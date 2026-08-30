import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

# Find and remove empty division rows (standings count == 0 and fixtures count == 0)
r_divs = requests.get(f'{url}/rest/v1/divisions?select=*', headers=headers)
divs = r_divs.json()

removed = 0
for d in divs:
    did = d['id']
    r_st = requests.get(f'{url}/rest/v1/standings?division_id=eq.{did}&select=id', headers=headers)
    st_count = len(r_st.json()) if r_st.status_code == 200 else 0
    
    r_fx = requests.get(f'{url}/rest/v1/fixtures?division_id=eq.{did}&select=id', headers=headers)
    fx_count = len(r_fx.json()) if r_fx.status_code == 200 else 0
    
    if st_count == 0 and fx_count == 0:
        print(f"Deleting empty division row: {did} | {d['season']} | {d['division_name']}")
        requests.delete(f'{url}/rest/v1/divisions?id=eq.{did}', headers=headers)
        removed += 1

print(f"Cleanup complete. Deleted {removed} empty division records.")
