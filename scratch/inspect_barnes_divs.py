import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

ids = ['f2ec8c92-d8c0-4084-9610-e372dc1af3f1', '3b612c90-7c57-49aa-b7dd-5896a3f3d8df']
for did in ids:
    r = requests.get(f"{url}/rest/v1/divisions?id=eq.{did}", headers=headers).json()
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}", headers=headers).json()
    print(f"Div ID: {did} -> {r} (Fixtures: {len(r_fix)})")
