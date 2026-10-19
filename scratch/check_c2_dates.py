import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}", headers=headers).json()

# Group by date
by_date = {}
for f in r_fix:
    d = f['date']
    if d not in by_date:
        by_date[d] = []
    by_date[d].append(f)

print("Unique dates in C2 Devon and match count:")
for d, matches in by_date.items():
    print(f"  {d:25} -> {len(matches)} matches")
