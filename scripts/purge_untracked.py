"""Remove stored data for teams that are not ticked to be kept up to date.

Keeps: custom_fixtures (manual fixtures), team_logos, teams, competitions and the
divisions catalogue itself (the dropdowns and discovery need it), and every
division in which a tracked team plays (tracked_teams table; any season).
Removes, for every other division: its standings, its (non-custom) fixtures, its
stored matches and their lineups; then players left with no appearances.

Dry run by default - prints what would go. With --execute it first writes a full
JSON backup (to --backup-dir, outside the repo: it holds player names), then deletes.
A team added to the sync later fills back in when the sync or the app next opens it.

    python scripts/purge_untracked.py                 # report only
    python scripts/purge_untracked.py --execute
"""
import argparse
import datetime
import json
import os
import sys
from urllib.parse import quote

import requests

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from rfu_parser.env import load_env_file
from rfu_parser.lineup_sync import SupabaseRest
from rfu_parser.scraper import _normalize_team_name

PAGE = 1000
BACKUP_TABLES = ["tracked_teams", "divisions", "standings", "fixtures", "custom_fixtures", "team_logos",
                 "matches", "appearances", "players"]


def fetch_all(db, path):
    """Every row of a PostgREST query, paging past the server's row cap."""
    rows, offset = [], 0
    sep = "&" if "?" in path else "?"
    while True:
        resp = requests.get(f"{db.base}/{path}{sep}limit={PAGE}&offset={offset}", headers=db.headers, timeout=60)
        resp.raise_for_status()
        page = resp.json()
        rows.extend(page)
        if len(page) < PAGE:
            return rows
        offset += PAGE


def chunks(items, n):
    items = list(items)
    for i in range(0, len(items), n):
        yield items[i:i + n]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--execute", action="store_true", help="back up, then delete (default: report only)")
    ap.add_argument("--backup-dir", default=os.path.join(os.path.expanduser("~"), "rfu-backups"))
    args = ap.parse_args()

    load_env_file()
    url, key = os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_SECRET_KEY", "")
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY in the environment or .env.")
    db = SupabaseRest(url, key)

    tracked = {_normalize_team_name(r["team_name"]).lower() for r in fetch_all(db, "tracked_teams?select=team_name")}
    if not tracked:
        sys.exit("tracked_teams is empty - refusing to purge everything.")
    print(f"Tracked teams ({len(tracked)}): {', '.join(sorted(tracked))}")

    divisions = fetch_all(db, "divisions?select=id,division_name,season")
    keep = set()
    for r in fetch_all(db, "standings?select=division_id,team_name"):
        if _normalize_team_name(r["team_name"]).lower() in tracked:
            keep.add(r["division_id"])
    for r in fetch_all(db, "fixtures?select=division_id,home_team,away_team"):
        if {_normalize_team_name(r["home_team"]).lower(), _normalize_team_name(r["away_team"]).lower()} & tracked:
            keep.add(r["division_id"])
    # Divisions that have standings/fixtures/matches stored but no tracked team
    purge = [d for d in divisions if d["id"] not in keep]
    print(f"Divisions: {len(divisions)} in catalogue, {len(keep)} kept (a tracked team plays there), "
          f"{len(purge)} to clear of stored results.")
    purge_ids = [d["id"] for d in purge]

    def count(table, extra=""):
        total = 0
        for part in chunks(purge_ids, 20):
            ids = ",".join(part)
            resp = requests.get(f"{db.base}/{table}?division_id=in.({ids}){extra}&select=division_id&limit=1",
                                headers={**db.headers, "Prefer": "count=exact", "Range-Unit": "items",
                                         "Range": "0-0"}, timeout=60)
            resp.raise_for_status()
            total += int(resp.headers["Content-Range"].split("/")[1])
        return total

    n_standings = count("standings")
    n_fixtures = count("fixtures", "&is_custom=eq.false")
    n_matches = count("matches")
    print(f"Would delete: {n_standings} standings rows, {n_fixtures} fixtures, {n_matches} matches "
          f"(and their appearances), then players with no appearances left.")
    print("Kept untouched: custom_fixtures, team_logos, teams, competitions, divisions.")

    if not args.execute:
        print("\nDry run - nothing changed. Re-run with --execute to back up and delete.")
        return

    os.makedirs(args.backup_dir, exist_ok=True)
    path = os.path.join(args.backup_dir, f"supabase_before_purge_{datetime.datetime.now():%Y%m%d_%H%M%S}.json")
    backup = {}
    for table in BACKUP_TABLES:
        backup[table] = fetch_all(db, f"{table}?select=*")
        print(f"  backed up {table}: {len(backup[table])} rows", flush=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(backup, f)
    print(f"Backup written to {path} ({os.path.getsize(path) / 1e6:.1f} MB)", flush=True)

    for part in chunks(purge_ids, 20):
        ids = ",".join(part)
        db.delete(f"standings?division_id=in.({ids})")
        db.delete(f"fixtures?division_id=in.({ids})&is_custom=eq.false")
        db.delete(f"matches?division_id=in.({ids})")  # appearances cascade
    print("Deleted standings, fixtures and matches of untracked divisions.", flush=True)

    used = {r["rfu_player_id"] for r in fetch_all(db, "appearances?select=rfu_player_id")}
    orphans = [r["rfu_player_id"] for r in fetch_all(db, "players?select=rfu_player_id") if r["rfu_player_id"] not in used]
    for part in chunks(orphans, 100):
        db.delete(f"players?rfu_player_id=in.({','.join(str(i) for i in part)})")
    print(f"Deleted {len(orphans)} players with no appearances left. Done.")


if __name__ == "__main__":
    main()
