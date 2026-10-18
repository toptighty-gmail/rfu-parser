"""Parse team lineups from England Rugby community match-centre pages.

Lineups come from the RFU Game Management System (electronic match cards) and are
rendered server-side as ``c085-lineup-table-*`` blocks, one block per team:

    c085-lineup-table-content
      c085-lineup-table-team-title  -> <a href="...&team=20429">St Ives (SW)</a>
      c085-lineup-table-player      -> number "15" + <a href="...?playerId=1811658">
      ...
      c085-lineup-table-team-substitutes
      c085-lineup-table-player      -> number "S1" ...

Elite (Premiership) match-centre pages load their Opta lineups client-side, so they
carry no lineup in the HTML and parse to an empty list.
"""
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import List, Optional

from bs4 import BeautifulSoup

MATCH_CENTRE_URL = "https://www.englandrugby.com/fixtures-and-results/match-centre-community?matchId={match_id}"
PLAYER_STATS_URL = "https://www.englandrugby.com/fixtures-and-results/player-stats?playerId={player_id}"
WITHHELD_NAME = "Name withheld"


@dataclass
class LineupPlayer:
    rfu_player_id: int
    display_name: str
    name_withheld: bool
    shirt: str  # as shown: "1".."15", "S1".."S8"
    shirt_number: Optional[int]
    is_substitute: bool


@dataclass
class TeamLineup:
    rfu_team_id: Optional[int]
    team_name: str
    players: List[LineupPlayer] = field(default_factory=list)


@dataclass
class MatchInfo:
    """Header details of a match-centre page (the c042 block)."""
    home_team: str
    away_team: str
    match_date: Optional[date]
    home_score: Optional[int]
    away_score: Optional[int]
    season: Optional[str]  # "2025-2026"
    rfu_competition_id: Optional[int]
    rfu_division_id: Optional[int]


def match_centre_url(match_id: int) -> str:
    return MATCH_CENTRE_URL.format(match_id=match_id)


def player_stats_url(player_id: int) -> str:
    return PLAYER_STATS_URL.format(player_id=player_id)


def parse_match_info(html_content: str) -> Optional[MatchInfo]:
    """Teams, date, score and competition/season/division of a match page.

    Returns None if the page has no match header (e.g. an error page).
    """
    soup = BeautifulSoup(html_content, "html.parser")
    names = [" ".join(t.get_text().split()) for t in soup.find_all(class_="c042-team-name")]
    if len(names) < 2:
        return None

    match_date = None
    date_el = soup.find(id="c042-event-date")
    if date_el:
        m = re.search(r"(\d{1,2}) ([A-Za-z]+) (\d{4})", date_el.get_text(" "))
        if m:
            try:
                match_date = datetime.strptime(" ".join(m.groups()), "%d %B %Y").date()
            except ValueError:
                pass

    home_score = away_score = None
    score_el = soup.find(class_="c042-match-score")
    if score_el:
        m = re.match(r"\s*(\d+)\s*-\s*(\d+)", score_el.get_text())
        if m:
            home_score, away_score = int(m.group(1)), int(m.group(2))

    # The lineup team links (and other in-page links) carry the match's own
    # competition, season and division.
    # Only present when the page was opened with those query params, so fall
    # back to the season the date falls in (seasons run August to July).
    season = competition = division = None
    m = re.search(r"competition=(\d+)&(?:amp;)?season=(\d{4}-\d{4})&(?:amp;)?division=(\d+)", html_content)
    if m:
        competition, season, division = int(m.group(1)), m.group(2), int(m.group(3))
    elif match_date:
        start = match_date.year if match_date.month >= 8 else match_date.year - 1
        season = f"{start}-{start + 1}"

    return MatchInfo(
        home_team=names[0],
        away_team=names[1],
        match_date=match_date,
        home_score=home_score,
        away_score=away_score,
        season=season,
        rfu_competition_id=competition,
        rfu_division_id=division,
    )


def parse_player_match_ids(html_content: str) -> List[int]:
    """Every matchId on a player-stats page (all seasons), oldest last."""
    seen = []
    for m in re.finditer(r"match-centre-community\?[^\"']*?matchId=(\d+)", html_content):
        mid = int(m.group(1))
        if mid not in seen:
            seen.append(mid)
    return seen


def clean_player_name(raw: str) -> str:
    """Collapse the page's multi-line whitespace and fix all-lower/all-upper names.

    Mixed-case names are left alone so spellings like "McDonald" survive.
    """
    name = " ".join(raw.split())
    if name and (name.islower() or name.isupper()):
        name = name.title()
    return name


def parse_lineup(html_content: str) -> List[TeamLineup]:
    """Return the home and away lineups (home first), or [] when none is published."""
    soup = BeautifulSoup(html_content, "html.parser")
    lineups: List[TeamLineup] = []
    seen_teams = set()

    for block in soup.find_all(class_="c085-lineup-table-content"):
        title = block.find("a", class_="c085-lineup-table-team-title-text")
        if not title:
            continue
        team_match = re.search(r"[?&]team=(\d+)", title.get("href", ""))
        team_id = int(team_match.group(1)) if team_match else None
        team_name = " ".join(title.get_text().split())
        team_key = team_id or team_name
        if team_key in seen_teams:
            continue
        seen_teams.add(team_key)

        lineup = TeamLineup(rfu_team_id=team_id, team_name=team_name)
        on_bench = False
        for el in block.find_all(class_=["c085-lineup-table-team-substitutes", "c085-lineup-table-player"]):
            if "c085-lineup-table-team-substitutes" in el.get("class", []):
                on_bench = True
                continue
            # "No lineup to show." placeholders have no player link
            link = el.find("a", href=re.compile(r"playerId=\d+"))
            if not link:
                continue
            player_id = int(re.search(r"playerId=(\d+)", link["href"]).group(1))
            number_el = el.find(class_="c085-lineup-table-player-number")
            shirt = number_el.get_text(strip=True).upper() if number_el else ""
            digits = re.search(r"\d+", shirt)
            name = clean_player_name(link.get_text())
            withheld = name.lower() == WITHHELD_NAME.lower()
            lineup.players.append(LineupPlayer(
                rfu_player_id=player_id,
                display_name=WITHHELD_NAME if withheld else name,
                name_withheld=withheld,
                shirt=shirt,
                shirt_number=int(digits.group(0)) if digits else None,
                is_substitute=on_bench or shirt.startswith("S"),
            ))

        if lineup.players:
            lineups.append(lineup)

    return lineups
