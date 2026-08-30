import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}', 'Content-Type': 'application/json'}

# 1. Fetch all divisions
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season,source_url,rfu_competition_id,rfu_division_id', headers=headers).json()
print(f"Total divisions in database: {len(r_divs)}")

# Group by canonical name & season
canonical_divs = {}
for d in r_divs:
    clean_name = d['division_name'].strip().lower().replace('  ', ' ')
    # Normalize minor name variations (e.g., 'tribute ale' vs 'tribute')
    clean_name = clean_name.replace('tribute ale', 'tribute').replace('  ', ' ')
    season = d['season'].strip()
    key = (clean_name, season)
    
    if key not in canonical_divs:
        canonical_divs[key] = []
    canonical_divs[key].append(d)

print(f"Distinct division concepts: {len(canonical_divs)}")

dup_div_groups = {k: v for k, v in canonical_divs.items() if len(v) > 1}
print(f"Division concepts with duplicate records: {len(dup_div_groups)}")

for (name, season), records in list(dup_div_groups.items())[:15]:
    print(f"\nDuplicate Division Concept: '{name}' ({season}) -> {len(records)} records:")
    for r in records:
        print(f"  - ID: {r['id']} | Name: '{r['division_name']}' | Comp: {r.get('rfu_competition_id')} | Div: {r.get('rfu_division_id')} | URL: {r.get('source_url', '')[:40]}")
