import requests
from bs4 import BeautifulSoup
import re
from datetime import datetime

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

def sync_live_rfu_fixtures(comp_id=1699, div_id=75799, season='2026-2027', division_name='Counties 2 Tribute Ale Devon'):
    print(f"Scraping exact live RFU fixture times for {division_name} ({season})...")
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })

    # Fetch division ID from Supabase
    r_div = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?season=eq.{season}&rfu_division_id=eq.{div_id}&select=id', headers=headers)
    if not r_div.json():
        # Search by name
        r_div = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?season=eq.{season}&division_name=ilike.*devon*&select=id', headers=headers)
    
    db_div_id = r_div.json()[0]['id']
    print(f"Division UUID in DB: {db_div_id}")

    # Fetch team lookup
    r_teams = requests.get(f'{SUPABASE_URL}/rest/v1/teams?select=rfu_team_id,team_name', headers=headers)
    teams_db = r_teams.json() if r_teams.status_code == 200 else []
    team_lookup = {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_db}

    # Delete existing fixtures for this division in DB so we populate fresh from RFU
    requests.delete(f'{SUPABASE_URL}/rest/v1/fixtures?division_id=eq.{db_div_id}', headers=headers)

    url = f'https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season}&division={div_id}'
    r = s.get(url)
    soup = BeautifulSoup(r.text, 'html.parser')

    wrappers = soup.find_all(class_='resultWrapper')
    fixtures_payload = []

    for round_idx, w in enumerate(wrappers, start=1):
        date_t = w.find(class_='coh-style-card-left-date')
        date_str = date_t.get_text(strip=True) if date_t else ''

        for card in w.find_all(class_='coh-style-card-scores'):
            h = card.find(class_='coh-style-hometeam')
            a = card.find(class_='coh-style-away-team')
            if not h or not a: continue

            home_team = h.get_text(strip=True)
            away_team = a.get_text(strip=True)

            # Check if RFU has explicit KO time or scores
            card_text = card.get_text()
            time_match = re.search(r'\b([012]?\d:[0-5]\d)\b', card_text)
            
            # Scores (for completed seasons)
            home_score = None
            away_score = None
            status = 'Scheduled'
            
            score_div = card.find(class_='fnr-scores')
            if score_div:
                score_tags = score_div.find_all('a')
                if len(score_tags) >= 2:
                    try:
                        home_score = int(score_tags[0].get_text(strip=True))
                        away_score = int(score_tags[1].get_text(strip=True))
                        status = 'Completed'
                    except ValueError:
                        pass

            # If KO time is explicitly confirmed on RFU (e.g. 14:30, 16:00, 14:00), use it;
            # otherwise if not confirmed yet, default to official RFU Saturday league kickoff (15:00)
            ko_time = time_match.group(1) if time_match else "15:00"

            venue_tag = card.find(class_='coh-style-verticle-left')
            venue = venue_tag.get_text(strip=True) if venue_tag else ""

            # Skip undetermined playoff/relegation placeholder slots (e.g. "TBC vs TBC") -
            # the RFU page can list the same placeholder more than once per round, which
            # collides with the DB's (division_id, home_team, away_team, round_num) unique
            # constraint and fails the whole batch insert.
            if home_team.upper() == 'TBC' and away_team.upper() == 'TBC':
                continue

            hid = team_lookup.get(home_team.lower().strip())
            aid = team_lookup.get(away_team.lower().strip())

            fixtures_payload.append({
                'division_id': db_div_id,
                'home_team': home_team,
                'away_team': away_team,
                'home_team_id': hid,
                'away_team_id': aid,
                'home_score': home_score,
                'away_score': away_score,
                'date': date_str,
                'time': ko_time,
                'status': status,
                'venue': venue,
                'round_num': f"Round {round_idx}",
                'is_custom': False,
                'updated_at': 'now()'
            })

    if fixtures_payload:
        resp = requests.post(f'{SUPABASE_URL}/rest/v1/fixtures', headers=headers, json=fixtures_payload)
        if resp.status_code not in (200, 201):
            print(f"FAILED to sync fixtures for {division_name} ({season}): {resp.status_code} {resp.text}")
            return
        print(f"Successfully scraped and synced {len(fixtures_payload)} official RFU fixtures for {division_name} ({season})")
        print(f"Sample scraped times:")
        for sample in fixtures_payload[:5]:
            print(f"  • {sample['date']} | {sample['home_team']} vs {sample['away_team']} -> KO: {sample['time']} ({sample['status']})")

if __name__ == '__main__':
    sync_live_rfu_fixtures()
