import re
import requests

env = open('.env', encoding='utf-8').read()
SUPABASE_URL = re.search(r'SUPABASE_URL=(.+)', env).group(1).strip()
SUPABASE_KEY = (re.search(r'SUPABASE_SERVICE_ROLE_KEY=(.+)', env)
                or re.search(r'SUPABASE_ANON_KEY=(.+)', env)).group(1).strip()

headers = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
    'Content-Type': 'application/json',
}

CANONICAL = 'Old Plymothian & Mannamedian'
DIVISION_ID = None  # filled in below


def get(url):
    r = requests.get(f'{SUPABASE_URL}/rest/v1/{url}', headers=headers, timeout=30)
    r.raise_for_status()
    return r.json()


# 1. Resolve Counties 2 Tribute Ale Devon (2026-2027) division id
divs = get('divisions?rfu_division_id=eq.75799&season=eq.2026-2027&select=id')
DIVISION_ID = divs[0]['id']

# 2. Rename the surviving standings row from "OPMs" back to the full name
standings = get(f'standings?division_id=eq.{DIVISION_ID}&select=id,team_name')
for s in standings:
    if s['team_name'].strip().lower() == 'opms':
        r = requests.patch(
            f"{SUPABASE_URL}/rest/v1/standings?id=eq.{s['id']}",
            headers=headers, json={'team_name': CANONICAL},
        )
        print('standings rename:', r.status_code, s['id'])

# 3. Dedupe fixtures: for every fixture pair split across "OPMs" and the full
# name, keep the full-name row and delete the "OPMs" one.
fixtures = get(
    f'fixtures?division_id=eq.{DIVISION_ID}'
    f'&select=id,date,home_team,away_team,round_num'
)
deleted = 0
for f in fixtures:
    if (f['home_team'].strip().lower() == 'opms'
            or f['away_team'].strip().lower() == 'opms'):
        r = requests.delete(
            f"{SUPABASE_URL}/rest/v1/fixtures?id=eq.{f['id']}",
            headers=headers,
        )
        print('fixture delete:', r.status_code, f['date'], f['home_team'], 'vs', f['away_team'])
        deleted += 1

print(f'Done. Deleted {deleted} duplicate "OPMs" fixture rows.')
