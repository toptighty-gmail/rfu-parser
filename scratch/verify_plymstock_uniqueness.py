import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Get all divisions map
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
div_map = {d['id']: d for d in r_divs}

r_fix = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*)&order=date.asc", headers=headers).json()
print(f"Total Plymstock fixtures across database: {len(r_fix)}")

# Check for duplicate dates / pairings
by_key = {}
for f in r_fix:
    k = (f['home_team'].strip().lower(), f['away_team'].strip().lower(), f['date'].strip())
    if k not in by_key:
        by_key[k] = []
    by_key[k].append(f)

dups_found = {k: v for k, v in by_key.items() if len(v) > 1}
print(f"Duplicate (Home, Away, Date) groups for Plymstock: {len(dups_found)}")

if dups_found:
    for k, matches in dups_found.items():
        print(f"\nDUPLICATE: {k[0]} v {k[1]} on '{k[2]}':")
        for m in matches:
            dinfo = div_map.get(m.get('division_id'), {})
            print(f"  - ID: {m['id'][:8]} | Div: {dinfo.get('division_name')} ({dinfo.get('season')})")
else:
    print("ALL Plymstock 1st & 2nd team fixtures are 100% unique and duplicate-free across the entire database!")
