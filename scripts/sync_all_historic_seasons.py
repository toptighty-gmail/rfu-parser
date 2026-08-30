import requests
from bs4 import BeautifulSoup
import re
import concurrent.futures

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates,return=representation'
}

def get_session():
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    return s

def fetch_teams_lookup():
    r_teams = requests.get(f'{SUPABASE_URL}/rest/v1/teams?select=rfu_team_id,team_name', headers=headers)
    teams_db = r_teams.json() if r_teams.status_code == 200 else []
    return {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_db}

def discover_season_divisions(season):
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
            r = s.get(url, timeout=10)
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
            print(f"Error exploring competition {comp_id} for {season}: {e}")

    return divisions_found

def sync_single_div(div_info, team_lookup):
    s = get_session()
    url = div_info['url']
    dname = div_info['division_name']
    season = div_info['season']
    comp_id = div_info['competition_id']
    div_num = div_info['division_id']
    region = div_info['region']

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

    try:
        r = s.get(url, timeout=12)
        if r.status_code != 200:
            return (dname, season, False, f'HTTP {r.status_code}')

        soup = BeautifulSoup(r.text, 'html.parser')
        tbl = soup.find('table')
        if not tbl:
            return (dname, season, False, 'No table')

        # Upsert Division
        r_div_upsert = requests.post(
            f'{SUPABASE_URL}/rest/v1/divisions',
            headers=headers,
            json={
                'division_name': dname,
                'season': season,
                'rfu_competition_id': comp_id,
                'rfu_division_id': div_num,
                'tier_level': tier,
                'region': region,
                'source_url': url,
                'updated_at': 'now()'
            }
        )

        db_div_id = None
        if r_div_upsert.status_code in [200, 201] and r_div_upsert.json():
            db_div_id = r_div_upsert.json()[0]['id']
        else:
            r_id = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?season=eq.{season}&rfu_division_id=eq.{div_num}&select=id', headers=headers)
            if r_id.status_code == 200 and r_id.json():
                db_div_id = r_id.json()[0]['id']

        if not db_div_id:
            return (dname, season, False, 'UUID not found')

        # Parse Standings
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
            return (dname, season, True, f'{len(standings_payload)} teams')
        return (dname, season, False, '0 standings')
    except Exception as e:
        return (dname, season, False, str(e))

def main():
    print("===================================================================", flush=True)
    print("HISTORIC SEASONS PYRAMID SYNC (2024-2025, 2023-2024, 2022-2023, 2021-2022)", flush=True)
    print("===================================================================", flush=True)

    team_lookup = fetch_teams_lookup()
    seasons = ['2024-2025', '2023-2024', '2022-2023', '2021-2022']

    for season in seasons:
        print(f"\n--- Crawling & Syncing Season {season} ---", flush=True)
        divs = discover_season_divisions(season)
        print(f"Discovered {len(divs)} divisions for {season}. Syncing to Supabase...", flush=True)
        
        ok_count = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = {executor.submit(sync_single_div, d, team_lookup): d for d in divs}
            for future in concurrent.futures.as_completed(futures):
                dname, s, ok, msg = future.result()
                if ok:
                    ok_count += 1
                    print(f"  [OK] [{s}] {dname:<40} -> {msg}", flush=True)
                else:
                    print(f"  [SKIP] [{s}] {dname:<40} -> {msg}", flush=True)
        print(f"--> Completed {season}: {ok_count} divisions saved.", flush=True)

    print("\n===================================================================", flush=True)
    print("HISTORIC SEASONS SYNC FINISHED!", flush=True)
    print("===================================================================", flush=True)

if __name__ == '__main__':
    main()
