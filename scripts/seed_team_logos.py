import requests, json, re

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

# 1. Fetch existing team_logos
r_existing = requests.get(f'{url}/rest/v1/team_logos?select=*', headers=headers)
existing_logos = {l['team_name'].lower().strip(): l['logo_url'] for l in r_existing.json()}
print(f'Existing custom team_logos in Supabase: {len(existing_logos)}')

# 2. Fetch all teams from standings
r_teams = requests.get(f'{url}/rest/v1/standings?select=team_name', headers=headers)
all_teams = sorted(list(set(r['team_name'] for r in r_teams.json())))
print(f'Total pyramid teams to verify: {len(all_teams)}')

# Color palettes for club styling
colors = [
    ('#005A36', '#D4AF37'), # Green / Gold
    ('#002B7F', '#FFFFFF'), # Navy / White
    ('#C8102E', '#FFFFFF'), # Red / White
    ('#1B4D3E', '#FFD700'), # Forest / Gold
    ('#003399', '#FF9900'), # Blue / Amber
    ('#000000', '#DAA520'), # Black / Gold
    ('#800000', '#FFFFFF'), # Maroon / White
    ('#001F3F', '#C8102E'), # Navy / Red
    ('#DAA520', '#003399'), # Gold / Blue
    ('#0C2340', '#DAA520'), # Deep Navy / Gold
]

def generate_svg(team_name, p_color, s_color):
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', team_name).strip()
    words = [w for w in clean.split() if w.upper() not in ['RFC', 'CLUB', 'RUGBY', 'THE']]
    initials = ''.join([w[0].upper() for w in words[:3]]) if words else 'RFC'
    display_name = (words[0].upper() if words else 'CLUB')[:8]
    
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <defs>
    <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="{p_color}" />
      <stop offset="100%" stop-color="{p_color}" stop-opacity="0.85" />
    </linearGradient>
  </defs>
  <path d="M24 2C35 2 44 8 44 18C44 32 24 46 24 46C24 46 4 32 4 18C4 8 13 2 24 2Z" fill="url(#g)" stroke="{s_color}" stroke-width="2"/>
  <circle cx="24" cy="18" r="9" fill="{s_color}" fill-opacity="0.15" stroke="{s_color}" stroke-width="1"/>
  <text x="24" y="22" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="10" fill="{s_color}">{initials}</text>
  <text x="24" y="38" text-anchor="middle" font-family="Arial, sans-serif" font-weight="900" font-size="6.5" fill="#FFFFFF" letter-spacing="0.5">{display_name}</text>
</svg>'''
    return svg

new_seeded = 0
for idx, team in enumerate(all_teams):
    clean_key = team.lower().strip()
    if clean_key in existing_logos:
        continue # Preserve custom user-uploaded logo
    
    pal = colors[idx % len(colors)]
    svg_content = generate_svg(team, pal[0], pal[1])
    safe_name = re.sub(r'[^a-z0-9]', '_', clean_key)
    file_name = f'{safe_name}.svg'
    
    # 1. Upload to Supabase Storage
    storage_headers = {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'Content-Type': 'image/svg+xml',
        'x-upsert': 'true'
    }
    upload_url = f'{url}/storage/v1/object/rfu-parcer-team-logos/{file_name}'
    r_up = requests.post(upload_url, headers=storage_headers, data=svg_content.encode('utf-8'))
    
    public_url = f'{url}/storage/v1/object/public/rfu-parcer-team-logos/{file_name}'
    
    # 2. Upsert to team_logos table
    upsert_payload = {
        'team_name': team,
        'logo_url': public_url
    }
    r_db = requests.post(f'{url}/rest/v1/team_logos?on_conflict=team_name', headers=headers, json=upsert_payload)
    new_seeded += 1

print(f'Successfully uploaded and seeded {new_seeded} club logos to Supabase storage bucket & team_logos table!')
