import requests

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'return=minimal'
}

def clean_2026_2027_fixtures():
    print("Finding 2026-2027 divisions...")
    r_divs = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?season=eq.2026-2027&select=id,division_name', headers=headers)
    divs = r_divs.json() if r_divs.status_code == 200 else []
    print(f"Found {len(divs)} divisions in 2026-2027.")

    total_reset = 0
    for d in divs:
        did = d['id']
        dname = d['division_name']
        
        # Patch all fixtures belonging to this 2026-2027 division to remove scores and set status='Scheduled'
        # and ensure default kickoff time '15:00' if time was missing
        r_patch = requests.patch(
            f'{SUPABASE_URL}/rest/v1/fixtures?division_id=eq.{did}',
            headers=headers,
            json={
                'home_score': None,
                'away_score': None,
                'status': 'Scheduled',
                'updated_at': 'now()'
            }
        )
        if r_patch.status_code in [200, 204]:
            print(f"  [RESET] {dname:<45} -> Scores cleared, status set to Scheduled")
            total_reset += 1
        else:
            print(f"  [FAIL] {dname:<45} -> {r_patch.status_code} {r_patch.text}")

    print(f"\nCompleted: Reset fixtures for {total_reset} divisions in season 2026-2027!")

if __name__ == '__main__':
    clean_2026_2027_fixtures()
