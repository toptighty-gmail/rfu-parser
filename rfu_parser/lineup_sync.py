"""Scrape RFU match lineups into the players / matches / appearances tables.

Shared by scripts/sync_lineups.py (command line, scheduled job) and the
/api/lineups/sync endpoint (on-demand from the app). A match already stored is
skipped unless it was played within the recheck window (electronic match cards
can be filed or corrected a few days late), so re-running only fetches what is
new. Writes need the Supabase secret (service-role) key.
"""
import re
import time
from datetime import date, datetime, timedelta, timezone

import cloudscraper
import requests

from rfu_parser.competitions import AGE_GRADE_NAME, CATEGORIES
from rfu_parser.lineups import (
    match_centre_url,
    parse_lineup,
    parse_match_events,
    parse_match_info,
    parse_player_matches,
    player_stats_url,
)
from rfu_parser.scraper import RFUParser, _normalize_team_name


class RfuBlocked(RuntimeError):
    """The RFU site answered with its bot challenge (AWS WAF) or a rate limit.

    Every further request would be challenged too, and keeping on only extends
    the block, so a run stops at the first one. Try again later, more slowly.
    """


def get_rfu_page(session, url, params=None):
    """GET an englandrugby.com page or API response body, raising RfuBlocked
    on the site's firewall challenge.

    The WAF challenge comes back as a small "202 Accepted" page that a script
    can't pass; treating it as a normal page would quietly record matches as
    having no lineup, or competitions as having no divisions.
    """
    resp = session.get(url, params=params, timeout=30)
    if resp.status_code in (202, 429) or "awsWafCookieDomainList" in resp.text[:4000]:
        raise RfuBlocked(f"RFU site challenged the request (HTTP {resp.status_code}) for {url}")
    resp.raise_for_status()
    return resp.text


# Competition groups whose lineups may be stored: the senior display groups,
# plus the labels competitions carried before the full catalogue existed.
SENIOR_CATEGORIES = set(CATEGORIES) | {"Senior Mens", "Elite Men", "Elite Women"}


def senior_competition_ids(db):
    """RFU ids of competitions whose lineups may be stored (never age grade)."""
    rows = db.get("competitions?select=rfu_competition_id,category")
    return {r["rfu_competition_id"] for r in rows if r.get("category") in SENIOR_CATEGORIES}


def is_senior_division(division, senior_ids):
    """A division of a known senior competition, without an age-grade name.

    Divisions can reach the table from a live crawl of any team the app is
    asked for (e.g. a colts side), so lineup syncs check before fetching.
    """
    comp = division.get("rfu_competition_id") or query_param(division.get("source_url"), "competition")
    return comp in senior_ids and not AGE_GRADE_NAME.search(division.get("division_name") or "")


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
        self.headers = {"apikey": key, "Content-Type": "application/json"}
        # Legacy keys are JWTs and also go in Authorization; the newer
        # sb_secret_ keys are not JWTs and belong on the apikey header only.
        if key.startswith("eyJ"):
            self.headers["Authorization"] = f"Bearer {key}"

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

    def patch(self, path, values):
        """Update the rows matching a PostgREST filter, e.g. patch("divisions?id=eq.X", {...})."""
        if self.dry_run:
            return
        resp = requests.patch(f"{self.base}/{path}", json=values,
                              headers={**self.headers, "Prefer": "return=minimal"}, timeout=30)
        if resp.status_code not in (200, 204):
            raise RuntimeError(f"patch {path} failed: {resp.status_code} {resp.text[:300]}")

    def delete(self, path):
        if self.dry_run:
            return
        resp = requests.delete(f"{self.base}/{path}", headers=self.headers, timeout=30)
        if resp.status_code not in (200, 204):
            raise RuntimeError(f"delete {path} failed: {resp.status_code} {resp.text[:300]}")


# appearances columns, keyed by MatchEvent.kind
EVENT_COLUMNS = {
    "try": "tries",
    "conversion": "conversions",
    "penalty": "penalties",
    "drop_goal": "drop_goals",
    "yellow_card": "yellow_cards",
    "red_card": "red_cards",
}
NO_EVENTS = {column: 0 for column in EVENT_COLUMNS.values()}


def event_counts(team, events):
    """{rfu_player_id: {"tries": n, ...}} for one team's match events.

    Timeline events link the player's id; key-events ones only give a name,
    so each is credited to the player with that name in the team's lineup,
    and left out when no player, or more than one (namesakes, or several
    withheld names), has it.
    """
    ids_by_name = {}
    for p in team.players:
        ids_by_name.setdefault(p.display_name.lower(), set()).add(p.rfu_player_id)
    lineup_ids = {p.rfu_player_id for p in team.players}
    counts = {}
    for e in events:
        if e.rfu_player_id is not None:
            ids = {e.rfu_player_id} & lineup_ids
        else:
            ids = ids_by_name.get(e.player_name.lower(), set())
        if len(ids) == 1:
            row = counts.setdefault(next(iter(ids)), dict(NO_EVENTS))
            row[EVENT_COLUMNS[e.kind]] += 1
    return counts


