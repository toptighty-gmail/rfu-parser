import os
import json
import datetime
import requests

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json'
}

tables = [
    'divisions',
    'standings',
    'fixtures',
    'custom_fixtures',
    'team_logos'
]

def backup():
    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'backups')
    os.makedirs(backup_dir, exist_ok=True)
    
    backup_file = os.path.join(backup_dir, f'supabase_backup_{timestamp}.json')
    backup_data = {
        'timestamp': timestamp,
        'supabase_url': SUPABASE_URL,
        'tables': {}
    }
    
    print(f"Starting database backup to {backup_file}...", flush=True)
    
    for table in tables:
        try:
            r = requests.get(f'{SUPABASE_URL}/rest/v1/{table}?select=*', headers=headers)
            if r.status_code == 200:
                rows = r.json()
                backup_data['tables'][table] = rows
                print(f"  [OK] Backed up {table}: {len(rows)} records", flush=True)
            else:
                print(f"  [FAIL] Failed to fetch {table}: HTTP {r.status_code}", flush=True)
        except Exception as e:
            print(f"  [ERROR] Error backing up {table}: {e}", flush=True)
            
    # Also backup storage bucket listing
    try:
        r_bucket = requests.post(f'{SUPABASE_URL}/storage/v1/object/list/rfu-parcer-team-logos', headers=headers, json={'prefix': '', 'limit': 1000})
        if r_bucket.status_code == 200:
            objects = r_bucket.json()
            backup_data['storage_bucket_files'] = [obj.get('name') for obj in objects]
            print(f"  [OK] Backed up storage bucket file list: {len(objects)} files", flush=True)
    except Exception as e:
        print(f"  [ERROR] Error backing up bucket: {e}", flush=True)
        
    with open(backup_file, 'w', encoding='utf-8') as f:
        json.dump(backup_data, f, indent=2)
        
    print(f"\n==========================================", flush=True)
    print(f"BACKUP COMPLETE: Saved to {backup_file}", flush=True)
    print(f"==========================================", flush=True)

if __name__ == '__main__':
    backup()
