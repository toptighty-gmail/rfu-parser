import requests
from bs4 import BeautifulSoup
import re
import concurrent.futures
import urllib.parse
import sys

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}


def get_session():
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    return s


def discover_divisions(season='2026-2027'):
    s = get_session()
    competitions = [
        (1699, 'South West'),
        (1605, 'National'),
        (261, 'London & SE'),
        (1597, 'Midlands'),
        (1623, 'North'),
        (173, 'National'),
        (1764, 'National')
    ]
    divisions_found = []
    seen_div_ids = set()

    for comp_id, region in competitions:
        try:
            url = f'https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season}'
            r = s.get(url, timeout=12)
            soup = BeautifulSoup(r.text, 'html.parser')
            for a in soup.find_all('a', href=True):
                href = a['href']
                if 'division=' in href:
                    m = re.search(r'division=(\d+)', href)
                    if m:
                        div_num = int(m.group(1))
                        name = a.text.strip()
                        if name and div_num not in seen_div_ids:
                            seen_div_ids.add(div_num)
                            divisions_found.append({
                                'competition_id': comp_id,
                                'division_id': div_num,
                                'division_name': name,
                                'region': region,
                                'season': season,
                                'url': f'https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season}&division={div_num}'
                            })
        except Exception as e:
            print(f'Error exploring competition {comp_id}: {e}', file=sys.stderr)
    return divisions_found


def existing_divisions_in_db(season='2026-2027'):
    r = requests.get(f"{SUPABASE_URL}/rest/v1/divisions?season=eq.{urllib.parse.quote(season)}&select=rfu_division_id,division_name,id", headers=headers, timeout=20)
    if r.status_code != 200:
        print('Failed to query existing divisions:', r.status_code, r.text, file=sys.stderr)
        return []
    return r.json()


def upsert_division_into_db(div_info):
    dname = div_info['division_name']
    season = div_info['season']
    comp_id = div_info['competition_id']
    div_num = div_info['division_id']
    region = div_info['region']
    url = div_info['url']

    # Determine tier
    tier = 8
    dl = dname.lower()
    if 'premiership' in dl: tier = 1
    elif 'championship' in dl: tier = 2
    elif 'national 1' in dl or 'national league 1' in dl: tier = 3
    elif 'national 2' in dl or 'national league 2' in dl: tier = 4
    elif 'regional 1' in dl: tier = 5
    elif 'regional 2' in dl: tier = 6
    elif 'counties 1' in dl: tier = 7
    elif 'counties 2' in dl: tier = 8
    elif 'counties 3' in dl: tier = 9
    elif 'counties 4' in dl: tier = 10

    payload = {
        'division_name': dname,
        'season': season,
        'rfu_competition_id': comp_id,
        'rfu_division_id': div_num,
        'tier_level': tier,
        'region': region,
        'source_url': url,
        'updated_at': 'now()'
    }
    r = requests.post(f"{SUPABASE_URL}/rest/v1/divisions", headers=headers, json=payload, timeout=30)
    return r.status_code, r.text


def main(apply_changes=False, seasons=None):
    if not seasons:
        seasons = ['2026-2027']

    for season in seasons:
        print('Discovering divisions for', season)
        found = discover_divisions(season)
        print('Discovered', len(found), 'divisions')

        existing = existing_divisions_in_db(season)
        existing_ids = {int(row['rfu_division_id']) for row in existing if row.get('rfu_division_id')}

        missing = [d for d in found if d['division_id'] not in existing_ids]

        print('\nExisting divisions in DB (count):', len(existing))
        print('Missing divisions to populate:', len(missing))
        for d in missing:
            print(f" - {d['division_id']} | {d['division_name']} | comp={d['competition_id']} | region={d['region']}")

        if apply_changes and missing:
            print('\nApplying upserts for missing divisions...')
            for d in missing:
                status, text = upsert_division_into_db(d)
                print(f"Upsert {d['division_id']} -> {status}")
        else:
            print('\nDry-run complete. To apply changes, run with --apply')

if __name__ == '__main__':
    apply_flag = '--apply' in sys.argv
    # support --season "2025-2026" or --seasons "2025-2026,2024-2025"
    seasons_arg = None
    for i, a in enumerate(sys.argv):
        if a.startswith('--season='):
            seasons_arg = a.split('=', 1)[1]
        if a == '--season' and i + 1 < len(sys.argv):
            seasons_arg = sys.argv[i + 1]
        if a.startswith('--seasons='):
            seasons_arg = a.split('=', 1)[1]
        if a == '--seasons' and i + 1 < len(sys.argv):
            seasons_arg = sys.argv[i + 1]

    seasons = None
    if seasons_arg:
        seasons = [s.strip() for s in seasons_arg.split(',') if s.strip()]

    main(apply_flag, seasons)
