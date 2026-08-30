import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()

print("Analyzing divisions where fixture dates don't match the division's season:")
mismatched_divisions = []

for d in r_divs:
    did = d['id']
    season = d['season']
    dname = d['division_name']
    
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}&select=id,date", headers=headers).json()
    if not r_fix or not isinstance(r_fix, list):
        continue
        
    dates = [f['date'] for f in r_fix if f.get('date')]
    if not dates:
        continue
        
    # Check years in dates
    years = set()
    for dt in dates:
        for y in ['2024', '2025', '2026', '2027']:
            if y in dt:
                years.add(y)
                
    expected_years = season.split('-')
    # If season is 2025-2026, expected years are 2025 and 2026. If it has 2027, it's 2026-2027 data!
    if season == '2025-2026' and '2027' in years:
        mismatched_divisions.append((d, years, len(r_fix)))
        print(f"  [MISMATCH] '{dname}' ({season}, ID: {did}): Contains years {sorted(years)} ({len(r_fix)} fixtures)")
    elif season == '2024-2025' and ('2026' in years or '2027' in years):
        mismatched_divisions.append((d, years, len(r_fix)))
        print(f"  [MISMATCH] '{dname}' ({season}, ID: {did}): Contains years {sorted(years)} ({len(r_fix)} fixtures)")

print(f"\nTotal mismatched / duplicate divisions across seasons: {len(mismatched_divisions)}")
