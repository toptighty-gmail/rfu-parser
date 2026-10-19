import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

d1 = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3' # Counties 2 Tribute Ale Devon
d2 = 'bd913ae9-9f4a-482c-8f78-18da497b913b' # Counties 3 Tribute Ale Devon North & East

r1 = requests.get(f"{url}/rest/v1/standings?division_id=eq.{d1}", headers=headers).json()
print("Standings for Counties 2 Tribute Ale Devon (9214a6a4):")
for s in r1:
    print(f"  #{s.get('pos')} {s.get('team_name')}")

r2 = requests.get(f"{url}/rest/v1/standings?division_id=eq.{d2}", headers=headers).json()
print("\nStandings for Counties 3 Tribute Ale Devon North & East (bd913ae9):")
for s in r2:
    print(f"  #{s.get('pos')} {s.get('team_name')}")

# Also check fixtures
r1_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{d1}", headers=headers).json()
r2_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{d2}", headers=headers).json()
print(f"\nFixtures count: C2 Devon={len(r1_fix)}, C3 Devon North & East={len(r2_fix)}")
