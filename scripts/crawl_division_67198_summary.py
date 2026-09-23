import sys, os, json
repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)
from rfu_parser.scraper import RFUParser

url = "https://www.englandrugby.com/fixtures-and-results/search-results?competition=173&season=2025-2026&division=67198"
parser = RFUParser()
try:
    res = parser.fetch_and_parse(url, fallback_on_fail=False)
    print('Division:', res.division_name)
    print('Season:', res.season)
    print('Standings count:', len(res.standings) if res.standings else 0)
    print('Fixtures count:', len(res.fixtures) if res.fixtures else 0)
    print('\nFirst 12 standings:')
    for s in (res.standings or [])[:12]:
        print(f" - {s.position}: {s.team_name}")
    print('\nFirst 10 fixtures:')
    for f in (res.fixtures or [])[:10]:
        print(f" - {f.date} {f.time} | {f.home_team} v {f.away_team} | {f.round_num} | {f.status}")
except Exception as e:
    print('ERROR', e)
    raise
