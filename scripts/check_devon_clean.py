import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

r = requests.get(f'{url}/rest/v1/divisions?division_name=ilike.*devon*&select=*', headers=headers)
for d in r.json():
    did = d['id']
    r_st = requests.get(f'{url}/rest/v1/standings?division_id=eq.{did}&select=id', headers=headers)
    print(did, '|', d['season'], '|', d['division_name'], '| Standings:', len(r_st.json()))
