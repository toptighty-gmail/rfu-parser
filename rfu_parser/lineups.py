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
from typing import List, Optional

from bs4 import BeautifulSoup

MATCH_CENTRE_URL = "https://www.englandrugby.com/fixtures-and-results/match-centre-community?matchId={match_id}"
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


def match_centre_url(match_id: int) -> str:
    return MATCH_CENTRE_URL.format(match_id=match_id)


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
