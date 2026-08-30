import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

ids = ['f2ec8c92-d8c0-4084-9610-e372dc1af3f1', '3b612c90-7c57-49aa-b7dd-5896a3f3d8df']
for did in ids:
    r = requests.get(f"{url}/rest/v1/divisions?id=eq.{did}", headers=headers).json()
    r_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did}", headers=headers).json()
    print(f"Div ID: {did} -> {r} (Fixtures: {len(r_fix)})")
