import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r = requests.get(f'{url}/rest/v1/team_logos?select=*', headers=headers)
rows = r.json()

unique_teams = {x['team_name'].lower().strip(): x for x in rows}

png_teams = [x for x in unique_teams.values() if x.get('logo_url') and x['logo_url'].endswith('.png')]
svg_teams = [x for x in unique_teams.values() if x.get('logo_url') and x['logo_url'].endswith('.svg') and x['team_name'].lower() != 'tbc']
null_teams = [x for x in unique_teams.values() if not x.get('logo_url')]

print('==============================================')
print('TOTAL UNIQUE TEAMS (excl TBC):', len([k for k in unique_teams if k != 'tbc']))
print('TEAMS WITH OFFICIAL CRESTS (.png):', len(png_teams))
print('TEAMS WITH FALLBACK CRESTS (.svg):', len(svg_teams))
print('TEAMS WITH NULL/EMPTY LOGO:', len(null_teams))
print('==============================================')

print('\nDetailed Breakdown of the Remaining .svg Teams:')
for idx, item in enumerate(sorted(svg_teams, key=lambda x: x['team_name']), 1):
    tname = item['team_name']
    lurl = item['logo_url']
    print(f'{idx}. {tname} -> {lurl}')
