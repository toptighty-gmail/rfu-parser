import requests
from bs4 import BeautifulSoup
import re
import time

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates,return=representation'
}

def sync_season_throttled(season='2023-2024'):
    print(f"Syncing season {season} with rate limiting...")
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    s.get('https://www.englandrugby.com/fixtures-and-results')

    r_teams = requests.get(f'{SUPABASE_URL}/rest/v1/teams?select=rfu_team_id,team_name', headers=headers)
    teams_db = r_teams.json() if r_teams.status_code == 200 else []
    team_lookup = {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_db}

    competitions = [
        (1699, 'South West'),
        (1605, 'National'),
        (261, 'London & SE'),
        (1597, 'Midlands'),
        (1623, 'North'),
    ]

    for comp_id, region in competitions:
        try:
            url = f'https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season}'
            r = s.get(url, timeout=10)
            soup = BeautifulSoup(r.text, 'html.parser')

            for a in soup.find_all('a', href=True):
                href = a['href']
                if 'division=' in href:
                    m = re.search(r'division=(\d+)', href)
                    if not m: continue
                    div_num = int(m.group(1))
                    dname = a.text.strip()
                    if not dname: continue

                    div_url = f'https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season}&division={div_num}'
                    time.sleep(0.4)
                    r_div = s.get(div_url, timeout=10)
                    if r_div.status_code != 200: continue
                    div_soup = BeautifulSoup(r_div.text, 'html.parser')
                    tbl = div_soup.find('table')
                    if not tbl: continue

                    tier = 8
                    dl = dname.lower()
                    if 'regional 1' in dl: tier = 5
                    elif 'regional 2' in dl: tier = 6
                    elif 'counties 1' in dl: tier = 7
                    elif 'counties 2' in dl: tier = 8
                    elif 'counties 3' in dl: tier = 9
                    elif 'counties 4' in dl: tier = 10

                    r_upsert = requests.post(
                        f'{SUPABASE_URL}/rest/v1/divisions',
                        headers=headers,
                        json={
                            'division_name': dname,
                            'season': season,
                            'rfu_competition_id': comp_id,
                            'rfu_division_id': div_num,
                            'tier_level': tier,
                            'region': region,
                            'source_url': div_url,
                            'updated_at': 'now()'
                        }
                    )
                    
                    if r_upsert.status_code not in [200, 201] or not r_upsert.json(): continue
                    db_div_id = r_upsert.json()[0]['id']

                    standings_payload = []
                    for tr in tbl.find_all('tr'):
                        tds = [td.text.strip() for td in tr.find_all('td')]
                        if len(tds) >= 12:
                            pos = int(tds[0]) if tds[0].isdigit() else 0
                            tname = tds[1]
                            played = int(tds[2]) if tds[2].isdigit() else 0
                            won = int(tds[3]) if tds[3].isdigit() else 0
                            drawn = int(tds[4]) if tds[4].isdigit() else 0
                            lost = int(tds[5]) if tds[5].isdigit() else 0
                            pf = int(tds[6]) if tds[6].isdigit() else 0
                            pa = int(tds[7]) if tds[7].isdigit() else 0
                            pd = int(tds[8]) if tds[8].replace('-', '').isdigit() else 0
                            tb = int(tds[9]) if tds[9].isdigit() else 0
                            lb = int(tds[10]) if tds[10].isdigit() else 0
                            pts = int(tds[11]) if tds[11].replace('-', '').isdigit() else 0

                            tid = team_lookup.get(tname.lower().strip())

                            standings_payload.append({
                                'division_id': db_div_id,
                                'position': pos,
                                'team_name': tname,
                                'rfu_team_id': tid,
                                'played': played,
                                'won': won,
                                'drawn': drawn,
                                'lost': lost,
                                'points_for': pf,
                                'points_against': pa,
                                'points_diff': pd,
                                'try_bonus': tb,
                                'lose_bonus': lb,
                                'points': pts,
                                'updated_at': 'now()'
                            })

                    if standings_payload:
                        requests.post(f'{SUPABASE_URL}/rest/v1/standings', headers=headers, json=standings_payload)
                        print(f"  [OK] [{season}] {dname:<40} -> {len(standings_payload)} teams synced")

        except Exception as e:
            print(f"Error on comp {comp_id}: {e}")

if __name__ == '__main__':
    sync_season_throttled('2023-2024')
