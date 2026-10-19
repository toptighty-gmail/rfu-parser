import requests
import concurrent.futures

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r_logos = requests.get(f'{url}/rest/v1/team_logos?select=*', headers=headers)
logos = r_logos.json()

def check_logo(item):
    name = item['team_name']
    logo = item.get('logo_url')
    if not logo:
        return (name, False, 'NO_URL')
    try:
        r = requests.head(logo, timeout=3, headers={'User-Agent': 'Mozilla/5.0'})
        return (name, r.status_code == 200, f'HTTP {r.status_code}', logo)
    except Exception as e:
        return (name, False, str(e), logo)

results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
    results = list(executor.map(check_logo, logos))

valid = [r for r in results if r[1]]
broken = [r for r in results if not r[1]]

print(f"Total logos: {len(results)}")
print(f"Valid (HTTP 200): {len(valid)}")
print(f"Broken / Missing: {len(broken)}")

print("\n--- SAMPLE BROKEN LOGOS ---")
for b in broken[:40]:
    print(f"  {b[0]} -> {b[2]} ({b[3] if len(b) > 3 else ''})")
