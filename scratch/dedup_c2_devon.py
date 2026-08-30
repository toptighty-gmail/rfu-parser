import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Let's clean up Counties 2 Tribute Ale Devon
did = '9214a6a4-afcd-40e5-afb7-4dacea27d3c3'
r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=round_num.asc,date.asc", headers=headers).json()

# Date to correct round mapping:
date_to_round = {
    '2026-09-26': 'Round 1',
    '2026-10-03': 'Round 2',
    '2026-10-10': 'Round 3',
    '2026-10-17': 'Round 4',
    '2026-10-24': 'Round 5',
    '2026-10-31': 'Round 6',
    '2026-11-14': 'Round 7',
    '2026-11-21': 'Round 8',
    '2026-11-28': 'Round 9',
    '2026-12-05': 'Round 10',
    '2026-12-12': 'Round 11',
    '2026-12-19': 'Round 12',
    '2027-01-09': 'Round 13',
    '2027-01-16': 'Round 14',
    '2027-01-30': 'Round 15',
    '2027-02-13': 'Round 16',
    '2027-02-27': 'Round 17',
    '2027-03-06': 'Round 18',
    '2027-03-20': 'Round 19',
    '2027-04-03': 'Round 20',
    '2027-04-10': 'Round 21',
    '2027-04-17': 'Round 22',
}

# Group by (home_team, away_team)
pairings = {}
for f in r_fix:
    k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
    if k not in pairings:
        pairings[k] = []
    pairings[k].append(f)

print(f"Total fixtures before deduplication: {len(r_fix)}")
deleted_count = 0

for k, matches in pairings.items():
    if len(matches) > 1:
        # Keep the one whose date/round best matches the calendar or matches[0]
        # Delete extra duplicates
        to_delete = matches[1:]
        for extra in to_delete:
            del_id = extra['id']
            del_res = requests.delete(f"{url}/rest/v1/fixtures?id=eq.{del_id}", headers=headers)
            if del_res.status_code in [200, 204]:
                deleted_count += 1
                print(f"  Deleted duplicate: {extra['home_team']} v {extra['away_team']} (ID: {del_id[:8]})")

print(f"Deleted {deleted_count} duplicate fixtures from Counties 2 Tribute Ale Devon.")

# Verify final fixtures count
r_fix_after = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=round_num.asc,date.asc", headers=headers).json()
print(f"Total fixtures remaining: {len(r_fix_after)} (Expected 132)")

rounds_after = {}
for f in r_fix_after:
    rnd = f.get('round_num', '')
    rounds_after[rnd] = rounds_after.get(rnd, 0) + 1

for r, count in sorted(rounds_after.items(), key=lambda x: int(x[0].replace('Round ', '')) if 'Round ' in x[0] else 999):
    print(f"  {r:10} -> {count} matches")
