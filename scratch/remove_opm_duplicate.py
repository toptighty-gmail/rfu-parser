import re
import requests

env = open('.env', encoding='utf-8').read()
SUPABASE_URL = re.search(r'SUPABASE_URL=(.+)', env).group(1).strip()
SUPABASE_KEY = (re.search(r'SUPABASE_SERVICE_ROLE_KEY=(.+)', env)
                or re.search(r'SUPABASE_ANON_KEY=(.+)', env)).group(1).strip()

headers = {
    'apikey': SUPABASE_KEY,
    'Authorization': f'Bearer {SUPABASE_KEY}',
}

# Stale duplicate: "Old Plymothian & Mannamedian" at position 7 in Counties 2
# Tribute Ale Devon (2026-2027), superseded by the "OPMs" row from the latest
# crawl at the same position.
ROW_ID = 'adadd376-4645-46be-8adf-b2a8c025196f'

resp = requests.delete(
    f'{SUPABASE_URL}/rest/v1/standings?id=eq.{ROW_ID}',
    headers=headers,
)
print(resp.status_code, resp.text)
