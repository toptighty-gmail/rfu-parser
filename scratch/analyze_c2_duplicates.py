import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=round_num.asc,date.asc", headers=headers).json()

# In a standard 12-team round robin, each fixture (Home vs Away) happens EXACTLY ONCE.
# Let's group by (home_team, away_team)
pairings = {}
for f in r_fix:
    k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
    if k not in pairings:
        pairings[k] = []
    pairings[k].append(f)

print(f"Total distinct pairings in C2 Devon: {len(pairings)}")
duplicates_to_delete = []

for k, matches in pairings.items():
    if len(matches) > 1:
        print(f"\nDuplicate match: {k[0]} v {k[1]} ({len(matches)} entries):")
        # Keep the one with a score or earliest creation / correct round numbering
        # Let's inspect each match
        for idx, m in enumerate(matches):
            print(f"  [{idx}] ID={m['id'][:8]} | Round='{m.get('round_num')}' | Date='{m.get('date')}' | Score='{m.get('home_score')}-{m.get('away_score')}'")
        
        # We keep matches[0] and delete the rest
        for extra in matches[1:]:
            duplicates_to_delete.append(extra['id'])

print(f"\nTotal duplicate fixtures identified for cleanup: {len(duplicates_to_delete)}")
