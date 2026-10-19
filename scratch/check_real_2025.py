import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did_real_2025 = '36dc0266-34c2-485e-a751-80da9935cf94'
r1 = requests.get(f"{url}/rest/v1/divisions?id=eq.{did_real_2025}", headers=headers).json()
r1_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did_real_2025}", headers=headers).json()
print(f"Division {did_real_2025}: {r1} -> {len(r1_fix)} fixtures")
if r1_fix:
    print(f"  Sample date: {r1_fix[0].get('date')} | {r1_fix[0].get('home_team')} v {r1_fix[0].get('away_team')}")
