import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Get all divisions
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
print("DIVISIONS:")
for d in r_divs:
    print(f"  {d['id']} | {d['season']} | {d['division_name']}")

# Check duplicates per division
for d in r_divs:
    did = d['id']
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=date.asc", headers=headers).json()
    
    seen = {}
    dups = []
    for f in r_fix:
        # Key: (home_team, away_team) OR (round_num, home_team, away_team)
        k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
        if k in seen:
            dups.append((seen[k], f))
        else:
            seen[k] = f
            
    if dups:
        print(f"\nDivision '{d['division_name']}' ({d['season']}) has {len(dups)} DUPLICATE FIXTURES (Total: {len(r_fix)}):")
        for orig, dup in dups:
            print(f"  - Orig: id={orig['id'][:8]} rnd='{orig.get('round_num')}' dt='{orig.get('date')}' {orig['home_team']} v {orig['away_team']}")
            print(f"    Dup:  id={dup['id'][:8]} rnd='{dup.get('round_num')}' dt='{dup.get('date')}' {dup['home_team']} v {dup['away_team']}")
