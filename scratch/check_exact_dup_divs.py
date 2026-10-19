import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Check Barnes vs Dorking
r = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*barnes*,away_team.ilike.*barnes*)", headers=headers).json()
print(f"Barnes fixtures count: {len(r)}")
for f in r:
    print(f"  {f['id'][:8]} | Div: {f.get('division_id')} | {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")

# Check all division names in divisions table for duplicates
r_divs = requests.get(url + "/rest/v1/divisions?select=id,division_name,season", headers=headers).json()
div_counts = {}
for d in r_divs:
    k = (d['division_name'].strip(), d['season'].strip())
    if k not in div_counts:
        div_counts[k] = []
    div_counts[k].append(d['id'])

exact_dup_divs = {k: v for k, v in div_counts.items() if len(v) > 1}
print(f"\nExact duplicate division records in divisions table: {len(exact_dup_divs)}")
for (name, season), ids in exact_dup_divs.items():
    print(f"  - '{name}' ({season}) -> IDs: {ids}")
