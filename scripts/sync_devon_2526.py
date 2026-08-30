import requests
from bs4 import BeautifulSoup
import re

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

def sync_devon_2526():
    print("Syncing live 2025-2026 Counties 2 Tribute Devon from England Rugby...")
    
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    s.get('https://www.englandrugby.com/fixtures-and-results')

    source_url = 'https://www.englandrugby.com/fixtures-and-results/search-results?competition=1699&season=2025-2026&division=66462'
    r = s.get(source_url)
    soup = BeautifulSoup(r.text, 'html.parser')

    # 1. Fetch team ID lookup from Supabase teams table
    r_teams = requests.get(f'{SUPABASE_URL}/rest/v1/teams?select=rfu_team_id,team_name', headers=headers)
    teams_db = r_teams.json() if r_teams.status_code == 200 else []
    team_name_to_id = {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_db}

    # 2. Upsert Division record in Supabase
    div_payload = {
        'division_name': 'Counties 2 Tribute Devon',
        'season': '2025-2026',
        'rfu_competition_id': 1699,
        'rfu_division_id': 66462,
        'tier_level': 8,
        'region': 'South West',
        'source_url': source_url,
        'updated_at': 'now()'
    }
    
    r_upsert_div = requests.post(
        f'{SUPABASE_URL}/rest/v1/divisions',
        headers=headers,
        json=div_payload
    )
    
    # Get the division ID
    r_div_id = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?division_name=ilike.*Counties 2 Tribute Devon*&season=eq.2025-2026&select=id', headers=headers)
    div_id = r_div_id.json()[0]['id']
    print(f"Division ID for 2025-2026: {div_id}")

    # 3. Parse Standings Table
    tbl = soup.find('table')
    standings_payload = []
    if tbl:
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

                # Match team ID
                clean = tname.lower().strip()
                tid = team_name_to_id.get(clean)

                standings_payload.append({
                    'division_id': div_id,
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
        print(f"  [OK] Successfully upserted {len(standings_payload)} standings for Counties 2 Tribute Devon (2025-2026)!")
        for s in standings_payload:
            print(f"    {s['position']:2d}. {s['team_name']:<28} P:{s['played']:2d} W:{s['won']:2d} D:{s['drawn']:2d} L:{s['lost']:2d} Pts:{s['points']:3d}")

if __name__ == '__main__':
    sync_devon_2526()
