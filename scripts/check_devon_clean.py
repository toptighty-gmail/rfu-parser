import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
service_key = supabase_secret_key()  # from .env; never hard-code keys (public repo)
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r = requests.get(f'{url}/rest/v1/divisions?division_name=ilike.*devon*&select=*', headers=headers)
for d in r.json():
    did = d['id']
    r_st = requests.get(f'{url}/rest/v1/standings?division_id=eq.{did}&select=id', headers=headers)
    print(did, '|', d['season'], '|', d['division_name'], '| Standings:', len(r_st.json()))
