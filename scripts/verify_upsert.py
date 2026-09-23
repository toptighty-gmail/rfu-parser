import os
import sys
import requests

base = os.environ.get('SUPABASE_URL', '').rstrip('/')
key = os.environ.get('SUPABASE_SERVICE_ROLE_KEY') or os.environ.get('SUPABASE_ANON_KEY') or os.environ.get('SUPABASE_KEY')
if not base or not key:
    print('MISSING_ENV')
    sys.exit(1)

division_id = 'aface5d1-7f63-478b-b723-79500eda3067'
headers = {'apikey': key, 'Authorization': f'Bearer {key}'}

def get_json(path):
    r = requests.get(path, headers=headers, timeout=30)
    r.raise_for_status()
    return r.json()

try:
    div = get_json(f"{base}/rest/v1/divisions?id=eq.{division_id}&select=*")
    stand = get_json(f"{base}/rest/v1/standings?division_id=eq.{division_id}&select=id")
    fix = get_json(f"{base}/rest/v1/fixtures?division_id=eq.{division_id}&select=id")
    print('DIV_ROWS:', len(div))
    print('STANDINGS_ROWS:', len(stand))
    print('FIXTURES_ROWS:', len(fix))
    if div:
        print('DIVISION:', div[0].get('division_name'), div[0].get('season'))
except Exception as e:
    print('ERROR', e)
    raise
