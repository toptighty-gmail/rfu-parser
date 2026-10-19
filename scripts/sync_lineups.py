"""Scrape player lineups from RFU match-centre pages into Supabase.

For every division of a season, reads the division's fixtures page for match ids,
then fetches each completed match's community match-centre page and stores its
lineup in the players / matches / appearances tables
(migrations/2026-10-18_player_appearances.sql).

Resumable: a match already checked is skipped unless it was played within the
last --recheck-days (electronic match cards can be filed or corrected a few days
late) or --refresh is given. Re-running after an interruption picks up where it
stopped.

Credentials come from the environment or the repo's .env file:
    SUPABASE_URL, SUPABASE_SECRET_KEY (an sb_secret_ key; the legacy
    SUPABASE_SERVICE_ROLE_KEY also works). SUPABASE_ANON_KEY is enough for --dry-run.

Examples:
    python scripts/sync_lineups.py --season 2025-2026 --division 66453
    python scripts/sync_lineups.py --season 2025-2026 --competition 1699
    python scripts/sync_lineups.py --season 2026-2027            # weekly top-up
    python scripts/sync_lineups.py --season 2025-2026 --team "Plymstock Oaks" --team "Plymstock Oaks II"
    python scripts/sync_lineups.py --player "Aiden Taylor"        # whole career, every season and club
    python scripts/sync_lineups.py --season 2025-2026 --division 66453 --limit 3 --dry-run
"""
import argparse
import os
import sys
from urllib.parse import quote

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rfu_parser.lineup_sync import LineupSync, RfuBlocked, SupabaseRest, current_season, query_param
from rfu_parser.scraper import _normalize_team_name

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env_file(path):
    """Minimal .env loader; variables already set in the environment win."""
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--season", default=current_season(), help="e.g. 2025-2026 (default: current season)")
    ap.add_argument("--competition", type=int, help="only this RFU competition id, e.g. 1699")
    ap.add_argument("--division", type=int, help="only this RFU division id, e.g. 66453")
    ap.add_argument("--team", action="append",
                    help="only matches involving this team (exact name, repeatable), e.g. --team \"Plymstock Oaks\"")
    ap.add_argument("--player", action="append",
                    help="sync a player's whole RFU history (every season and club) instead of divisions; "
                         "an RFU playerId, or a name already in the players table (repeatable)")
    ap.add_argument("--delay", type=float, default=3.0,
                    help="seconds between RFU requests (default 3; the RFU site's firewall challenges fast clients)")
    ap.add_argument("--recheck-days", type=int, default=14,
                    help="re-fetch matches played within this many days (default 14)")
    ap.add_argument("--refresh", action="store_true", help="re-fetch every match, even ones already stored")
    ap.add_argument("--limit", type=int, help="stop after fetching this many match pages")
    ap.add_argument("--dry-run", action="store_true", help="scrape and print, but write nothing to Supabase")
    args = ap.parse_args()

    load_env_file(os.path.join(REPO_ROOT, ".env"))
    url = os.environ.get("SUPABASE_URL", "")
    key = (os.environ.get("SUPABASE_SECRET_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
           or (args.dry_run and os.environ.get("SUPABASE_ANON_KEY")))
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY (or SUPABASE_SERVICE_ROLE_KEY), "
                 "in the environment or .env.")

    db = SupabaseRest(url, key, dry_run=args.dry_run)
    if args.player:
        sync_players(db, args)
        return

    divisions = db.get(
        f"divisions?season=eq.{args.season}"
        "&select=id,division_name,season,source_url,rfu_competition_id,rfu_division_id&order=division_name"
    )
    divisions = [d for d in divisions if (d.get("source_url") or "").startswith("http")]
    if args.competition:
        divisions = [d for d in divisions
                     if (d.get("rfu_competition_id") or query_param(d["source_url"], "competition")) == args.competition]
    if args.division:
        divisions = [d for d in divisions
                     if (d.get("rfu_division_id") or query_param(d["source_url"], "division")) == args.division]
    if args.team:
        # Only the divisions whose league table lists one of the teams
        names = ",".join('"' + _normalize_team_name(t).replace('"', '') + '"' for t in args.team)
        team_divs = {s["division_id"] for s in db.get(f"standings?team_name=in.({quote(names)})&select=division_id")}
        divisions = [d for d in divisions if d["id"] in team_divs]

    print(f"Lineup sync {args.season}: {len(divisions)} divisions"
          f"{' (dry run)' if args.dry_run else ''}", flush=True)
    sync = LineupSync(db, args.delay, args.recheck_days, args.refresh, args.limit, teams=args.team)
    try:
        for i, div in enumerate(divisions, start=1):
            if sync.limit is not None and sync.stats["fetched"] >= sync.limit:
                break
            print(f"[{i}/{len(divisions)}] {div['division_name']}", flush=True)
            try:
                sync.sync_division(div)
            except RfuBlocked:
                raise
            except Exception as e:
                sync.stats["errors"] += 1
                print(f"  ! division failed: {e}", flush=True)
    except KeyboardInterrupt:
        print("\nInterrupted - progress so far is saved; re-run to continue.", flush=True)
    except RfuBlocked as e:
        stop_blocked(sync, e)

    print_summary(sync)


def stop_blocked(sync, error):
    """Report an RFU firewall challenge and exit non-zero, keeping what was saved."""
    print(f"\nStopped: {error}.\nThe RFU site is challenging this connection, so nothing more can be "
          "fetched for now. Progress so far is saved; re-run later (hours, not minutes), "
          "ideally with a larger --delay.", flush=True)
    print_summary(sync)
    sys.exit(2)


def print_summary(sync):
    s = sync.stats
    print(f"Done: {s['divisions']} divisions, {s['fetched']} match pages fetched "
          f"({s['with_lineup']} with lineups, {s['appearances']} appearances), "
          f"{s['skipped']} already stored, {s['errors']} errors.", flush=True)


def resolve_player_id(db, value):
    """An RFU playerId as given, or looked up by exact name in our players table."""
    if value.strip().isdigit():
        return int(value)
    rows = db.get(f"players?display_name=ilike.{quote(value.strip())}&select=rfu_player_id,display_name")
    if len(rows) == 1:
        return rows[0]["rfu_player_id"]
    if not rows:
        sys.exit(f'No player called "{value}" in the database yet. Pass their RFU playerId instead '
                 f'(the number in their England Rugby player-stats link).')
    ids = ", ".join(str(r["rfu_player_id"]) for r in rows)
    sys.exit(f'Several players are called "{value}" (playerIds {ids}); pass the playerId instead.')


def sync_players(db, args):
    player_ids = [resolve_player_id(db, p) for p in args.player]
    print(f"Lineup sync for {len(player_ids)} player(s), all seasons"
          f"{' (dry run)' if args.dry_run else ''}", flush=True)
    sync = LineupSync(db, args.delay, args.recheck_days, args.refresh, args.limit)
    try:
        for player_id in player_ids:
            try:
                sync.sync_player(player_id)
            except RfuBlocked:
                raise
            except Exception as e:
                sync.stats["errors"] += 1
                print(f"  ! player {player_id} failed: {e}", flush=True)
    except KeyboardInterrupt:
        print("\nInterrupted - progress so far is saved; re-run to continue.", flush=True)
    except RfuBlocked as e:
        stop_blocked(sync, e)
    print_summary(sync)


if __name__ == "__main__":
    main()
