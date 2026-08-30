import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=round_num.asc,date.asc", headers=headers).json()

print(f"Counties 2 Tribute Ale Devon Fixtures (Total: {len(r_fix)}):")
for f in r_fix:
    rnd = f.get('round_num', '')
    if any(r in rnd for r in ['Round 16', 'Round 17', 'Round 18', 'Round 19', 'Round 20', 'Round 21']):
        print(f"ID: {f['id']} | {rnd:10} | {f['date']:24} | {f['home_team']:30} v {f['away_team']:30} | Status: {f['status']}")
