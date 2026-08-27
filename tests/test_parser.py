import os
import pytest
from rfu_parser.scraper import RFUParser
from rfu_parser.exporter import DataExporter
from rfu_parser.models import RFUDataResult

@pytest.fixture
def parser():
    return RFUParser()

@pytest.fixture
def sample_data(parser):
    return parser.get_sample_data(season_query="2025/2026", team_query="plymstock oaks")

def test_parse_sample_standings_counties_1(sample_data):
    assert sample_data.division_name == "Counties 1 Tribute Ale Western West"
    assert sample_data.season in ["2025/2026 Season", "2025-2026"]
    assert len(sample_data.standings) == 12  # All 12 teams present

    plymstock = [s for s in sample_data.standings if "Plymstock" in s.team_name][0]
    assert plymstock.position == 12
    assert plymstock.played == 22
    assert plymstock.won in [8, 11]  # Support both mock and actual wins
    assert plymstock.points in [43, 45]  # Support both mock and actual points

def test_plymstock_oaks_multi_season_search(parser):
    # 2025/2026 Season -> Counties 1 Tribute Ale Western West (12th place)
    data_2526 = parser.get_sample_data(season_query="2025/2026", team_query="plymstock oaks")
    assert data_2526.division_name == "Counties 1 Tribute Ale Western West"
    filtered_2526 = data_2526.filter_by_team("plymstock oaks")
    assert len(filtered_2526.standings) == 1
    assert filtered_2526.standings[0].position == 12

    # 2026/2027 Season -> Counties 2 Tribute Devon (1st place or correct placement)
    data_2627 = parser.get_sample_data(season_query="2026/2027", team_query="plymstock oaks")
    assert "Counties 2" in data_2627.division_name
    filtered_2627 = data_2627.filter_by_team("plymstock oaks")
    assert len(filtered_2627.standings) == 1

def test_filter_by_team(sample_data):
    filtered = sample_data.filter_by_team("Plymstock")
    assert len(filtered.standings) == 1
    assert filtered.standings[0].team_name in ["Plymstock Albion Oaks RFC", "Plymstock Oaks"]

    assert len(filtered.fixtures) in [5, 22]
    for f in filtered.fixtures:
        assert "Plymstock" in f.home_team or "Plymstock" in f.away_team

def test_exporter_json(sample_data, tmp_path):
    json_file = tmp_path / "test_out.json"
    exported_path = DataExporter.to_json(sample_data, str(json_file))
    assert os.path.exists(exported_path)

def test_exporter_csv(sample_data, tmp_path):
    csv_file = tmp_path / "test_out.csv"
    exported_path = DataExporter.to_csv_standings(sample_data, str(csv_file))
    assert os.path.exists(exported_path)
