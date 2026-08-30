import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}', 'Content-Type': 'application/json'}

def normalize_name(name):
    if not name:
        return name
    clean = name.strip()
    lower = clean.lower()
    if 'old plymothian' in lower:
        if 'ii' in lower or '2nd' in lower or 'seconds' in lower:
            return 'OPMs II'
        return 'OPMs'
    if lower == 'opm':
        return 'OPMs'
    if lower == 'opm ii':
        return 'OPMs II'
    return clean

# 1. Update standings table
print("Updating standings table...", flush=True)
r_standings = requests.get(url + '/rest/v1/standings?or=(team_name.ilike.*plymothian*,team_name.ilike.*opm*)', headers=headers).json()
for s in r_standings:
    old_name = s['team_name']
    new_name = normalize_name(old_name)
    if new_name != old_name:
        sid = s['id']
        requests.patch(f"{url}/rest/v1/standings?id=eq.{sid}", headers=headers, json={'team_name': new_name})
        print(f"  Standings: '{old_name}' -> '{new_name}' (ID: {sid})")

# 2. Update fixtures table
print("\nUpdating fixtures table...", flush=True)
r_fix = requests.get(url + '/rest/v1/fixtures?or=(home_team.ilike.*plymothian*,away_team.ilike.*plymothian*,home_team.ilike.*opm*,away_team.ilike.*opm*)', headers=headers).json()
fix_updated = 0
for f in r_fix:
    h_old = f['home_team']
    a_old = f['away_team']
    h_new = normalize_name(h_old)
    a_new = normalize_name(a_old)
    
    payload = {}
    if h_new != h_old:
        payload['home_team'] = h_new
    if a_new != a_old:
        payload['away_team'] = a_new
        
    if payload:
        fid = f['id']
        requests.patch(f"{url}/rest/v1/fixtures?id=eq.{fid}", headers=headers, json=payload)
        fix_updated += 1

print(f"  Updated {fix_updated} fixtures with OPMs naming.")

# 3. Update custom_fixtures table
print("\nUpdating custom_fixtures table...", flush=True)
r_cust = requests.get(url + '/rest/v1/custom_fixtures', headers=headers).json()
if isinstance(r_cust, list):
    for f in r_cust:
        h_old = f.get('home_team', '')
        a_old = f.get('away_team', '')
        c_old = f.get('context_team', '')
        
        payload = {}
        if normalize_name(h_old) != h_old:
            payload['home_team'] = normalize_name(h_old)
        if normalize_name(a_old) != a_old:
            payload['away_team'] = normalize_name(a_old)
        if normalize_name(c_old) != c_old:
            payload['context_team'] = normalize_name(c_old)
            
        if payload:
            cid = f['id']
            requests.patch(f"{url}/rest/v1/custom_fixtures?id=eq.{cid}", headers=headers, json=payload)
            print(f"  Custom fixture: ID {cid} updated with {payload}")

print("\nDatabase team normalization complete!")
