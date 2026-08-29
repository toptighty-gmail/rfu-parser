import requests, json, time, re

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers_supabase = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

headers_rfu = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
}

# 1. Fetch all distinct team names from Supabase standings
r_teams = requests.get(f'{url}/rest/v1/standings?select=team_name', headers=headers_supabase)
all_teams = sorted(list(set(r['team_name'] for r in r_teams.json())))
print(f'Total pyramid teams to query on RFU API: {len(all_teams)}')

# 2. Fetch existing user uploads so we do not overwrite any user custom uploads from storage bucket
r_existing = requests.get(f'{url}/rest/v1/team_logos?select=*', headers=headers_supabase)
user_uploads = set()
for l in r_existing.json():
    logo_url = l.get('logo_url', '')
    if 'rfu-parcer-team-logos' in logo_url and (logo_url.endswith('.jpg') or logo_url.endswith('.png')):
        user_uploads.add(l['team_name'].lower().strip())

print(f'User custom uploaded logos preserved: {len(user_uploads)}')

resolved_count = 0
for idx, team_name in enumerate(all_teams):
    clean_team = team_name.lower().strip()
    if clean_team in user_uploads:
        print(f'[{idx+1}/{len(all_teams)}] Preserving user upload for {team_name}')
        continue

    # Clean search term (remove II, RFC, etc for better matching)
    search_term = re.sub(r'\b(II|III|RFC|Club|XV)\b', '', team_name, flags=re.IGNORECASE).strip()
    if not search_term:
        search_term = team_name

    search_url = f'https://www.englandrugby.com/api/fixtures-and-result/search?name={requests.utils.quote(search_term)}'
    try:
        r_rfu = requests.get(search_url, headers=headers_rfu, timeout=6)
        if r_rfu.status_code == 200:
            data = r_rfu.json().get('data', [])
            if data:
                # Find best matching club
                club_id = None
                for candidate in data:
                    c_name = candidate.get('name', '').lower()
                    if search_term.lower() in c_name or c_name in search_term.lower():
                        club_id = candidate.get('_id')
                        break
                if not club_id and data:
                    club_id = data[0].get('_id')

                if club_id:
                    rfu_img_url = f'https://images.englandrugby.com/club_images/{club_id}.png'
                    # Verify image exists on RFU CDN
                    r_head = requests.head(rfu_img_url, headers=headers_rfu, timeout=4)
                    if r_head.status_code == 200:
                        # Upsert official RFU logo URL into Supabase team_logos table
                        upsert_payload = {
                            'team_name': team_name,
                            'logo_url': rfu_img_url,
                            'updated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
                        }
                        requests.post(f'{url}/rest/v1/team_logos?on_conflict=team_name', headers=headers_supabase, json=upsert_payload)
                        print(f'[{idx+1}/{len(all_teams)}] RESOLVED: {team_name} -> {rfu_img_url}')
                        resolved_count += 1
                        time.sleep(0.05)
                        continue
    except Exception as e:
        print(f'[{idx+1}/{len(all_teams)}] Error querying {team_name}: {e}')

print(f'\nFinished! Successfully resolved and updated {resolved_count} official RFU club logo URLs in Supabase!')
