import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r_logos = requests.get(f'{url}/rest/v1/team_logos?select=*', headers=headers)
logos = r_logos.json()

print(f"Total logos in table: {len(logos)}")
broken_logos = []
valid_logos = []

for item in logos:
    t_name = item['team_name']
    l_url = item['logo_url']
    if not l_url:
        broken_logos.append((t_name, 'NO_URL'))
        continue
    try:
        resp = requests.head(l_url, timeout=4, headers={'User-Agent': 'Mozilla/5.0'})
        if resp.status_code == 200:
            valid_logos.append((t_name, l_url))
        else:
            broken_logos.append((t_name, f"HTTP {resp.status_code}: {l_url}"))
    except Exception as e:
        broken_logos.append((t_name, f"ERROR: {e}"))

print(f"\nVALID LOGOS (HTTP 200): {len(valid_logos)}")
print(f"BROKEN / MISSING LOGOS: {len(broken_logos)}")

print("\n--- SAMPLE OF BROKEN LOGOS ---")
for b in broken_logos[:30]:
    print(f"  {b[0]} -> {b[1]}")
