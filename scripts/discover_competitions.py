"""Discover every senior RFU competition and its divisions, season by season.

1. Competitions: read the competition directory on the Fixtures & Results page
   and run the site search for a list of terms (see rfu_parser/competitions.py),
   keeping senior men's and women's leagues, merit tables, cups, internationals
   and elite competitions. Age-grade and university rugby are left out.
2. Divisions: for each competition and season, read the competition's page and
   add any division (league, merit table, cup round, ...) not yet in the
   divisions table. Fixtures and tables are fetched later, when a division is
   opened in the app or by the sync jobs.

Resumable: each competition/season read is recorded in competition_seasons and
not fetched again, except for the current season (cups add rounds as it goes)
or with --refresh. Stops at the first RFU firewall challenge (exit code 2).

Needs migrations/2026-10-19_competition_catalog.sql and SUPABASE_SECRET_KEY.

Examples:
    python scripts/discover_competitions.py                       # current season
    python scripts/discover_competitions.py --season 2025-2026 --season 2024-2025
    python scripts/discover_competitions.py --all-seasons
    python scripts/discover_competitions.py --skip-search --competition 2106 --dry-run
"""
import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import cloudscraper
import requests

from rfu_parser.competitions import (
    CATEGORIES,
    COMPETITION_PAGE,
    FIXTURES_PAGE,
    SEARCH_API,
    SEARCH_TERMS,
    Competition,
    competitions_from_directory,
    merge_competitions,
    parse_competition_divisions,
)
from rfu_parser.env import load_env_file
from rfu_parser.lineup_sync import RfuBlocked, SupabaseRest, current_season, get_rfu_page, query_param

FIRST_SEASON = 2021  # the app's earliest season


class Fetcher:
    def __init__(self, delay):
        self.delay = delay
        self.session = cloudscraper.create_scraper()
        self.last = 0.0
        self.count = 0

    def get(self, url, params=None):
        wait = self.delay - (time.time() - self.last)
        if wait > 0:
            time.sleep(wait)
        try:
            return get_rfu_page(self.session, url, params)
        finally:
            self.last = time.time()
            self.count += 1


def find_competitions(fetcher):
    directory = competitions_from_directory(fetcher.get(FIXTURES_PAGE))
    results = []
    for term in SEARCH_TERMS:
        body = json.loads(fetcher.get(SEARCH_API, params={"name": term}) or "{}")
        results.extend((body or {}).get("data") or [])
    return merge_competitions(results, directory)


def save_competitions(db, competitions):
    db.upsert("competitions", [{
        "rfu_competition_id": c.rfu_competition_id,
        "name": c.name,
        "category": c.category,
        "rfu_type": c.rfu_type,
        "is_elite": c.is_elite,
    } for c in competitions.values()], "rfu_competition_id")


def load_competitions(db):
    rows = db.get("competitions?select=rfu_competition_id,name,category,rfu_type,is_elite")
    return {r["rfu_competition_id"]: Competition(r["rfu_competition_id"], r["name"], r["category"],
                                                 r.get("rfu_type") or "", bool(r.get("is_elite")))
            for r in rows if r.get("category") in CATEGORIES}


