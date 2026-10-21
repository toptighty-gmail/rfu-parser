import os

from rfu_parser.lineups import (
    clean_player_name,
    parse_lineup,
    parse_match_events,
    parse_match_info,
    parse_player_match_ids,
)
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


# Trimmed copy of a match page's header and key-events accordion (made-up
# names): home events, an empty middle column, away events. Each name is
# followed by two non-breaking spaces, the minute and a prime mark.
EVENTS_HTML = """
<a href="/fixtures-and-results/search-results?matchId=9&amp;team=111" class="c042-team">
  <span class="c042-team-name">Home RFC</span></a>
<a href="/fixtures-and-results/search-results?matchId=9&amp;team=222" class="c042-team">
  <span class="c042-team-name">Away II</span></a>
<div class="c042-key-match-events-accordion-body-info">
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-try"></div>
    <div class="key-match-events-item">Alex McTest  12′</div>
  </div>
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-conversion"></div>
    <div class="key-match-events-item">Alex  McTest   13′</div>
  </div>
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-penalty-try"></div>
    <div class="key-match-events-item">  30′</div>
  </div>
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-yellow-card"></div>
    <div class="key-match-events-item">SAM UPPERCASE  41′</div>
  </div>
</div>
<div class="c042-key-match-events-accordion-body-info"></div>
<div class="c042-key-match-events-accordion-body-info">
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-drop-goal"></div>
    <div class="key-match-events-item">Jo Lowercase  55′</div>
  </div>
  <div class="c042-key-match-events-items">
    <div class="c042-event-item c042-red-card"></div>
    <div class="key-match-events-item">Jo Lowercase  70′</div>
  </div>
</div>
"""


def test_parse_match_events_by_team():
    events = parse_match_events(EVENTS_HTML)
    assert [(e.kind, e.player_name) for e in events[111]] == [
        ("try", "Alex McTest"),
        ("conversion", "Alex McTest"),
        ("yellow_card", "Sam Uppercase"),  # penalty try has no scorer
    ]
    assert [(e.kind, e.player_name) for e in events[222]] == [
        ("drop_goal", "Jo Lowercase"),
        ("red_card", "Jo Lowercase"),
    ]


def test_parse_match_events_without_events():
    assert parse_match_events("<html><body>no events</body></html>") == {}


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


MATCH_HEADER_HTML = """
<div class="c042-team"><span class="c042-team-name">Home RFC</span></div>
<div class="c042-score"><span class="c042-match-score">27 - 12</span> Full time</div>
<div class="c042-team"><span class="c042-team-name">Away II</span></div>
<div id="c042-event"><div id="c042-event-date"> Saturday 6 September 2025 00:00 </div></div>
"""


def test_parse_match_info_derives_season_from_date():
    info = parse_match_info(MATCH_HEADER_HTML)
    assert (info.home_team, info.away_team) == ("Home RFC", "Away II")
    assert (info.home_score, info.away_score) == (27, 12)
    assert info.match_date.isoformat() == "2025-09-06"
    assert info.season == "2025-2026"
    assert info.rfu_division_id is None


def test_parse_match_info_reads_season_and_division_from_links():
    html = MATCH_HEADER_HTML + (
        '<a href="/fixtures-and-results/search-results?competition=1699&amp;season=2024-2025'
        '&amp;division=66453&amp;matchId=9&amp;team=111">Home RFC</a>'
    )
    info = parse_match_info(html)
    assert (info.rfu_competition_id, info.season, info.rfu_division_id) == (1699, "2024-2025", 66453)


def test_parse_match_info_spring_date_belongs_to_previous_season():
    info = parse_match_info(MATCH_HEADER_HTML.replace("6 September 2025", "14 March 2026"))
    assert info.season == "2025-2026"


def test_parse_match_info_without_header():
    assert parse_match_info("<html><body>Page not found</body></html>") is None


def test_parse_player_match_ids_dedupes_in_page_order():
    html = """
    <a href="/fixtures-and-results/match-centre-community?playerId=5&amp;matchId=300">Home v Away</a>
    <a href="/fixtures-and-results/match-centre-community?playerId=5&amp;matchId=300">27 - 12</a>
    <a href="/fixtures-and-results/match-centre-community?playerId=5&amp;matchId=200">Away v Home</a>
    <a href="/fixtures-and-results/search-results?team=111">Home RFC</a>
    """
    assert parse_player_match_ids(html) == [300, 200]


def test_parse_player_matches_reads_competition_per_row():
    from rfu_parser.lineups import parse_player_matches

    def row(mid, comp):
        return (f'<tr><td>Sep 6, 25</td><td><a href="/fixtures-and-results/match-centre-community?playerId=5'
                f'&amp;matchId={mid}">A vs B</a></td><td>{comp}</td><td>20 - 14</td></tr>')

    html = "<table>" + row(300, "South West Division") + row(200, "Devon Colts Competitions") + "</table>"
    assert parse_player_matches(html) == [(300, "South West Division"), (200, "Devon Colts Competitions")]
