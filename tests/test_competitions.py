import os
import sys

import pytest

from rfu_parser.competitions import (
    CUPS,
    ELITE,
    INTERNATIONALS,
    MENS_LEAGUES,
    MERIT_TABLES,
    WOMENS_CUPS,
    WOMENS_LEAGUES,
    classify,
    clean_name,
    merge_competitions,
    parse_competition_divisions,
)

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(__file__)), "scripts"))
from discover_competitions import DivisionCatalog  # noqa: E402


@pytest.mark.parametrize("cid,name,label,elite,expected", [
    (1699, "South West Division", "Senior League", False, MENS_LEAGUES),
    (202, "Hampshire Merit Tables", "Senior League", False, MERIT_TABLES),
    (2106, "RFU Men's Community Cup", "Senior Cup", False, CUPS),
    (1782, "Women's Competitions", "Womens League", False, WOMENS_LEAGUES),
    (1783, "Women's Cup Competitions", "Womens Cup", False, WOMENS_CUPS),
    (2645, "Midlands East Ladies T1 League", "Senior League", False, WOMENS_LEAGUES),
    (0, "Internationals", None, True, INTERNATIONALS),
    (1979, "Red Bull International 7s", "Senior League", False, INTERNATIONALS),
    (5, "Gallagher Prem", None, False, ELITE),
    (9, "European Rugby Champions Cup", None, True, ELITE),
    # Left out: age grade, university, girls', junk entries, unknown labels
    (2305, "CRFU U16'S BOYS LEAGUE 25-26", "Youth", False, None),
    (2004, "NLD Colts League", "Colts", False, None),
    (1684, "Continental Tyres Schools U15 Cup", "School", False, None),
    (42, "Men's BUCS Super Rugby", "BUSA", False, None),
    (154, "Girls Cups", "Womens Cup", False, None),
    (1664, "RFU ACE Boys League", "School", False, None),
    (2630, "Paul Harris Devon League-wrong", "Senior League", False, None),
    (999, "Something", "", False, None),
])
def test_classify(cid, name, label, elite, expected):
    assert classify(cid, name, label, elite) == expected


def test_merge_prefers_directory_name_and_drops_unlabelled_extras():
    search = [
        {"_id": 77, "listType": "CompetitionType", "name": "Paul Harris Devon League", "league": "Senior League"},
        {"_id": 2253, "listType": "CompetitionType", "name": "CRFU U16'S GIRLS", "league": "Youth"},
        {"_id": 16976, "listType": "TeamType", "name": "Plymstock Oaks"},
    ]
    directory = {77: "Devon Merit Tables", 5: "Gallagher Prem", 1234: "Some Unlabelled Thing"}
    merged = merge_competitions(search, directory)
    assert merged[77].name == "Devon Merit Tables" and merged[77].category == MERIT_TABLES
    assert merged[5].category == ELITE
    assert 2253 not in merged and 16976 not in merged and 1234 not in merged


def test_clean_name_fixes_replacement_character():
    assert clean_name("RFU Men�s  Community Cup ") == "RFU Men’s Community Cup"


def _card(cid, did, text):
    return (f'<a class="c026_accordion_items_card c026_accordion_items_card_link" '
            f'href="/fixtures-and-results/search-results?competition={cid}&amp;season=2025-2026&amp;division={did}">{text}</a>')


def test_parse_divisions_from_accordion_cards():
    html = "".join([
        _card(2106, 69369, "Counties 1 Championship - Round 1"),
        _card(2106, 69369, "Counties 1 Championship - Round 1"),  # repeated for mobile
        _card(2106, 71772, "Counties 1 Championship - Round 2"),
        _card(173, 57597, "Champ Rugby"),  # quick link to another competition
        '<a href="/fixtures-and-results/search-results?competition=2106&amp;division=69369&amp;team=5">Team</a>',
    ])
    divs = parse_competition_divisions(html, 2106, "RFU Men's Community Cup")
    assert [(d.rfu_division_id, d.name) for d in divs] == [
        (69369, "Counties 1 Championship - Round 1"), (71772, "Counties 1 Championship - Round 2")]


def test_parse_single_division_competition_takes_competition_name():
    html = ('<a class="viewAll" href="/fixtures-and-results/search-results?competition=0&amp;season=2025-2026'
            '&amp;division=64487#fixtures">View all fixtures</a>'
            '<a class="coh-style-sub-header-right" href="/fixtures-and-results/search-results?competition=0'
            '&amp;season=2025-2026&amp;division=64487">1</a>')
    divs = parse_competition_divisions(html, 0, "Men's Internationals")
    assert [(d.rfu_division_id, d.name) for d in divs] == [(64487, "Men's Internationals")]


class FakeDb:
    def __init__(self, rows):
        self.rows, self.upserts, self.patches = rows, [], []

    def get(self, path):
        return self.rows

    def upsert(self, table, rows, on_conflict):
        self.upserts.extend(rows)

    def patch(self, path, values):
        self.patches.append((path, values))


