import requests

URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
import os, sys  # noqa: E401
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rfu_parser.env import supabase_secret_key  # noqa: E402
KEY = supabase_secret_key()  # from .env; never hard-code keys (public repo)
HEADERS = {'apikey': KEY, 'Authorization': f'Bearer {KEY}'}

tables = ['divisions_cleanup_backup', 'divisions_null_id_backup']

def exists(tbl):
    r = requests.get(f"{URL}/rest/v1/{tbl}?select=*&limit=1", headers=HEADERS, timeout=20)
    return r.status_code == 200

def truncate(tbl):
    # Delete all rows
    r = requests.delete(f"{URL}/rest/v1/{tbl}", headers=HEADERS, timeout=30)
    return r.status_code, r.text

def main():
    for t in tables:
        print('Checking', t)
        if not exists(t):
            print(' - Table not found:', t)
            continue
        print(' - Table exists. Deleting all rows...')
        code, text = truncate(t)
        print(f' - DELETE -> HTTP {code}')

    print('\nSQL to DROP the tables (run in Supabase SQL Editor if you want to remove tables entirely):')
    print('DROP TABLE IF EXISTS divisions_cleanup_backup;')
    print('DROP TABLE IF EXISTS divisions_null_id_backup;')

if __name__ == "__main__":
    main()
