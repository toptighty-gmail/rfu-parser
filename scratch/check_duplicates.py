import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Let's inspect fixtures for Plymstock Oaks
r = requests.get(url + '/rest/v1/fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*)&order=date.asc', headers=headers)
fixtures = r.json()
print('Total Plymstock fixtures in DB:', len(fixtures))

for f in fixtures:
    fid = f['id'][:8]
    did = f.get('division_id', '')[:8] if f.get('division_id') else 'none'
    rnd = f.get('round_num', '')
    dt = f.get('date', '')
    tm = f.get('time', '')
    h = f.get('home_team', '')
    a = f.get('away_team', '')
    print(f"{fid} | Div: {did} | {rnd:10} | {dt:24} {tm:5} | {h} v {a}")

print('\n=== Custom fixtures for Plymstock ===')
r2 = requests.get(url + '/rest/v1/custom_fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*,context_team.ilike.*plymstock*)', headers=headers)
cust = r2.json()
for f in cust:
    fid = f['id'][:8]
    did = f.get('division_id', '')[:8] if f.get('division_id') else 'none'
    dt = f.get('date', '')
    tm = f.get('time', '')
    h = f.get('home_team', '')
    a = f.get('away_team', '')
    print(f"{fid} | Div: {did} | {dt:24} {tm:5} | {h} v {a}")
