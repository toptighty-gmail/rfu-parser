import sys, os, json
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from rfu_parser.scraper import RFUParser

p = RFUParser()
url = "https://www.englandrugby.com/fixtures-and-results/search-results?competition=1699&season=2026-2027&division=75799"
try:
    res = p.fetch_and_parse(url, fallback_on_fail=False)
    out = {
        'division_name': res.division_name,
        'season': res.season,
        'rfu_competition_id': res.rfu_competition_id,
        'rfu_division_id': res.rfu_division_id,
        'standings_count': len(res.standings),
        'teams': [s.team_name for s in res.standings],
        'fixtures_count': len(res.fixtures),
        'first_10_fixtures': [
            {'date': f.date, 'time': f.time, 'home': f.home_team, 'away': f.away_team, 'status': f.status, 'round': f.round_num}
            for f in res.fixtures[:10]
        ]
    }
    print(json.dumps(out, indent=2))
except Exception as e:
    print('ERROR:', e)
    raise
