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
    SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (SUPABASE_ANON_KEY is enough for --dry-run)

Examples:
    python scripts/sync_lineups.py --season 2025-2026 --division 66453
    python scripts/sync_lineups.py --season 2025-2026 --competition 1699
    python scripts/sync_lineups.py --season 2026-2027            # weekly top-up
    python scripts/sync_lineups.py --season 2025-2026 --division 66453 --limit 3 --dry-run
"""
import argparse
import os
import re
import sys
import time
from datetime import date, datetime, timedelta, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import cloudscraper
import requests

from rfu_parser.lineups import match_centre_url, parse_lineup
from rfu_parser.scraper import RFUParser, _normalize_team_name

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


def current_season(today=None):
    today = today or date.today()
    start = today.year if today.month >= 8 else today.year - 1
    return f"{start}-{start + 1}"


def parse_fixture_date(raw):
    """'Saturday, 06 Sep 2025' -> date(2025, 9, 6); None if unrecognised."""
    text = (raw or "").split(",", 1)[-1].strip()
    for fmt in ("%d %b %Y", "%d %B %Y"):
        try:
            return datetime.strptime(text, fmt).date()
        except ValueError:
            pass
    return None


def query_param(url, name):
    m = re.search(rf"[?&]{name}=(\d+)", url or "")
    return int(m.group(1)) if m else None


class SupabaseRest:
    def __init__(self, url, key, dry_run=False):
        self.base = url.rstrip("/") + "/rest/v1"
        self.dry_run = dry_run
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }

    def get(self, path):
        resp = requests.get(f"{self.base}/{path}", headers={**self.headers, "Range": "0-9999"}, timeout=30)
        resp.raise_for_status()
        return resp.json()

    def upsert(self, table, rows, on_conflict):
        if self.dry_run or not rows:
            return
        resp = requests.post(
            f"{self.base}/{table}?on_conflict={on_conflict}",
            json=rows,
            headers={**self.headers, "Prefer": "resolution=merge-duplicates,return=minimal"},
            timeout=30,
        )
        if resp.status_code not in (200, 201, 204):
            raise RuntimeError(f"upsert {table} failed: {resp.status_code} {resp.text[:300]}")

    def delete(self, path):
        if self.dry_run:
            return
        resp = requests.delete(f"{self.base}/{path}", headers=self.headers, timeout=30)
        if resp.status_code not in (200, 204):
            raise RuntimeError(f"delete {path} failed: {resp.status_code} {resp.text[:300]}")


class LineupSync:
    def __init__(self, db, delay, recheck_days, refresh, limit):
        self.db = db
        self.delay = delay
        self.recheck_cutoff = date.today() - timedelta(days=recheck_days)
        self.refresh = refresh
        self.limit = limit
        self.rfu = cloudscraper.create_scraper()
        self.parser = RFUParser()
        self.last_request = 0.0
        self.stats = {"divisions": 0, "fetched": 0, "with_lineup": 0, "appearances": 0, "skipped": 0, "errors": 0}

    def fetch(self, url):
        wait = self.delay - (time.time() - self.last_request)
        if wait > 0:
            time.sleep(wait)
        try:
            resp = self.rfu.get(url, timeout=30)
            resp.raise_for_status()
            return resp.text
        finally:
            self.last_request = time.time()

    def needs_fetch(self, existing, match_date):
        if existing is None or self.refresh:
            return True
        return match_date is not None and match_date >= self.recheck_cutoff

    def sync_division(self, div):
        name, season, src = div["division_name"], div["season"], div.get("source_url") or ""
        html = self.fetch(src)
        if "match-centre-community" not in html:
            # Elite competitions use match-centre-elite pages with client-side (Opta) lineups
            print(f"  - {name}: no community match-centre links, skipping", flush=True)
            return
        self.stats["divisions"] += 1

        played = [f for f in self.parser.parse_fixtures(html) if f.rfu_match_id and f.status == "Completed"]
        try:
            known = self.db.get(f"matches?division_id=eq.{div['id']}&select=rfu_match_id,lineup_status")
        except requests.HTTPError:
            if not self.db.dry_run:
                raise
            known = []  # dry run before the migration has been applied
        existing = {m["rfu_match_id"]: m for m in known}
        todo = []
        for f in played:
            match_date = parse_fixture_date(f.date)
            if self.needs_fetch(existing.get(f.rfu_match_id), match_date):
                todo.append((f, match_date))
            else:
                self.stats["skipped"] += 1
        print(f"  - {name}: {len(played)} played, {len(todo)} to fetch", flush=True)

        for f, match_date in todo:
            if self.limit is not None and self.stats["fetched"] >= self.limit:
                return
            try:
                self.sync_match(div, f, match_date)
            except Exception as e:  # keep going; the match is retried on the next run
                self.stats["errors"] += 1
                print(f"      ! match {f.rfu_match_id} ({f.home_team} v {f.away_team}): {e}", flush=True)

    def sync_match(self, div, fixture, match_date):
        match_id = fixture.rfu_match_id
        lineups = parse_lineup(self.fetch(match_centre_url(match_id)))
        self.stats["fetched"] += 1
        iso_date = match_date.isoformat() if match_date else None
        now = datetime.now(timezone.utc).isoformat()
        home = lineups[0] if len(lineups) > 0 else None
        away = lineups[1] if len(lineups) > 1 else None

        self.db.upsert("matches", [{
            "rfu_match_id": match_id,
            "division_id": div["id"],
            "rfu_competition_id": div.get("rfu_competition_id") or query_param(div.get("source_url"), "competition"),
            "rfu_division_id": div.get("rfu_division_id") or query_param(div.get("source_url"), "division"),
            "season": div["season"],
            "match_date": iso_date,
            "home_team": _normalize_team_name(fixture.home_team),
            "away_team": _normalize_team_name(fixture.away_team),
            "home_team_id": home.rfu_team_id if home else None,
            "away_team_id": away.rfu_team_id if away else None,
            "home_score": fixture.home_score,
            "away_score": fixture.away_score,
            "lineup_status": "ok" if lineups else "none",
            "lineup_checked_at": now,
            "updated_at": now,
        }], "rfu_match_id")

        players, appearances = {}, []
        for team in lineups:
            team_name = _normalize_team_name(team.team_name)
            for p in team.players:
                players[p.rfu_player_id] = {
                    "rfu_player_id": p.rfu_player_id,
                    "display_name": p.display_name,
                    "name_withheld": p.name_withheld,
                    "updated_at": now,
                }
                appearances.append({
                    "rfu_match_id": match_id,
                    "rfu_player_id": p.rfu_player_id,
                    "rfu_team_id": team.rfu_team_id,
                    "team_name": team_name,
                    "season": div["season"],
                    "division_id": div["id"],
                    "match_date": iso_date,
                    "shirt": p.shirt,
                    "shirt_number": p.shirt_number,
                    "is_substitute": p.is_substitute,
                })
        # A player listed twice on one card (data-entry slip) would break the batch's primary key
        appearances = list({a["rfu_player_id"]: a for a in appearances}.values())

        self.db.upsert("players", list(players.values()), "rfu_player_id")
        # Replace rather than merge so a corrected match card drops removed players
        self.db.delete(f"appearances?rfu_match_id=eq.{match_id}")
        self.db.upsert("appearances", appearances, "rfu_match_id,rfu_player_id")

        if lineups:
            self.stats["with_lineup"] += 1
            self.stats["appearances"] += len(appearances)
        summary = ", ".join(f"{t.team_name} {len(t.players)}" for t in lineups) or "no lineup"
        print(f"      {iso_date} {fixture.home_team} v {fixture.away_team} [{match_id}]: {summary}", flush=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--season", default=current_season(), help="e.g. 2025-2026 (default: current season)")
    ap.add_argument("--competition", type=int, help="only this RFU competition id, e.g. 1699")
    ap.add_argument("--division", type=int, help="only this RFU division id, e.g. 66453")
    ap.add_argument("--delay", type=float, default=1.5, help="seconds between RFU requests (default 1.5)")
    ap.add_argument("--recheck-days", type=int, default=14,
                    help="re-fetch matches played within this many days (default 14)")
    ap.add_argument("--refresh", action="store_true", help="re-fetch every match, even ones already stored")
    ap.add_argument("--limit", type=int, help="stop after fetching this many match pages")
    ap.add_argument("--dry-run", action="store_true", help="scrape and print, but write nothing to Supabase")
    args = ap.parse_args()

    load_env_file(os.path.join(REPO_ROOT, ".env"))
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or (args.dry_run and os.environ.get("SUPABASE_ANON_KEY"))
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (in the environment or .env).")

    db = SupabaseRest(url, key, dry_run=args.dry_run)
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

    print(f"Lineup sync {args.season}: {len(divisions)} divisions"
          f"{' (dry run)' if args.dry_run else ''}", flush=True)
    sync = LineupSync(db, args.delay, args.recheck_days, args.refresh, args.limit)
    try:
        for i, div in enumerate(divisions, start=1):
            if sync.limit is not None and sync.stats["fetched"] >= sync.limit:
                break
            print(f"[{i}/{len(divisions)}] {div['division_name']}", flush=True)
            try:
                sync.sync_division(div)
            except Exception as e:
                sync.stats["errors"] += 1
                print(f"  ! division failed: {e}", flush=True)
    except KeyboardInterrupt:
        print("\nInterrupted - progress so far is saved; re-run to continue.", flush=True)

    s = sync.stats
    print(f"Done: {s['divisions']} divisions, {s['fetched']} match pages fetched "
          f"({s['with_lineup']} with lineups, {s['appearances']} appearances), "
          f"{s['skipped']} already stored, {s['errors']} errors.", flush=True)


if __name__ == "__main__":
    main()
