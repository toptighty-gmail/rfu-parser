import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# 1. Fetch all divisions map
r_divs = requests.get(url + '/rest/v1/divisions?select=id,division_name,season', headers=headers).json()
div_map = {d['id']: d for d in r_divs}

# 2. Fetch all standings to know which teams REALLY belong to which division!
r_standings = requests.get(url + '/rest/v1/standings?select=division_id,team_name', headers=headers).json()
team_to_real_division = {}
for s in r_standings:
    d_id = s.get('division_id')
    t_name = s.get('team_name', '').strip().lower()
    if d_id and t_name:
        if d_id not in team_to_real_division:
            team_to_real_division[d_id] = set()
        team_to_real_division[d_id].add(t_name)

# 3. Fetch all fixtures
r_fix = requests.get(url + '/rest/v1/fixtures?select=id,division_id,date,time,home_team,away_team,round_num,status,home_score,away_score', headers=headers).json()
print(f"Total fixtures in database: {len(r_fix)}")

# Group by (home_team, away_team, date)
match_keys = {}
for f in r_fix:
    h = f.get('home_team', '').strip().lower()
    a = f.get('away_team', '').strip().lower()
    d = f.get('date', '').strip()
    k = (h, a, d)
    if k not in match_keys:
        match_keys[k] = []
    match_keys[k].append(f)

cross_div_dups = {k: v for k, v in match_keys.items() if len(v) > 1}
print(f"Cross-division duplicate match groups: {len(cross_div_dups)}")

for (h, a, d), fixtures in list(cross_div_dups.items())[:20]:
    print(f"\nMatch: {h.title()} v {a.title()} on '{d}' ({len(fixtures)} copies across divisions):")
    for f in fixtures:
        div_info = div_map.get(f.get('division_id'), {})
        dname = div_info.get('division_name', 'Unknown')
        season = div_info.get('season', 'Unknown')
        did = f.get('division_id', 'None')[:8]
        # Check if home/away actually belong to this division's standings table
        real_teams = team_to_real_division.get(f.get('division_id'), set())
        is_legit = (h in real_teams) or (a in real_teams)
        print(f"  - ID: {f['id'][:8]} | Div: {dname} ({season}, {did}) | Legit Division: {is_legit} | Rnd: {f.get('round_num')}")