class DivisionCatalog:
    """Divisions already stored for one season, to add only new ones and keep names unique."""

    def __init__(self, db, season):
        self.db, self.season = db, season
        rows = db.get(f"divisions?season=eq.{season}&select=id,division_name,rfu_division_id,rfu_competition_id,source_url")
        self.by_rfu_id = {}
        self.names = {}
        for r in rows:
            rfu_id = r.get("rfu_division_id") or query_param(r.get("source_url"), "division")
            if rfu_id:
                self.by_rfu_id[rfu_id] = r
            self.names[r["division_name"].lower()] = rfu_id

    def unique_name(self, name, competition, rfu_id):
        """divisions are unique by (name, season): prefix the competition, then the id, on a clash."""
        for candidate in (name, f"{competition.name} - {name}", f"{competition.name} - {name} ({rfu_id})"):
            if self.names.get(candidate.lower(), rfu_id) == rfu_id:
                return candidate
        return f"{name} ({rfu_id})"

    def add(self, competition, links):
        """Store new divisions; returns how many were new."""
        new_rows = []
        for link in links:
            known = self.by_rfu_id.get(link.rfu_division_id)
            url = COMPETITION_PAGE.format(cid=competition.rfu_competition_id, season=self.season) \
                + f"&division={link.rfu_division_id}"
            if known:
                if not known.get("rfu_competition_id") or not known.get("rfu_division_id"):
                    self.db.patch(f"divisions?id=eq.{known['id']}", {
                        "rfu_competition_id": competition.rfu_competition_id,
                        "rfu_division_id": link.rfu_division_id,
                    })
                continue
            name = self.unique_name(link.name, competition, link.rfu_division_id)
            self.names[name.lower()] = link.rfu_division_id
            self.by_rfu_id[link.rfu_division_id] = {"rfu_competition_id": competition.rfu_competition_id,
                                                    "rfu_division_id": link.rfu_division_id}
            new_rows.append({
                "division_name": name,
                "season": self.season,
                "rfu_competition_id": competition.rfu_competition_id,
                "rfu_division_id": link.rfu_division_id,
                "source_url": url,
                "tier_level": None,
                "region": None,
            })
        self.db.upsert("divisions", new_rows, "division_name,season")
        return len(new_rows)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--season", action="append", help="season(s) to read, e.g. 2025-2026 (default: current)")
    ap.add_argument("--all-seasons", action="store_true", help=f"every season from {FIRST_SEASON}-{FIRST_SEASON + 1}")
    ap.add_argument("--competition", type=int, action="append", help="only these RFU competition ids")
    ap.add_argument("--skip-search", action="store_true",
                    help="use the competitions already stored instead of searching the RFU site again")
    ap.add_argument("--refresh", action="store_true", help="re-read competition/seasons already checked")
    ap.add_argument("--delay", type=float, default=4.0, help="seconds between RFU requests (default 4)")
    ap.add_argument("--dry-run", action="store_true", help="read the RFU site but write nothing")
    args = ap.parse_args()

    load_env_file()
    url = os.environ.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SECRET_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY") \
        or (args.dry_run and os.environ.get("SUPABASE_ANON_KEY"))
    if not url or not key:
        sys.exit("Set SUPABASE_URL and SUPABASE_SECRET_KEY (in the environment or .env).")
    db = SupabaseRest(url, key, dry_run=args.dry_run)
    fetcher = Fetcher(args.delay)

    now_season = current_season()
    start = int(now_season[:4])
    seasons = args.season or ([f"{y}-{y + 1}" for y in range(start, FIRST_SEASON - 1, -1)]
                              if args.all_seasons else [now_season])

    stats = {"competitions": 0, "pages": 0, "new_divisions": 0, "skipped": 0}
    try:
        if args.skip_search:
            competitions = load_competitions(db)
        else:
            competitions = find_competitions(fetcher)
            save_competitions(db, competitions)
        if args.competition:
            competitions = {cid: c for cid, c in competitions.items() if cid in set(args.competition)}
        stats["competitions"] = len(competitions)
        by_cat = {cat: sum(1 for c in competitions.values() if c.category == cat) for cat in CATEGORIES}
        print(f"{len(competitions)} senior competitions: {by_cat}", flush=True)

        try:
            checked = {(r["rfu_competition_id"], r["season"])
                       for r in db.get("competition_seasons?select=rfu_competition_id,season")}
        except requests.HTTPError:
            if not args.dry_run:
                raise
            checked = set()  # dry run before the migration has been applied
        order = sorted(competitions.values(), key=lambda c: (CATEGORIES.index(c.category), c.name.lower()))
        for season in seasons:
            catalog = DivisionCatalog(db, season)
            print(f"\n{season}", flush=True)
            for comp in order:
                key_ = (comp.rfu_competition_id, season)
                if key_ in checked and season != now_season and not args.refresh:
                    stats["skipped"] += 1
                    continue
                html = fetcher.get(COMPETITION_PAGE.format(cid=comp.rfu_competition_id, season=season))
                stats["pages"] += 1
                links = parse_competition_divisions(html, comp.rfu_competition_id, comp.name)
                added = catalog.add(comp, links)
                stats["new_divisions"] += added
                db.upsert("competition_seasons", [{
                    "rfu_competition_id": comp.rfu_competition_id,
                    "season": season,
                    "division_count": len(links),
                    "checked_at": datetime.now(timezone.utc).isoformat(),
                }], "rfu_competition_id,season")
                if links:
                    print(f"  [{comp.category}] {comp.name}: {len(links)} divisions"
                          f"{f', {added} new' if added else ''}", flush=True)
    except RfuBlocked as e:
        print(f"\nStopped: {e}.\nThe RFU site is challenging this connection. Everything read so far is "
              "saved; re-run later (hours, not minutes) and it carries on.", flush=True)
        print(f"Done: {stats}", flush=True)
        sys.exit(2)
    except KeyboardInterrupt:
        print("\nInterrupted - progress so far is saved; re-run to continue.", flush=True)
    print(f"\nDone: {stats}, {fetcher.count} RFU requests", flush=True)


if __name__ == "__main__":
    main()
