import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Clean out the 4 test fixtures from f2ec8c92 and 3b612c90
requests.delete(f"{url}/rest/v1/fixtures?division_id=eq.f2ec8c92-d8c0-4084-9610-e372dc1af3f1", headers=headers)
requests.delete(f"{url}/rest/v1/fixtures?division_id=eq.3b612c90-7c57-49aa-b7dd-5896a3f3d8df", headers=headers)

# Re-check Barnes vs Dorking
r = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*barnes*,away_team.ilike.*barnes*)", headers=headers).json()
print(f"Remaining Barnes fixtures: {len(r)}")
for f in r:
    print(f"  {f['id'][:8]} | Div: {f.get('division_id')} | {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")
