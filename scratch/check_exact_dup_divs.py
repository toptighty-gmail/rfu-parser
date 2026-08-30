import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Check Barnes vs Dorking
r = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*barnes*,away_team.ilike.*barnes*)", headers=headers).json()
print(f"Barnes fixtures count: {len(r)}")
for f in r:
    print(f"  {f['id'][:8]} | Div: {f.get('division_id')} | {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")

# Check all division names in divisions table for duplicates
r_divs = requests.get(url + "/rest/v1/divisions?select=id,division_name,season", headers=headers).json()
div_counts = {}
for d in r_divs:
    k = (d['division_name'].strip(), d['season'].strip())
    if k not in div_counts:
        div_counts[k] = []
    div_counts[k].append(d['id'])

exact_dup_divs = {k: v for k, v in div_counts.items() if len(v) > 1}
print(f"\nExact duplicate division records in divisions table: {len(exact_dup_divs)}")
for (name, season), ids in exact_dup_divs.items():
    print(f"  - '{name}' ({season}) -> IDs: {ids}")
