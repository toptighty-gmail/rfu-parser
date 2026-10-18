import os

from rfu_parser.lineups import clean_player_name, parse_lineup
from rfu_parser.scraper import RFUParser

SAMPLE_DIR = os.path.join(os.path.dirname(__file__), "sample_data")

# Trimmed copy of the c085 lineup markup from a community match-centre page, with
# made-up names. Whitespace inside the names mirrors the real page.
LINEUP_HTML = """
<div class="c085-lineup-table-container">
  <div class="c085-lineup-table-content">
    <div class="loader"><span class="message">Loading</span></div>
    <div class="c085-lineup-table-team-title">
      <a class="c085-lineup-table-team-title-text c085-link"
         href="/fixtures-and-results/search-results?competition=1699&amp;season=2025-2026&amp;division=1&amp;matchId=9&amp;team=111">Home RFC</a>
    </div>
    <div class="c085-lineup-table-player">
      <div class="c085-lineup-table-player-number">15</div>
      <div class="c085-lineup-table-player-name-text">
        <a class="c085-lineup-table-player-name-text c085-link" href="/fixtures-and-results/player-stats?playerId=1001">Alex
                    McTest</a>
      </div>
    </div>
    <div class="c085-lineup-table-player">
      <div class="c085-lineup-table-player-number">7</div>
      <div class="c085-lineup-table-player-name-text">
        <a class="c085-lineup-table-player-name-text c085-link" href="/fixtures-and-results/player-stats?playerId=1002">Name withheld</a>
      </div>
    </div>
    <div class="c085-lineup-table-team-substitutes">
      <span class="c085-lineup-table-team-title-text">Substitutes</span>
    </div>
    <div class="c085-lineup-table-player">
      <div class="c085-lineup-table-player-number">S1</div>
      <div class="c085-lineup-table-player-name-text">
        <a class="c085-lineup-table-player-name-text c085-link" href="/fixtures-and-results/player-stats?playerId=1003">SAM
                    UPPERCASE</a>
      </div>
    </div>
  </div>
  <div class="c085-lineup-table-content">
    <div class="c085-lineup-table-team-title">
      <a class="c085-lineup-table-team-title-text c085-link"
         href="/fixtures-and-results/search-results?competition=1699&amp;season=2025-2026&amp;division=1&amp;matchId=9&amp;team=222">Away II</a>
    </div>
    <div class="c085-lineup-table-player">
      <div class="c085-lineup-table-player-number">1</div>
      <div class="c085-lineup-table-player-name-text">
        <a class="c085-lineup-table-player-name-text c085-link" href="/fixtures-and-results/player-stats?playerId=2001">jo lowercase</a>
      </div>
    </div>
  </div>
</div>
"""

NO_LINEUP_HTML = """
<div class="c085-lineup-table-container">
  <div class="c085-lineup-table-content">
    <div class="c085-lineup-table-team-title">
      <a class="c085-lineup-table-team-title-text c085-link" href="/x?team=111">Home RFC</a>
    </div>
    <div class="c085-lineup-table-player">No lineup to show.</div>
  </div>
</div>
"""


def test_parse_lineup_teams_and_players():
    home, away = parse_lineup(LINEUP_HTML)
    assert (home.rfu_team_id, home.team_name) == (111, "Home RFC")
    assert (away.rfu_team_id, away.team_name) == (222, "Away II")

    starter, withheld, sub = home.players
    assert starter.rfu_player_id == 1001
    assert starter.display_name == "Alex McTest"
    assert (starter.shirt, starter.shirt_number, starter.is_substitute) == ("15", 15, False)

    assert withheld.rfu_player_id == 1002
    assert withheld.name_withheld is True
    assert withheld.display_name == "Name withheld"

    assert sub.display_name == "Sam Uppercase"
    assert (sub.shirt, sub.shirt_number, sub.is_substitute) == ("S1", 1, True)

    assert away.players[0].display_name == "Jo Lowercase"


def test_parse_lineup_without_published_lineup():
    assert parse_lineup(NO_LINEUP_HTML) == []
    assert parse_lineup("<html><body>no lineup markup</body></html>") == []


def test_clean_player_name_keeps_mixed_case():
    assert clean_player_name("  Mary-Jane\n\t\tO'Neill ") == "Mary-Jane O'Neill"
    assert clean_player_name("DE LA CRUZ") == "De La Cruz"


def _fixtures(filename):
    with open(os.path.join(SAMPLE_DIR, filename), encoding="utf-8") as fh:
        return RFUParser().parse_fixtures(fh.read())


def test_parse_fixtures_captures_match_id_for_played_match():
    fixtures = _fixtures("counties_1_western_west_2526.html")
    match = next(f for f in fixtures if f.home_team == "Torquay Athletic" and f.away_team == "Penryn")
    assert match.status == "Completed"
    assert match.rfu_match_id == 1272782


def test_parse_fixtures_captures_match_id_for_unplayed_match():
    fixtures = _fixtures("counties_2_devon.html")
    assert all(f.rfu_match_id for f in fixtures)
    assert 1280118 in {f.rfu_match_id for f in fixtures}
    assert len({f.rfu_match_id for f in fixtures}) == len(fixtures)
