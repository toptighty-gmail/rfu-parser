import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# 1. Fetch division
r_div = requests.get(f'{url}/rest/v1/divisions?division_name=ilike.*Counties%202%20Tribute%20Devon*&select=*', headers=headers)
divs = r_div.json()
print('Divisions matching:', divs)

for d in divs:
    did = d['id']
    season = d['season']
    dname = d['division_name']
    r_st = requests.get(f'{url}/rest/v1/standings?division_id=eq.{did}&select=*&order=position.asc', headers=headers)
    rows = r_st.json()
    print(f"\n=== Standings for {dname} ({season}) [ID: {did}] (Total: {len(rows)}) ===")
    for r in rows:
        print(f"{r.get('position'):2d}. {r.get('team_name'):<25} P:{r.get('played'):2d} W:{r.get('won'):2d} D:{r.get('drawn'):2d} L:{r.get('lost'):2d} Pts:{r.get('points'):3d}")
