import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
total_remaining_dups = 0

for d in r_divs:
    did = d['id']
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&select=home_team,away_team", headers=headers).json()
    if not isinstance(r_fix, list): continue
    
    seen = set()
    for f in r_fix:
        k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
        if k in seen:
            total_remaining_dups += 1
            print(f"Residual dup in '{d['division_name']}' ({d['season']}): {k}")
        seen.add(k)

print(f"Verification Complete. Total duplicate pairings remaining across all {len(r_divs)} divisions: {total_remaining_dups}")
