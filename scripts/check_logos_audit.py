import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# 1. Fetch all standings teams in Counties 2 Tribute Devon
r_div = requests.get(f'{url}/rest/v1/divisions?division_name=ilike.*Counties 2 Tribute Devon*&select=id,division_name', headers=headers)
divs = r_div.json()
print('Divisions matched:', divs)

if divs:
    div_id = divs[0]['id']
    r_st = requests.get(f'{url}/rest/v1/standings?division_id=eq.{div_id}&select=*', headers=headers)
    print('Standings status:', r_st.status_code)
    try:
        standings = r_st.json()
        print(f'Total standings rows for division: {len(standings)}')
        for s in standings:
            print(f"  #{s.get('position')} {s.get('team_name')} -> logo_url: {s.get('logo_url')}")
    except Exception as e:
        print('Error parsing standings:', e, r_st.text)

devon_teams = ['Crediton', 'Exeter Saracens', 'Exmouth', 'Old Plymothian', 'South Molton', 'Bideford', 'Tavistock', 'Honiton', 'Withycombe', 'Brixham', 'Topsham', 'Plymstock Oaks']

print('\n=== DEVON TEAMS IN team_logos TABLE ===')
for t in devon_teams:
    r = requests.get(f'{url}/rest/v1/team_logos?team_name=ilike.*{t}*&select=*', headers=headers)
    rows = r.json()
    print(f'Match for {t}:')
    if rows:
        for row in rows:
            print(f"  {row.get('team_name')} -> {row.get('logo_url')}")
    else:
        print('  NO ROW IN team_logos!')

# 3. Check what files are in Supabase storage bucket
r_files = requests.post(f'{url}/storage/v1/object/list/rfu-parcer-team-logos', headers=headers, json={'prefix': '', 'limit': 100})
print(f'\nStorage bucket files count: {len(r_files.json()) if isinstance(r_files.json(), list) else r_files.text}')
if isinstance(r_files.json(), list):
    for f in r_files.json()[:20]:
        print(f"  File: {f.get('name')}")