class LineupSync:
    def __init__(self, db, delay, recheck_days, refresh, limit, teams=None, time_budget=None):
        self.db = db
        # Stop starting new match fetches after this many seconds (web requests
        # have a time limit); unfinished matches are counted in stats["remaining"].
        self.deadline = time.time() + time_budget if time_budget else None
        # Lower-cased canonical team names; when set, only their matches are fetched
        self.teams = {_normalize_team_name(t).lower() for t in teams} if teams else None
        self.delay = delay
        self.recheck_cutoff = date.today() - timedelta(days=recheck_days)
        self.refresh = refresh
        self.limit = limit
        self.rfu = cloudscraper.create_scraper()
        self.parser = RFUParser()
        self.last_request = 0.0
        self._divisions = None
        self.stats = {"divisions": 0, "fetched": 0, "with_lineup": 0, "appearances": 0, "skipped": 0,
                      "errors": 0, "remaining": 0}

    def fetch(self, url):
        wait = self.delay - (time.time() - self.last_request)
        if wait > 0:
            time.sleep(wait)
        try:
            return get_rfu_page(self.rfu, url)
        finally:
            self.last_request = time.time()

    def should_stop(self):
        """Out of --limit or time budget."""
        if self.limit is not None and self.stats["fetched"] >= self.limit:
            return True
        # Allow for one more page fetch (a few seconds) before the deadline
        return self.deadline is not None and time.time() > self.deadline - self.delay - 5

    def needs_fetch(self, existing, match_date):
        if existing is None or self.refresh:
            return True
        # Stored before tries, cards etc. were recorded: fetch once more for them
        if existing.get("lineup_status") == "ok" and existing.get("events_checked") is False:
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
        if self.teams:
            played = [f for f in played
                      if {_normalize_team_name(f.home_team).lower(), _normalize_team_name(f.away_team).lower()} & self.teams]
        try:
            known = self.db.get(f"matches?division_id=eq.{div['id']}&select=rfu_match_id,lineup_status,events_checked")
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

        for i, (f, match_date) in enumerate(todo):
            if self.should_stop():
                self.stats["remaining"] += len(todo) - i
                return
            try:
                self.sync_match(div, f, match_date)
            except RfuBlocked:
                raise
            except Exception as e:  # keep going; the match is retried on the next run
                self.stats["errors"] += 1
                print(f"      ! match {f.rfu_match_id} ({f.home_team} v {f.away_team}): {e}", flush=True)

    def sync_match(self, div, fixture, match_date):
        """Fetch and store one match found on a division's fixtures page."""
        match_id = fixture.rfu_match_id
        html = self.fetch(match_centre_url(match_id))
        self.stats["fetched"] += 1
        self.store_match(
            match_id,
            parse_lineup(html),
            parse_match_events(html),
            season=div["season"],
            division_id=div["id"],
            rfu_competition_id=div.get("rfu_competition_id") or query_param(div.get("source_url"), "competition"),
            rfu_division_id=div.get("rfu_division_id") or query_param(div.get("source_url"), "division"),
            match_date=match_date,
            home_team=fixture.home_team,
            away_team=fixture.away_team,
            home_score=fixture.home_score,
            away_score=fixture.away_score,
        )

    def sync_player(self, player_id):
        """Fetch every match on a player's RFU stats page (all seasons, any
        club), storing each match's full lineups."""
        rows = parse_player_matches(self.fetch(player_stats_url(player_id)))
        # Age-grade matches (colts, youth, schools) are never stored: those
        # lineups are mostly children's names.
        match_ids = [mid for mid, competition in rows if not AGE_GRADE_NAME.search(competition)]
        if len(match_ids) < len(rows):
            print(f"  - player {player_id}: skipping {len(rows) - len(match_ids)} age-grade matches", flush=True)
        existing = {}
        for i in range(0, len(match_ids), 100):
            chunk = ",".join(str(m) for m in match_ids[i:i + 100])
            for m in self.db.get(f"matches?rfu_match_id=in.({chunk})"
                                 "&select=rfu_match_id,match_date,lineup_status,events_checked,"
                                 "division_id,rfu_competition_id,rfu_division_id"):
                existing[m["rfu_match_id"]] = m
        todo = []
        for match_id in match_ids:
            known = existing.get(match_id)
            known_date = date.fromisoformat(known["match_date"]) if known and known.get("match_date") else None
            if self.needs_fetch(known, known_date):
                todo.append(match_id)
            else:
                self.stats["skipped"] += 1
        print(f"  - player {player_id}: {len(match_ids)} matches on RFU, {len(todo)} to fetch", flush=True)

        for i, match_id in enumerate(todo):
            if self.should_stop():
                self.stats["remaining"] += len(todo) - i
                return
            try:
                self.sync_match_id(match_id, existing.get(match_id))
            except RfuBlocked:
                raise
            except Exception as e:  # keep going; the match is retried on the next run
                self.stats["errors"] += 1
                print(f"      ! match {match_id}: {e}", flush=True)

    def sync_missing_events(self):
        """Re-fetch stored matches that have a lineup but were synced before
        tries, cards etc. were recorded, newest first."""
        todo = self.db.get("matches?lineup_status=eq.ok&events_checked=is.false"
                           "&select=rfu_match_id,division_id,rfu_competition_id,rfu_division_id"
                           "&order=match_date.desc")
        print(f"  - {len(todo)} stored matches without tries, cards etc.", flush=True)
        for i, known in enumerate(todo):
            if self.should_stop():
                self.stats["remaining"] += len(todo) - i
                return
            try:
                self.sync_match_id(known["rfu_match_id"], known)
            except RfuBlocked:
                raise
            except Exception as e:  # keep going; the match is retried on the next run
                self.stats["errors"] += 1
                print(f"      ! match {known['rfu_match_id']}: {e}", flush=True)

    def sync_match_id(self, match_id, known=None):
        """Fetch and store one match by id, reading its details from the page."""
        html = self.fetch(match_centre_url(match_id))
        self.stats["fetched"] += 1
        info = parse_match_info(html)
        if info is None or not info.season:
            raise RuntimeError("no match header on page")
        # A page opened by matchId alone doesn't name its division; keep
        # whatever an earlier division sync recorded for this match.
        known = known or {}
        rfu_division_id = info.rfu_division_id or known.get("rfu_division_id")
        self.store_match(
            match_id,
            parse_lineup(html),
            parse_match_events(html),
            season=info.season,
            division_id=self.division_uuid(info.season, rfu_division_id) or known.get("division_id"),
            rfu_competition_id=info.rfu_competition_id or known.get("rfu_competition_id"),
            rfu_division_id=rfu_division_id,
            match_date=info.match_date,
            home_team=info.home_team,
            away_team=info.away_team,
            home_score=info.home_score,
            away_score=info.away_score,
        )

    def division_uuid(self, season, rfu_division_id):
        """Our divisions.id for an RFU division in a season, if we track it."""
        if rfu_division_id is None:
            return None
        if self._divisions is None:
            self._divisions = {}
            for d in self.db.get("divisions?select=id,season,source_url,rfu_division_id"):
                rfu_id = d.get("rfu_division_id") or query_param(d.get("source_url"), "division")
                if rfu_id:
                    self._divisions[(d["season"], rfu_id)] = d["id"]
        return self._divisions.get((season, rfu_division_id))

    def store_match(self, match_id, lineups, events, *, season, division_id, rfu_competition_id, rfu_division_id,
                    match_date, home_team, away_team, home_score, away_score):
        iso_date = match_date.isoformat() if match_date else None
        now = datetime.now(timezone.utc).isoformat()
        home = lineups[0] if len(lineups) > 0 else None
        away = lineups[1] if len(lineups) > 1 else None

        match_row = {
            "rfu_match_id": match_id,
            "division_id": division_id,
            "rfu_competition_id": rfu_competition_id,
            "rfu_division_id": rfu_division_id,
            "season": season,
            "match_date": iso_date,
            "home_team": _normalize_team_name(home_team),
            "away_team": _normalize_team_name(away_team),
            "home_team_id": home.rfu_team_id if home else None,
            "away_team_id": away.rfu_team_id if away else None,
            "home_score": home_score,
            "away_score": away_score,
            "lineup_status": "ok" if lineups else "none",
            "lineup_checked_at": now,
            "events_checked": True,
            "updated_at": now,
        }
        # Leave unknown division details out so the upsert doesn't blank ones
        # already stored (a single-row upsert only updates the columns sent).
        for key in ("division_id", "rfu_competition_id", "rfu_division_id"):
            if match_row[key] is None:
                del match_row[key]
        self.db.upsert("matches", [match_row], "rfu_match_id")

        players, appearances = {}, []
        for team in lineups:
            team_name = _normalize_team_name(team.team_name)
            counts = event_counts(team, events.get(team.rfu_team_id, []))
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
                    "season": season,
                    "division_id": division_id,
                    "match_date": iso_date,
                    "shirt": p.shirt,
                    "shirt_number": p.shirt_number,
                    "is_substitute": p.is_substitute,
                    **counts.get(p.rfu_player_id, NO_EVENTS),
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
        print(f"      {iso_date} {home_team} v {away_team} [{match_id}]: {summary}", flush=True)
