import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
total_remaining_dups = 0

for d in r_divs:
    did = d['id']
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&select=home_team,away_team", headers=headers).json()
    if not isinstance(r_fix, list): continue
    
    seen = set()
    for f in r_fix:
        k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
        if k in seen:
            total_remaining_dups += 1
            print(f"Residual dup in '{d['division_name']}' ({d['season']}): {k}")
        seen.add(k)

print(f"Verification Complete. Total duplicate pairings remaining across all {len(r_divs)} divisions: {total_remaining_dups}")
