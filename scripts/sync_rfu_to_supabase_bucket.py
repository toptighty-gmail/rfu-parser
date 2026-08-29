import requests
import re

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': service_key,
    'Authorization': f'Bearer {service_key}',
}
browser_headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

def sanitize_slug(name):
    clean = re.sub(r'[^a-zA-Z0-9]+', '_', name.strip().lower()).strip('_')
    return clean

# 1. Fetch all distinct teams from standings, fixtures, and teams_db
r_teams = requests.get(f'{url}/rest/v1/team_logos?select=team_name', headers=headers)
known_names = [t['team_name'] for t in r_teams.json()] if r_teams.status_code == 200 else []

print(f"Total known teams to sync: {len(known_names)}", flush=True)

uploaded_count = 0
failed_count = 0

for name in known_names:
    slug = sanitize_slug(name)
    bucket_filename = f"{slug}.png"
    public_url = f"{url}/storage/v1/object/public/rfu-parcer-team-logos/{bucket_filename}"
    
    # 1. Try search API to get RFU Club ID if possible
    search_url = f"https://www.englandrugby.com/api/fixtures-and-result/search?name={name}"
    club_id = None
    try:
        s_resp = requests.get(search_url, headers=browser_headers, timeout=5)
        if s_resp.status_code == 200:
            data = s_resp.json()
            if isinstance(data, list) and len(data) > 0:
                club_id = data[0].get('_id')
    except Exception:
        pass
    
    png_data = None
    if club_id:
        rfu_img_url = f"https://images.englandrugby.com/club_images/{club_id}.png"
        try:
            img_resp = requests.get(rfu_img_url, headers=browser_headers, timeout=5)
            if img_resp.status_code == 200 and 'image' in img_resp.headers.get('Content-Type', ''):
                png_data = img_resp.content
        except Exception:
            pass
    
    if png_data:
        # Upload to Supabase Storage Bucket
        upload_url = f"{url}/storage/v1/object/rfu-parcer-team-logos/{bucket_filename}"
        up_resp = requests.post(
            upload_url,
            headers={
                'apikey': service_key,
                'Authorization': f'Bearer {service_key}',
                'Content-Type': 'image/png',
                'x-upsert': 'true'
            },
            data=png_data
        )
        
        # Update team_logos table with CORS-friendly Supabase bucket URL
        requests.post(
            f"{url}/rest/v1/team_logos",
            headers={
                'apikey': service_key,
                'Authorization': f'Bearer {service_key}',
                'Content-Type': 'application/json',
                'Prefer': 'resolution=merge-duplicates'
            },
            json={'team_name': name, 'logo_url': public_url}
        )
        print(f" [OK] {name} -> uploaded {bucket_filename} ({len(png_data)} bytes)", flush=True)
        uploaded_count += 1
    else:
        print(f" [MISSING] {name} (No RFU CDN image found)", flush=True)
        failed_count += 1

print(f"\n--- SYNC COMPLETE ---", flush=True)
print(f"Uploaded into Supabase Bucket: {uploaded_count}", flush=True)
print(f"Missing RFU Images (Need Custom Upload): {failed_count}", flush=True)
