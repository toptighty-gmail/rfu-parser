import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Get all divisions map
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
div_map = {d['id']: d for d in r_divs}

print("=== CHECK 1: Plymstock Oaks vs Tavistock (or Tavistock Seconds) ===")
r1 = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*tavistock*,away_team.ilike.*tavistock*)&order=date.asc", headers=headers).json()
for f in r1:
    if 'plymstock' in f['home_team'].lower() or 'plymstock' in f['away_team'].lower():
        dinfo = div_map.get(f.get('division_id'), {})
        dname = dinfo.get('division_name', 'Unknown')
        season = dinfo.get('season', 'Unknown')
        print(f"ID: {f['id']} | Div: {dname} ({season}, {f.get('division_id')}) | Date: {f.get('date')} | {f.get('home_team')} v {f.get('away_team')} | Rnd: {f.get('round_num')}")

print("\n=== CHECK 2: Plymstock Oaks vs South Molton on Saturday, 3 October 2026 ===")
r2 = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*south molton*,away_team.ilike.*south molton*)&order=date.asc", headers=headers).json()
for f in r2:
    if 'plymstock' in f['home_team'].lower() or 'plymstock' in f['away_team'].lower():
        dinfo = div_map.get(f.get('division_id'), {})
        dname = dinfo.get('division_name', 'Unknown')
        season = dinfo.get('season', 'Unknown')
        print(f"ID: {f['id']} | Div: {dname} ({season}, {f.get('division_id')}) | Date: {f.get('date')} | {f.get('home_team')} v {f.get('away_team')} | Rnd: {f.get('round_num')}")

print("\n=== CHECK 3: custom_fixtures table ===")
r3 = requests.get(url + "/rest/v1/custom_fixtures", headers=headers).json()
for f in r3:
    if 'plymstock' in str(f).lower():
        print(f"Custom ID: {f['id']} | Context: {f.get('context_team')} | Date: {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")
