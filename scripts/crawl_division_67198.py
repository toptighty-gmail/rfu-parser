import sys
import os
import json

# Ensure repo root is on sys.path so local package imports work
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

from rfu_parser.scraper import RFUParser

url = "https://www.englandrugby.com/fixtures-and-results/search-results?competition=173&season=2025-2026&division=67198"
parser = RFUParser()
try:
    res = parser.fetch_and_parse(url, fallback_on_fail=False)
    out = {
        'division_name': res.division_name,
        'season': res.season,
        'standings_count': len(res.standings) if res.standings else 0,
        'standings': [{
            'position': s.position,
            'team_name': s.team_name
        } for s in res.standings],
        'fixtures_count': len(res.fixtures) if res.fixtures else 0,
        'fixtures': [{
            'date': f.date,
            'time': f.time,
            'home_team': f.home_team,
            'away_team': f.away_team,
            'round_num': f.round_num,
            'status': f.status
        } for f in res.fixtures]
    }
    print(json.dumps(out, indent=2))
except Exception as e:
    print('ERROR', e)
    raise
