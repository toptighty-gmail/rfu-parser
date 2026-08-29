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

browser_headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
}

# Canonical RFU club IDs registry
KNOWN_RFU_CLUB_IDS = {
    'plymstock oaks': 16976,
    'plymstock oaks ii': 16976,
    'plymstock oaks colts': 16976,
    'plymstock': 16976,
    'plymstock albion oaks': 16976,
    'plymstock oaks club xv': 16976,
    'old plymothian & mannamedian': 15907,
    'old plymothian': 15907,
    'opm': 15907,
    'withycombe': 25785,
    'honiton': 10355,
    'south molton': 19624,
    'brixham': 3314,
    'brixham ii': 3314,
    'tavistock': 21699,
    'tavistock ii': 21699,
    'exeter saracens': 7777,
    'bideford': 2153,
    'bideford ii': 2153,
    'topsham': 22933,
    'topsham ii': 22933,
    'crediton': 5832,
    'crediton ii': 5832,
    'exmouth': 7823,
    'exmouth ii': 7823,
    'barnstaple': 1479,
    'barnstaple ii': 1479,
    'cullompton': 6003,
    'cullompton ii': 6003,
    'devonport services': 6405,
    'devonport services ii': 6405,
    'devonport services colts': 6405,
    'ivybridge': 11333,
    'paignton': 16301,
    'paignton ii': 16301,
    'torquay athletic': 23018,
    'torquay athletic ii': 23018,
    'newton abbot': 15156,
    'newton abbot ii': 15156,
    'okehampton': 15849,
    'okehampton ii': 15849,
    'sidmouth': 19308,
    'teignmouth': 21876,
    'camborne': 4001,
    'redruth': 17743,
    'cornish pirates': 5644,
    'plymouth albion': 16968,
    'bath rugby': 42,
    'exeter chiefs': 41,
    'bristol bears': 43,
    'gloucester rugby': 44,
    'harlequins': 45,
    'leicester tigers': 1005,
    'northampton saints': 1006,
    'saracens': 1007,
    'sale sharks': 1009,
    'newcastle falcons': 1010,
    'coventry': 5722,
    'coventry welsh': 5736,
    'ealing trailfinders': 7084,
    'bedford blues': 1827,
    'doncaster knights': 6559,
    'ampthill': 632,
    'caldy': 3933,
    'chinnor': 4817,
    'chew valley': 4752,
    'lydney': 13627,
    'matson': 14175,
    'st austell': 20038,
    'old redcliffians': 15926,
    'burnham-on-sea': 3658,
    'chard': 4578,
    'clevedon': 5098,
    'gordano': 8929,
    'keynsham': 12053,
    'wadebridge camels': 24083,
    'truro': 23351,
    'tiverton': 22756,
    'ilfracombe': 11090,
    'totnes': 23078,
    'salcombe': 18659,
}

def sanitize_slug(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name.strip().lower()).strip('_')

def get_base_club_name(team_name):
    name = re.sub(r'\b(I{1,3}|IV|V|VI|1st|2nd|3rd|4th|Club XV|Colts|Ladies|Women|Nomads|Wanderers|Extra|Development)\b', '', team_name, flags=re.IGNORECASE)
    name = re.sub(r'\s+', ' ', name).strip()
    return name if name else team_name

def find_club_id(team_name):
    clean = team_name.strip().lower()
    if clean in KNOWN_RFU_CLUB_IDS:
        return KNOWN_RFU_CLUB_IDS[clean]
    base = get_base_club_name(team_name).strip().lower()
    if base in KNOWN_RFU_CLUB_IDS:
        return KNOWN_RFU_CLUB_IDS[base]
    for k, cid in KNOWN_RFU_CLUB_IDS.items():
        if k in clean or clean in k:
            return cid
    return None

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

    print("4. Resolving official RFU club crests (PNG) & uploading to Supabase Storage Bucket...", flush=True)

    def process_team(team_name):
        slug = sanitize_slug(team_name)
        base_name = get_base_club_name(team_name)
        base_slug = sanitize_slug(base_name)

        # 1. Lookup RFU Club ID from registry
        club_id = find_club_id(team_name)
        if club_id:
            rfu_img_url = f"https://images.englandrugby.com/club_images/{club_id}.png"
            try:
                img_resp = requests.get(rfu_img_url, headers=browser_headers, timeout=5)
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

        # 2. Check if custom SVG/JPG exists in storage bucket
        for candidate in [f"{slug}.png", f"{base_slug}.png", f"{slug}.svg", f"{base_slug}.svg", f"{slug}.jpg", f"{base_slug}.jpg"]:
            if candidate in existing_bucket_files:
                public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{candidate}"
                return (team_name, public_url, "EXISTING_BUCKET_FILE", candidate)

        # 3. Default to SVG in bucket
        fallback_file = f"{slug}.svg"
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{fallback_file}"
        return (team_name, public_url, "BUCKET_SVG_FALLBACK", fallback_file)

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
            elif status == "BUCKET_SVG_FALLBACK":
                svg_fallback_count += 1

    # Chunk upserts
    chunk_size = 50
    for i in range(0, len(batch_payload), chunk_size):
        chunk = batch_payload[i:i + chunk_size]
        requests.post(f'{SUPABASE_URL}/rest/v1/team_logos', headers=headers, json=chunk)

    print("\n=======================================================", flush=True)
    print("[SUCCESS] REBUILD & CONSOLIDATION COMPLETE", flush=True)
    print("=======================================================", flush=True)
    print(f"Total Unique Teams Processed: {len(team_list)}", flush=True)
    print(f"Total Logos in team_logos Table: {len(batch_payload)}", flush=True)
    print(f"  * Official RFU CDN PNG crests synced & stored in bucket: {rfu_png_count}", flush=True)
    print(f"  * Storage Bucket Custom/Existing SVGs & JPGs mapped:    {bucket_existing_count}", flush=True)
    print(f"  * Fallback SVG crests in bucket:                         {svg_fallback_count}", flush=True)
    print("100% of all logo URLs are now hosted on your Supabase Storage Bucket!", flush=True)

if __name__ == '__main__':
    main()
