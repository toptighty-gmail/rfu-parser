import os
import re
import requests
from urllib.parse import urljoin

ENV_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '.env'))

def load_env(path):
    data = {}
    try:
        with open(path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                k, v = line.split('=', 1)
                data[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        print(f".env not found at: {path}")
    return data


def try_supabase(env):
    supabase_url = env.get('SUPABASE_URL') or env.get('SUPABASE_PROJECT_URL')
    service_key = env.get('SUPABASE_SERVICE_ROLE_KEY') or env.get('SUPABASE_ANON_KEY') or env.get('SUPABASE_KEY')
    if not supabase_url:
        print('SUPABASE_URL not found in .env')
        return
    if not service_key:
        print('No Supabase key found in .env (SERVICE_ROLE or ANON)')
        return

    # Normalize URL
    if supabase_url.endswith('/'):
        supabase_url = supabase_url[:-1]

    endpoint = supabase_url + '/rest/v1/divisions?select=id&limit=1'
    headers = {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'Content-Type': 'application/json'
    }

    try:
        r = requests.get(endpoint, headers=headers, timeout=15)
        status = r.status_code
        if status == 200:
            print('OK: Supabase REST request succeeded (200). Key appears valid and can access `divisions` table.')
        elif status in (401, 403):
            print(f'AUTH ERROR: HTTP {status} — key invalid or insufficient privileges for REST requests to `divisions`.')
        elif status == 404:
            print('NOT FOUND: HTTP 404 — REST endpoint or `divisions` table not found (but authentication may still be valid).')
        else:
            print(f'HTTP {status}: {r.text[:500]}')
    except requests.exceptions.RequestException as e:
        print('Network/Error:', str(e))

if __name__ == "__main__":
    env = load_env(ENV_PATH)
    try_supabase(env)
