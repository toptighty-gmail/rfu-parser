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

def sync_devon_fixtures():
    print("Syncing 2025-2026 Counties 2 Tribute Devon fixtures & results...")
    
    # 1. Get division ID
    r_div = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?division_name=ilike.*Counties 2 Tribute Devon*&season=eq.2025-2026&select=id', headers=headers)
    div_id = r_div.json()[0]['id']

    # 2. Get teams mapping
    r_teams = requests.get(f'{SUPABASE_URL}/rest/v1/teams?select=rfu_team_id,team_name', headers=headers)
    teams_db = r_teams.json() if r_teams.status_code == 200 else []
    team_name_to_id = {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_db}

    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    s.get('https://www.englandrugby.com/fixtures-and-results')

    source_url = 'https://www.englandrugby.com/fixtures-and-results/search-results?competition=1699&season=2025-2026&division=66462'
    r = s.get(source_url)
    soup = BeautifulSoup(r.text, 'html.parser')

    fixtures_payload = []
    # Parse match cards
    match_cards = soup.find_all('div', class_=re.compile(r'c065|match-row|fixture-item|c026'))
    # Also parse from text patterns
    print(f"Parsing matches from page (HTML length: {len(r.text)})...")
    
    # England Rugby embeds fixture data in drupalSettings / JSON or markup
    # Let's extract all match cards
    match_containers = soup.find_all('a', href=re.compile(r'matchId=\d+'))
    print(f"Found {len(match_containers)} match references")

    for card in match_containers:
        text = card.get_text(separator='|', strip=True)
        parts = [p.strip() for p in text.split('|') if p.strip()]
        # Typically format: Team1 | Score1 | Score2 | Team2
        # Or parse surrounding elements
        parent = card.find_parent('div')
        if parent:
            p_text = parent.get_text(separator='|', strip=True)
            p_parts = [p.strip() for p in p_text.split('|') if p.strip()]
            # Find scores and team names
            scores = [p for p in p_parts if p.isdigit()]
            teams = [p for p in p_parts if not p.isdigit() and len(p) > 2 and 'Counties' not in p and 'View' not in p]
            if len(teams) >= 2:
                home = teams[0]
                away = teams[1]
                h_score = int(scores[0]) if len(scores) >= 1 else None
                a_score = int(scores[1]) if len(scores) >= 2 else None
                
                hid = team_name_to_id.get(home.lower())
                aid = team_name_to_id.get(away.lower())

                fixtures_payload.append({
                    'division_id': div_id,
                    'home_team': home,
                    'away_team': away,
                    'home_team_id': hid,
                    'away_team_id': aid,
                    'home_score': h_score,
                    'away_score': a_score,
                    'date': '2025-2026',
                    'time': '15:00',
                    'status': 'Completed' if h_score is not None else 'Scheduled',
                    'round_num': 'Season 2025-2026',
                    'is_custom': False,
                    'updated_at': 'now()'
                })

    # Deduplicate
    unique_fixtures = {}
    for f in fixtures_payload:
        key = (f['home_team'], f['away_team'])
        unique_fixtures[key] = f

    if unique_fixtures:
        payload_list = list(unique_fixtures.values())
        requests.post(f'{SUPABASE_URL}/rest/v1/fixtures', headers=headers, json=payload_list)
        print(f"  [OK] Saved {len(payload_list)} fixtures/results to Supabase.")

if __name__ == '__main__':
    sync_devon_fixtures()