def test_catalog_adds_only_new_divisions_with_unique_names():
    from rfu_parser.competitions import Competition, DivisionLink
    db = FakeDb([
        {"id": "a", "division_name": "Final", "rfu_division_id": 1, "rfu_competition_id": 26, "source_url": ""},
        {"id": "b", "division_name": "Counties 2 Devon", "rfu_division_id": None, "rfu_competition_id": None,
         "source_url": "https://x/search-results?competition=1699&season=2025-2026&division=75799"},
    ])
    catalog = DivisionCatalog(db, "2025-2026")
    cup = Competition(2106, "RFU Men's Community Cup", CUPS, "Senior Cup", False)
    added = catalog.add(cup, [DivisionLink(2, "Final"), DivisionLink(3, "Round 1"), DivisionLink(1, "Final")])
    assert added == 2
    assert [r["division_name"] for r in db.upserts] == ["RFU Men's Community Cup - Final", "Round 1"]
    assert all(r["rfu_competition_id"] == 2106 for r in db.upserts)
    # An existing division missing its ids gets them filled in, not duplicated
    league = Competition(1699, "South West Division", MENS_LEAGUES, "Senior League", False)
    assert catalog.add(league, [DivisionLink(75799, "Counties 2 Tribute Ale Devon")]) == 0
    assert db.patches == [("divisions?id=eq.b", {"rfu_competition_id": 1699, "rfu_division_id": 75799})]


def test_catalog_prefers_rows_with_ids():
    from rfu_parser.competitions import Competition, DivisionLink
    db = FakeDb([
        {"id": "dup", "division_name": "Champ Rugby", "rfu_division_id": None, "rfu_competition_id": None,
         "source_url": "https://x/search-results?competition=173&season=2026-2027&division=76143"},
        {"id": "real", "division_name": "Championship", "rfu_division_id": 76143, "rfu_competition_id": 173,
         "source_url": ""},
    ])
    catalog = DivisionCatalog(db, "2026-2027")
    elite = Competition(173, "Champ Rugby", ELITE, "", True)
    assert catalog.add(elite, [DivisionLink(76143, "Champ Rugby")]) == 0
    assert db.patches == []  # the row with the id is used; the duplicate isn't "repaired" into a clash


def _windows(rows):
    from discover_competitions import SeasonWindows

    class Db:
        def get(self, path):
            return rows

    return SeasonWindows(Db())


LEAGUES = [{"season": s, "rfu_division_id": i, "rfu_competition_id": 1699, "source_url": ""}
           for s, i in [("2024-2025", 56483), ("2025-2026", 66415), ("2026-2027", 75773)]]


def test_windows_reject_other_seasons_divisions():
    w = _windows(LEAGUES)
    assert w.accepts(75800, "2026-2027")                       # this season's league batch
    assert w.accepts(75771, "2026-2027")                       # merit table made just before the leagues
    assert not w.accepts(75566, "2026-2027")                   # last season's county championship final
    assert not w.accepts(7739, "2026-2027")                    # discontinued cup from years ago
    assert w.accepts(75566, "2025-2026")
    assert not w.accepts(75800, "2025-2026")                   # next season's division


def test_windows_internationals_created_early():
    w = _windows(LEAGUES)
    assert w.accepts(64487, "2025-2026", international=True)   # tour series made before the leagues
    assert not w.accepts(64487, "2025-2026")


def test_windows_one_season_per_division():
    w = _windows(LEAGUES + [{"season": "2025-2026", "rfu_division_id": 72339, "rfu_competition_id": 3,
                             "source_url": ""}])
    assert not w.accepts(72339, "2026-2027", international=True)  # already 2025-26's
    w.claim(79000, "2026-2027")
    assert w.accepts(79000, "2026-2027")                       # re-reading the same season is fine


def test_fixtures_in_season_checks_dates():
    import datetime
    from types import SimpleNamespace
    import discover_competitions as dc
    from rfu_parser.competitions import Competition, DivisionLink

    assert dc.season_of(datetime.date(2022, 6, 18)) == "2021-2022"
    assert dc.season_of(datetime.date(2022, 9, 3)) == "2022-2023"

    def fetcher_for(dates):
        cards = "".join(
            f'<div class="resultWrapper"><div class="coh-style-card-left-date">{d}</div>'
            f'<div class="coh-style-card-body"><div class="coh-style-card-scores">'
            f'<div class="coh-style-hometeam"><a>Home</a></div><div class="coh-style-away-team"><a>Away</a></div>'
            f'</div></div></div>' for d in dates)
        return SimpleNamespace(get=lambda url, params=None: cards)

    prem = Competition(5, "Gallagher Prem", ELITE, "", False)
    link = DivisionLink(75971, "1")
    assert dc.fixtures_in_season(fetcher_for(["Saturday, 21 May 2022", "Saturday, 18 Jun 2022"]), prem, link, "2021-2022")
    assert not dc.fixtures_in_season(fetcher_for(["Saturday, 21 May 2022"]), prem, link, "2026-2027")
    assert not dc.fixtures_in_season(fetcher_for([]), prem, link, "2021-2022")
