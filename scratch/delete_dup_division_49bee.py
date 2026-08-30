import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

dup_div_id = '49bee754-2d3d-4de4-bfed-31245755746b'

# 1. Delete all fixtures in this duplicate division
r_del_fix = requests.delete(f"{url}/rest/v1/fixtures?division_id=eq.{dup_div_id}", headers=headers)
print(f"Deleted duplicate fixtures from {dup_div_id}: status={r_del_fix.status_code}")

# 2. Delete all standings in this duplicate division
r_del_stand = requests.delete(f"{url}/rest/v1/standings?division_id=eq.{dup_div_id}", headers=headers)
print(f"Deleted duplicate standings from {dup_div_id}: status={r_del_stand.status_code}")

# 3. Delete the duplicate division record itself
r_del_div = requests.delete(f"{url}/rest/v1/divisions?id=eq.{dup_div_id}", headers=headers)
print(f"Deleted duplicate division record {dup_div_id}: status={r_del_div.status_code}")

# 4. Now let's re-verify the EXACT examples the user gave:
print("\n=== VERIFYING USER EXAMPLE 1: Plymstock Oaks vs Topsham II / Tavistock on Saturday, 3 April 2027 ===")
r_ex1 = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*)&date=ilike.*3 Apr 2027*", headers=headers).json()
for f in r_ex1:
    print(f"  ID: {f['id'][:8]} | Div: {f.get('division_id')} | Date: {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")

print("\n=== VERIFYING USER EXAMPLE 2: Plymstock Oaks vs South Molton on Saturday, 3 October 2026 ===")
r_ex2 = requests.get(url + "/rest/v1/fixtures?or=(home_team.ilike.*plymstock*,away_team.ilike.*plymstock*)&date=ilike.*3 Oct 2026*", headers=headers).json()
for f in r_ex2:
    print(f"  ID: {f['id'][:8]} | Div: {f.get('division_id')} | Date: {f.get('date')} | {f.get('home_team')} v {f.get('away_team')}")
