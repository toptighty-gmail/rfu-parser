import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=round_num.asc,date.asc", headers=headers).json()

print(f"Counties 2 Tribute Ale Devon Fixtures (Total: {len(r_fix)}):")
for f in r_fix:
    rnd = f.get('round_num', '')
    if any(r in rnd for r in ['Round 16', 'Round 17', 'Round 18', 'Round 19', 'Round 20', 'Round 21']):
        print(f"ID: {f['id']} | {rnd:10} | {f['date']:24} | {f['home_team']:30} v {f['away_team']:30} | Status: {f['status']}")
