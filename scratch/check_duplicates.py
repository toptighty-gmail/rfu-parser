import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Let's inspect fixtures for Plymstock Oaks
r = requests.get(url + '/rest/v1/fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*)&order=date.asc', headers=headers)
fixtures = r.json()
print('Total Plymstock fixtures in DB:', len(fixtures))

for f in fixtures:
    fid = f['id'][:8]
    did = f.get('division_id', '')[:8] if f.get('division_id') else 'none'
    rnd = f.get('round_num', '')
    dt = f.get('date', '')
    tm = f.get('time', '')
    h = f.get('home_team', '')
    a = f.get('away_team', '')
    print(f"{fid} | Div: {did} | {rnd:10} | {dt:24} {tm:5} | {h} v {a}")

print('\n=== Custom fixtures for Plymstock ===')
r2 = requests.get(url + '/rest/v1/custom_fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*,context_team.ilike.*plymstock*)', headers=headers)
cust = r2.json()
for f in cust:
    fid = f['id'][:8]
    did = f.get('division_id', '')[:8] if f.get('division_id') else 'none'
    dt = f.get('date', '')
    tm = f.get('time', '')
    h = f.get('home_team', '')
    a = f.get('away_team', '')
    print(f"{fid} | Div: {did} | {dt:24} {tm:5} | {h} v {a}")
