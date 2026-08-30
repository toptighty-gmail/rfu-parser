import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

print("===================================================================", flush=True)
print("COMPREHENSIVE GLOBAL AUDIT ACROSS ENTIRE SUPABASE DATABASE", flush=True)
print("===================================================================", flush=True)

# 1. Check all divisions
r_divs = requests.get(url + '/rest/v1/divisions?select=*', headers=headers).json()
div_map = {d['id']: d for d in r_divs}
print(f"1. Total division records: {len(r_divs)}")

# Check for duplicate division names within the same season
div_names = {}
duplicate_divisions = []
for d in r_divs:
    key = (d['division_name'].strip().lower(), d['season'].strip())
    if key in div_names:
        duplicate_divisions.append((div_names[key], d))
    else:
        div_names[key] = d

print(f"   Duplicate (Division Name, Season) containers found: {len(duplicate_divisions)}")
for orig, dup in duplicate_divisions:
    print(f"   - Orig ID: {orig['id'][:8]} vs Dup ID: {dup['id'][:8]} -> '{dup['division_name']}' ({dup['season']})")

# 2. Check all fixtures across the database
# Fetch in batches if necessary
all_fixtures = []
limit = 1000
offset = 0
while True:
    r = requests.get(f"{url}/rest/v1/fixtures?select=*&limit={limit}&offset={offset}", headers=headers).json()
    if not r or not isinstance(r, list):
        break
    all_fixtures.extend(r)
    if len(r) < limit:
        break
    offset += limit

print(f"\n2. Total fixture records across database: {len(all_fixtures)}")

# Check A: Exact cross-division duplicates: (home_team, away_team, date)
match_keys = {}
cross_div_dups = []
for f in all_fixtures:
    h = f.get('home_team', '').strip().lower()
    a = f.get('away_team', '').strip().lower()
    d = f.get('date', '').strip()
    k = (h, a, d)
    if k in match_keys:
        cross_div_dups.append((match_keys[k], f))
    else:
        match_keys[k] = f

print(f"   Cross-division duplicate matches (same home, away, date in multiple divisions): {len(cross_div_dups)}")
for orig, dup in cross_div_dups[:10]:
    o_div = div_map.get(orig.get('division_id'), {})
    d_div = div_map.get(dup.get('division_id'), {})
    print(f"   - Match: {orig['home_team']} v {orig['away_team']} on {orig['date']}")
    print(f"     Appears in: '{o_div.get('division_name')}' ({o_div.get('season')}) AND '{d_div.get('division_name')}' ({d_div.get('season')})")

# Check B: Same fixture pair (home_team, away_team) repeated in the same division
intra_div_dups = []
pairings_per_div = {}
for f in all_fixtures:
    did = f.get('division_id')
    h = f.get('home_team', '').strip().lower()
    a = f.get('away_team', '').strip().lower()
    k = (did, h, a)
    if k in pairings_per_div:
        intra_div_dups.append((pairings_per_div[k], f))
    else:
        pairings_per_div[k] = f

print(f"   Intra-division duplicate pairings (same home v away multiple times in one division): {len(intra_div_dups)}")
for orig, dup in intra_div_dups[:10]:
    o_div = div_map.get(orig.get('division_id'), {})
    print(f"   - Division: '{o_div.get('division_name')}' ({o_div.get('season')}): {orig['home_team']} v {orig['away_team']} (ID: {orig['id'][:8]} vs {dup['id'][:8]})")

# Check C: Season date mismatches (e.g. 2026/2027 dates in 2024-2025 or 2025-2026 division)
season_mismatches = []
for f in all_fixtures:
    did = f.get('division_id')
    div_info = div_map.get(did)
    if not div_info:
        continue
    season = div_info.get('season', '')
    date_str = f.get('date', '')
    
    if season == '2024-2025' and ('2026' in date_str or '2027' in date_str):
        season_mismatches.append((div_info, f))
    elif season == '2025-2026' and '2027' in date_str:
        season_mismatches.append((div_info, f))
    elif season == '2026-2027' and ('2024' in date_str or '2025' in date_str):
        season_mismatches.append((div_info, f))

print(f"   Season/Date Mismatches across all divisions: {len(season_mismatches)}")
for dinfo, f in season_mismatches[:10]:
    print(f"   - Div: '{dinfo['division_name']}' ({dinfo['season']}) contains fixture date: '{f.get('date')}' ({f.get('home_team')} v {f.get('away_team')})")

# 3. Check custom_fixtures table
r_cust = requests.get(url + '/rest/v1/custom_fixtures', headers=headers).json()
print(f"\n3. Total custom fixtures: {len(r_cust) if isinstance(r_cust, list) else 0}")
if isinstance(r_cust, list):
    seen_c = set()
    c_dups = 0
    for f in r_cust:
        k = (f.get('home_team', '').strip().lower(), f.get('away_team', '').strip().lower(), f.get('date', '').strip(), f.get('context_team', '').strip().lower())
        if k in seen_c:
            c_dups += 1
        seen_c.add(k)
    print(f"   Custom fixture duplicates: {c_dups}")

print("\n===================================================================", flush=True)
print("GLOBAL AUDIT SUMMARY COMPLETE", flush=True)
print("===================================================================", flush=True)
