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

def sync_club(team_name, club_id):
    slug = sanitize_slug(team_name)
    filename = f"{slug}.png"
    rfu_url = f"https://images.englandrugby.com/club_images/{club_id}.png"
    
    try:
        # 1. Download image from England Rugby CDN
        img_resp = requests.get(rfu_url, headers={'User-Agent': 'Mozilla/5.0'}, timeout=6)
        if img_resp.status_code == 200 and len(img_resp.content) > 100:
            # 2. Upload to Supabase Storage Bucket
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
                
                # 3. Patch or Upsert in team_logos table
                r_db = requests.post(
                    f"{SUPABASE_URL}/rest/v1/team_logos",
                    headers={
                        'apikey': SERVICE_KEY,
                        'Authorization': f'Bearer {SERVICE_KEY}',
                        'Content-Type': 'application/json',
                        'Prefer': 'resolution=merge-duplicates'
                    },
                    json={'team_name': team_name, 'logo_url': public_url}
                )
                return (team_name, club_id, True, f"Uploaded {filename} ({len(img_resp.content)} bytes)")
            else:
                return (team_name, club_id, False, f"Bucket upload failed: {r_up.status_code}")
        else:
            return (team_name, club_id, False, f"RFU CDN returned HTTP {img_resp.status_code}")
    except Exception as e:
        return (team_name, club_id, False, f"Error: {e}")

def main():
    json_path = os.path.join(os.path.dirname(__file__), 'custom_club_ids.json')
    if not os.path.exists(json_path):
        print(f"Error: {json_path} not found!")
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        mapping = json.load(f)

    print(f"Loaded {len(mapping)} custom club IDs from custom_club_ids.json", flush=True)
    print("Syncing with England Rugby CDN and Supabase Storage...", flush=True)

    success_count = 0
    fail_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(sync_club, name, cid) for name, cid in mapping.items()]
        for future in concurrent.futures.as_completed(futures):
            name, cid, success, msg = future.result()
            if success:
                print(f"  [OK] {name} (ID: {cid}) -> {msg}", flush=True)
                success_count += 1
            else:
                print(f"  [FAIL] {name} (ID: {cid}) -> {msg}", flush=True)
                fail_count += 1

    print("\n==========================================", flush=True)
    print(f"SYNC COMPLETE: {success_count} succeeded, {fail_count} failed.")
    print("==========================================", flush=True)

if __name__ == '__main__':
    main()
