import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}', 'Content-Type': 'application/json'}

# 1. Clean up Counties 3 Tribute Ale Devon North & East (bd913ae9)
# The real 12 teams in C3 Devon North & East are:
real_c3_north_east = {
    'bideford ii', 'cullompton ii', 'exeter athletic', 'exeter engineers',
    'ilfracombe', 'new cross', 'newton abbot ii', 'north tawton',
    'okehampton ii', 'sidmouth ii', 'tiverton ii', 'torrington'
}

d2 = 'bd913ae9-9f4a-482c-8f78-18da497b913b'

# Remove standings in bd913ae9 that do NOT belong to real C3 North & East
r_standings = requests.get(f"{url}/rest/v1/standings?division_id=eq.{d2}", headers=headers).json()
for s in r_standings:
    tname = s.get('team_name', '').strip().lower()
    if tname not in real_c3_north_east:
        sid = s['id']
        requests.delete(f"{url}/rest/v1/standings?id=eq.{sid}", headers=headers)
        print(f"Removed rogue standing '{s.get('team_name')}' from C3 Devon North & East")

# Remove fixtures in bd913ae9 that belong to Counties 2 Devon (i.e. Plymstock Oaks, etc.)
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{d2}", headers=headers).json()
deleted_c3_fix = 0
for f in r_fix:
    h = f.get('home_team', '').strip().lower()
    a = f.get('away_team', '').strip().lower()
    if h not in real_c3_north_east or a not in real_c3_north_east:
        fid = f['id']
        requests.delete(f"{url}/rest/v1/fixtures?id=eq.{fid}", headers=headers)
        deleted_c3_fix += 1

print(f"Deleted {deleted_c3_fix} cross-division duplicate fixtures from C3 Devon North & East.")

# 2. Consolidate duplicate empty divisions
# (e.g. 'bc85f7f0-636f-4252-b1e4-acfb473a8bb9' - Counties 2 Tribute Devon 2026-2027 which has 0 fixtures)
empty_dups = ['bc85f7f0-636f-4252-b1e4-acfb473a8bb9']
for ed in empty_dups:
    requests.delete(f"{url}/rest/v1/divisions?id=eq.{ed}", headers=headers)
    print(f"Deleted duplicate empty division record ID: {ed}")
