import requests
import json
import os

URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
KEY = supabase_secret_key()  # from .env; never hard-code keys (public repo)
HEADERS = {'apikey': KEY, 'Authorization': f'Bearer {KEY}'}

tables = ['divisions_cleanup_backup', 'divisions_null_id_backup']

out_dir = os.path.join(os.getcwd(), 'backups')
os.makedirs(out_dir, exist_ok=True)

def fetch_table(tbl):
    print('Fetching', tbl)
    r = requests.get(f"{URL}/rest/v1/{tbl}?select=*", headers=HEADERS, timeout=60)
    if r.status_code != 200:
        print('Failed to fetch', tbl, r.status_code, r.text)
        return None
    return r.json()

def save(tbl, data):
    path = os.path.join(out_dir, f"{tbl}.json")
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print('Saved', path)

def main():
    for t in tables:
        data = fetch_table(t)
        if data is None:
            print('Skipping', t)
            continue
        save(t, data)

if __name__ == '__main__':
    main()
