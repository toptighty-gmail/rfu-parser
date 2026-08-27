import os
import pytest
from rfu_parser.storage import CustomFixtureStorage

def test_custom_fixture_crud():
    # 1. Add fixture
    item = CustomFixtureStorage.add_fixture(
        date_str="2025-11-20",
        home_team="Plymstock Albion Oaks RFC",
        away_team="Exeter Saracens",
        season="2025-2026",
        time_str="14:30",
        venue="Friendly Derby"
    )
    assert item["id"] is not None
    assert item["home_team"] == "Plymstock Albion Oaks RFC"
    assert item["round_num"] == "Friendly"

    # 2. Get fixtures for team and season
    fixtures = CustomFixtureStorage.get_fixtures_for_season_and_team("2025-2026", "plymstock")
    assert len(fixtures) >= 1
    found = [f for f in fixtures if getattr(f, "id", "") == item["id"]]
    assert len(found) == 1
    assert found[0].venue == "Friendly Derby"

    # 3. Update fixture (record result)
    updated = CustomFixtureStorage.update_fixture(item["id"], {
        "home_score": 28,
        "away_score": 14,
        "status": "Completed"
    })
    assert updated is not None
    assert updated["home_score"] == 28
    assert updated["away_score"] == 14
    assert updated["status"] == "Completed"

    # 4. Delete fixture
    deleted = CustomFixtureStorage.delete_fixture(item["id"])
    assert deleted is True
