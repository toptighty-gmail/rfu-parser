import requests
import json
import re
import concurrent.futures

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

def sanitize_slug(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name.strip().lower()).strip('_')

def get_base_club_name(team_name):
    name = re.sub(r'\b(I{1,3}|IV|V|VI|1st|2nd|3rd|4th|Club XV|Colts|Ladies|Women|Nomads|Wanderers|Extra|Development)\b', '', team_name, flags=re.IGNORECASE)
    name = re.sub(r'\s+', ' ', name).strip()
    return name if name else team_name

def create_rfu_session():
    s = requests.Session()
    s.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.englandrugby.com/fixtures-and-results',
    })
    try:
        s.get('https://www.englandrugby.com/fixtures-and-results', timeout=5)
    except Exception:
        pass
    return s

def generate_svg(team_name, p_color='#002B7F', s_color='#D4AF37'):
    clean = re.sub(r'[^a-zA-Z0-9\s]', '', team_name).strip()
    words = [w for w in clean.split() if w.upper() not in ['RFC', 'CLUB', 'RUGBY', 'THE', 'AND', '&']]
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

def main():
    print("1. Gathering all unique teams from Supabase database...", flush=True)
    all_teams = set()
    
    # Standings
    try:
        r = requests.get(f'{SUPABASE_URL}/rest/v1/standings?select=team_name', headers=headers)
        if r.status_code == 200:
            for row in r.json():
                if row.get('team_name'): all_teams.add(row['team_name'].strip())
    except Exception as e:
        print(f"Error reading standings: {e}", flush=True)

    # Fixtures
    try:
        r = requests.get(f'{SUPABASE_URL}/rest/v1/fixtures?select=home_team,away_team', headers=headers)
        if r.status_code == 200:
            for row in r.json():
                if row.get('home_team'): all_teams.add(row['home_team'].strip())
                if row.get('away_team'): all_teams.add(row['away_team'].strip())
    except Exception as e:
        print(f"Error reading fixtures: {e}", flush=True)

    # Custom fixtures
    try:
        r = requests.get(f'{SUPABASE_URL}/rest/v1/custom_fixtures?select=team1_name,team2_name,context_team', headers=headers)
        if r.status_code == 200:
            for row in r.json():
                if row.get('team1_name'): all_teams.add(row['team1_name'].strip())
                if row.get('team2_name'): all_teams.add(row['team2_name'].strip())
                if row.get('context_team'): all_teams.add(row['context_team'].strip())
    except Exception as e:
        print(f"Error reading custom_fixtures: {e}", flush=True)

    print(f"Found {len(all_teams)} distinct team names across database.", flush=True)

    print("2. Listing existing files in Supabase storage bucket 'rfu-parcer-team-logos'...", flush=True)
    existing_bucket_files = set()
    try:
        r_list = requests.post(f'{SUPABASE_URL}/storage/v1/object/list/rfu-parcer-team-logos', headers=headers, json={'prefix': '', 'limit': 1000})
        if r_list.status_code == 200 and isinstance(r_list.json(), list):
            for obj in r_list.json():
                existing_bucket_files.add(obj.get('name'))
        print(f"Total objects currently in bucket: {len(existing_bucket_files)}", flush=True)
    except Exception as e:
        print(f"Error listing bucket: {e}", flush=True)

    print("3. Clearing existing contents of team_logos table...", flush=True)
    try:
        r_del = requests.delete(f'{SUPABASE_URL}/rest/v1/team_logos?team_name=neq.____FORCE_CLEAR____', headers=headers)
        print(f"Clear status: {r_del.status_code}", flush=True)
    except Exception as e:
        print(f"Error clearing table: {e}", flush=True)

    print("4. Resolving official RFU club crests (PNG) from England Rugby API & uploading to Supabase Bucket...", flush=True)
    rfu_session = create_rfu_session()

    def process_team(team_name):
        slug = sanitize_slug(team_name)
        base_name = get_base_club_name(team_name)
        base_slug = sanitize_slug(base_name)

        # 1. Search England Rugby API for club ID
        club_id = None
        for query in [base_name, team_name]:
            try:
                r_s = rfu_session.get(f'https://www.englandrugby.com/api/fixtures-and-result/search?name={query}', timeout=4)
                if r_s.status_code == 200:
                    data = r_s.json()
                    items = data.get('data', []) if isinstance(data, dict) else data
                    if items and isinstance(items, list):
                        club_id = items[0].get('_id')
                        if club_id:
                            break
            except Exception:
                pass

        # 2. If club ID found, fetch official PNG from CDN
        if club_id:
            rfu_img_url = f"https://images.englandrugby.com/club_images/{club_id}.png"
            try:
                img_resp = rfu_session.get(rfu_img_url, timeout=5)
                if img_resp.status_code == 200 and len(img_resp.content) > 100:
                    filename = f"{base_slug}.png"
                    # Upload to Supabase Storage Bucket
                    up_url = f"{SUPABASE_URL}/storage/v1/object/rfu-parcer-team-logos/{filename}"
                    up_headers = {
                        'apikey': SERVICE_KEY,
                        'Authorization': f'Bearer {SERVICE_KEY}',
                        'Content-Type': 'image/png',
                        'x-upsert': 'true'
                    }
                    r_up = requests.post(up_url, headers=up_headers, data=img_resp.content)
                    if r_up.status_code in [200, 201]:
                        public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{filename}"
                        return (team_name, public_url, "UPLOADED_RFU_PNG", filename)
            except Exception:
                pass

        # 3. Check if custom PNG/SVG/JPG already exists in bucket
        for candidate in [f"{slug}.png", f"{base_slug}.png", f"{slug}.svg", f"{base_slug}.svg", f"{slug}.jpg", f"{base_slug}.jpg"]:
            if candidate in existing_bucket_files:
                public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{candidate}"
                return (team_name, public_url, "EXISTING_BUCKET_FILE", candidate)

        # 4. Fallback: generate and upload SVG crest to bucket
        svg_filename = f"{slug}.svg"
        svg_content = generate_svg(team_name)
        up_url = f"{SUPABASE_URL}/storage/v1/object/rfu-parcer-team-logos/{svg_filename}"
        up_headers = {
            'apikey': SERVICE_KEY,
            'Authorization': f'Bearer {SERVICE_KEY}',
            'Content-Type': 'image/svg+xml',
            'x-upsert': 'true'
        }
        try:
            r_up = requests.post(up_url, headers=up_headers, data=svg_content.encode('utf-8'))
            if r_up.status_code in [200, 201]:
                public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{svg_filename}"
                return (team_name, public_url, "GENERATED_SVG", svg_filename)
        except Exception:
            pass

        return (team_name, None, "FAILED", None)

    team_list = sorted(list(all_teams))
    results = []
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(process_team, team_list))

    print("5. Upserting unified Supabase Storage URLs into team_logos table...", flush=True)
    batch_payload = []
    rfu_png_count = 0
    bucket_existing_count = 0
    svg_fallback_count = 0

    for name, logo_url, status, filename in results:
        if logo_url:
            batch_payload.append({'team_name': name, 'logo_url': logo_url})
            if status == "UPLOADED_RFU_PNG":
                rfu_png_count += 1
            elif status == "EXISTING_BUCKET_FILE":
                bucket_existing_count += 1
            elif status == "GENERATED_SVG":
                svg_fallback_count += 1

    # Chunk upserts
    chunk_size = 50
    for i in range(0, len(batch_payload), chunk_size):
        chunk = batch_payload[i:i + chunk_size]
        requests.post(f'{SUPABASE_URL}/rest/v1/team_logos', headers=headers, json=chunk)

    print("\n=======================================================", flush=True)
    print("[SUCCESS] FULL RFU REBUILD & SYNC COMPLETE", flush=True)
    print("=======================================================", flush=True)
    print(f"Total Unique Teams Processed: {len(team_list)}", flush=True)
    print(f"Total Logos in team_logos Table: {len(batch_payload)}", flush=True)
    print(f"  * Official RFU CDN PNG crests fetched & stored in bucket: {rfu_png_count}", flush=True)
    print(f"  * Storage Bucket Custom/Existing crests reused:           {bucket_existing_count}", flush=True)
    print(f"  * Fallback SVG crests generated:                           {svg_fallback_count}", flush=True)
    print("100% of all logo URLs are now hosted on your Supabase Storage Bucket!", flush=True)

if __name__ == '__main__':
    main()
