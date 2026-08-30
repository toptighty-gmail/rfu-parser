import requests
from datetime import datetime

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}', 'Content-Type': 'application/json'}

print("===================================================================", flush=True)
print("AUDITING & DEDUPLICATING ALL FIXTURES ACROSS ENTIRE SUPABASE DATABASE", flush=True)
print("===================================================================", flush=True)

# 1. Fetch all divisions
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
print(f"Total divisions in database: {len(r_divs)}\n", flush=True)

total_duplicates_deleted = 0

for d in r_divs:
    did = d['id']
    dname = d['division_name']
    season = d['season']
    
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&order=date.asc", headers=headers).json()
    if not r_fix or not isinstance(r_fix, list):
        continue
        
    # Group by (home_team, away_team)
    pairings = {}
    for f in r_fix:
        k = (f['home_team'].strip().lower(), f['away_team'].strip().lower())
        if k not in pairings:
            pairings[k] = []
        pairings[k].append(f)
        
    div_dups = 0
    for k, matches in pairings.items():
        if len(matches) > 1:
            # Sort: prioritize keeping match with score or valid details
            matches.sort(key=lambda m: (
                0 if m.get('home_score') is not None else 1,
                0 if m.get('round_num') and 'Round' in m.get('round_num') else 1,
                m.get('date', '')
            ))
            # Keep first, delete the rest
            for extra in matches[1:]:
                del_id = extra['id']
                requests.delete(f"{url}/rest/v1/fixtures?id=eq.{del_id}", headers=headers)
                div_dups += 1
                total_duplicates_deleted += 1
                
    if div_dups > 0:
        print(f"  [FIXED] '{dname}' ({season}): Deleted {div_dups} duplicate fixtures (Remaining: {len(r_fix) - div_dups})", flush=True)

# 2. Check and clean custom_fixtures table
print("\nAuditing custom_fixtures table...", flush=True)
r_cust = requests.get(url + '/rest/v1/custom_fixtures', headers=headers).json()
if isinstance(r_cust, list):
    seen_cust = {}
    cust_dups = 0
    for f in r_cust:
        k = (
            f.get('context_team', '').strip().lower(),
            f.get('home_team', '').strip().lower(),
            f.get('away_team', '').strip().lower(),
            f.get('date', '').strip()
        )
        if k in seen_cust:
            del_id = f['id']
            requests.delete(f"{url}/rest/v1/custom_fixtures?id=eq.{del_id}", headers=headers)
            cust_dups += 1
            total_duplicates_deleted += 1
        else:
            seen_cust[k] = f
            
    if cust_dups > 0:
        print(f"  [FIXED] Custom Fixtures: Deleted {cust_dups} duplicate custom entries.", flush=True)
    else:
        print("  Custom Fixtures: 0 duplicates found.", flush=True)

print(f"\n===================================================================", flush=True)
print(f"DATABASE AUDIT COMPLETE: Deleted {total_duplicates_deleted} duplicate fixtures across all divisions!", flush=True)
print("===================================================================", flush=True)
