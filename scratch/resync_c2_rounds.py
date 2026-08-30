import requests
from datetime import datetime

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}', 'Content-Type': 'application/json'}

did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}", headers=headers).json()

# Parse date strings to sort chronologically
def parse_date(d_str):
    clean = d_str.replace('Saturday, ', '').replace('Friday, ', '').replace('Sunday, ', '').strip()
    for fmt in ['%d %b %Y', '%d %B %Y', '%d/%m/%Y']:
        try:
            return datetime.strptime(clean, fmt)
        except:
            pass
    return datetime(2099, 1, 1)

unique_dates = list(set(f['date'] for f in r_fix))
unique_dates.sort(key=parse_date)

date_to_round = {}
for idx, d_str in enumerate(unique_dates, start=1):
    date_to_round[d_str] = f"Round {idx}"
    print(f"Date {idx:2}: {d_str:25} -> Round {idx}")

# Update each fixture
updated = 0
for f in r_fix:
    d_str = f['date']
    expected_round = date_to_round.get(d_str)
    if expected_round and f.get('round_num') != expected_round:
        fid = f['id']
        requests.patch(f"{url}/rest/v1/fixtures?id=eq.{fid}", headers=headers, json={'round_num': expected_round})
        updated += 1

print(f"\nSuccessfully synchronized {updated} fixtures to correct Round 1..22 numbering!")

# Verify
r_after = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}", headers=headers).json()
rounds_count = {}
for f in r_after:
    r = f.get('round_num')
    rounds_count[r] = rounds_count.get(r, 0) + 1

print("\nFinal verified round distribution in Counties 2 Tribute Ale Devon:")
for idx in range(1, 23):
    r_label = f"Round {idx}"
    print(f"  {r_label:10} -> {rounds_count.get(r_label, 0)} matches")
