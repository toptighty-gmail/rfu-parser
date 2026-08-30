import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Let's inspect the active 2026-2027 divisions
r_divs = requests.get(url + "/rest/v1/divisions?season=eq.2026-2027", headers=headers).json()
for d in r_divs:
    did = d['id']
    dname = d['division_name']
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=date.asc", headers=headers).json()
    print(f"\nDivision: {dname} (id={did}) -> {len(r_fix)} fixtures:")
    
    rounds = {}
    for f in r_fix:
        rnd = f.get('round_num', 'Unknown')
        rounds[rnd] = rounds.get(rnd, 0) + 1
    
    for r, count in sorted(rounds.items(), key=lambda x: int(x[0].replace('Round ', '')) if 'Round ' in x[0] else 999):
        print(f"  {r:10} -> {count} matches")
