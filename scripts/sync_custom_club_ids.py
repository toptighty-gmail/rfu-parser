import os
import json
import re
import requests
import concurrent.futures

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
}

def sanitize_slug(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name.strip().lower()).strip('_')

def sync_club(team_name, club_val, all_db_teams):
    if club_val is None or club_val == 0 or str(club_val).strip() == '':
        return (team_name, None, False, "SKIPPED (null or empty)")
    
    slug = sanitize_slug(team_name)
    
    # 1. Determine image source URL
    if isinstance(club_val, int) or (isinstance(club_val, str) and club_val.isdigit()):
        cid = int(club_val)
        source_url = f"https://images.englandrugby.com/club_images/{cid}.png"
        ext = "png"
    elif isinstance(club_val, str) and (club_val.startswith('http://') or club_val.startswith('https://')):
        source_url = club_val.strip()
        ext = "png"
        if ".jpg" in source_url.lower() or ".jpeg" in source_url.lower():
            ext = "jpg"
        elif ".svg" in source_url.lower():
            ext = "svg"
    else:
        return (team_name, club_val, False, "Invalid ID or URL format")

    filename = f"{slug}.{ext}"
    content_type = 'image/png' if ext == 'png' else ('image/jpeg' if ext == 'jpg' else 'image/svg+xml')

    try:
        # 2. Download image
        img_resp = requests.get(source_url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=8)
        if img_resp.status_code == 200 and len(img_resp.content) > 100:
            # 3. Upload to Supabase Storage Bucket
            up_url = f"{SUPABASE_URL}/storage/v1/object/rfu-parcer-team-logos/{filename}"
            up_headers = {
                'apikey': SERVICE_KEY,
                'Authorization': f'Bearer {SERVICE_KEY}',
                'Content-Type': content_type,
                'x-upsert': 'true'
            }
            r_up = requests.post(up_url, headers=up_headers, data=img_resp.content)
            
            if r_up.status_code in [200, 201]:
                public_url = f"{SUPABASE_URL}/storage/v1/object/public/rfu-parcer-team-logos/{filename}"
                
                # 4. Find matching team names in database (case-insensitive)
                matched_names = [db_name for db_name in all_db_teams if db_name.lower().strip() == team_name.lower().strip() or db_name.lower().strip() == slug.replace('_', ' ')]
                if not matched_names:
                    matched_names = [team_name]

                for name_to_update in matched_names:
                    requests.patch(
                        f"{SUPABASE_URL}/rest/v1/team_logos?team_name=eq.{name_to_update}",
                        headers=headers,
                        json={'logo_url': public_url}
                    )
                    requests.post(
                        f"{SUPABASE_URL}/rest/v1/team_logos",
                        headers={
                            'apikey': SERVICE_KEY,
                            'Authorization': f'Bearer {SERVICE_KEY}',
                            'Content-Type': 'application/json',
                            'Prefer': 'resolution=merge-duplicates'
                        },
                        json={'team_name': name_to_update, 'logo_url': public_url}
                    )
                return (team_name, club_val, True, f"Uploaded {filename} ({len(img_resp.content)} bytes) -> updated {matched_names}")
            else:
                return (team_name, club_val, False, f"Bucket upload failed: {r_up.status_code}")
        else:
            return (team_name, club_val, False, f"Image fetch returned HTTP {img_resp.status_code}")
    except Exception as e:
        return (team_name, club_val, False, f"Error: {e}")

def main():
    json_path = os.path.join(os.path.dirname(__file__), 'custom_club_ids.json')
    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found!")
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        mapping = json.load(f)

    # Filter non-null entries
    active_entries = {k: v for k, v in mapping.items() if v is not None and v != 0 and str(v).strip() != ''}

    print(f"Loaded {len(mapping)} clubs from custom_club_ids.json ({len(active_entries)} active with IDs/URLs)", flush=True)

    if not active_entries:
        print("No active IDs or URLs filled in yet. Edit custom_club_ids.json and replace null with an RFU ID or URL!")
        return

    # Fetch all existing team names in DB
    r_db = requests.get(f"{SUPABASE_URL}/rest/v1/team_logos?select=team_name", headers=headers)
    all_db_teams = [row['team_name'] for row in r_db.json()] if r_db.status_code == 200 else []

    print("Syncing with image source and Supabase Storage...", flush=True)
    success_count = 0
    fail_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(sync_club, name, val, all_db_teams) for name, val in active_entries.items()]
        for future in concurrent.futures.as_completed(futures):
            name, val, success, msg = future.result()
            if success:
                print(f"  [OK] {name} -> {msg}", flush=True)
                success_count += 1
            else:
                print(f"  [FAIL] {name} -> {msg}", flush=True)
                fail_count += 1

    print("\n==========================================", flush=True)
    print(f"SYNC COMPLETE: {success_count} succeeded, {fail_count} failed.")
    print("==========================================", flush=True)

if __name__ == '__main__':
    main()
