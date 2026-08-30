import requests

url = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
service_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'
headers = {'apikey': service_key, 'Authorization': f'Bearer {service_key}'}

did_real_2025 = '36dc0266-34c2-485e-a751-80da9935cf94'
r1 = requests.get(f"{url}/rest/v1/divisions?id=eq.{did_real_2025}", headers=headers).json()
r1_fix = requests.get(f"{url}/rest/v1/fixtures?division_id=eq.{did_real_2025}", headers=headers).json()
print(f"Division {did_real_2025}: {r1} -> {len(r1_fix)} fixtures")
if r1_fix:
    print(f"  Sample date: {r1_fix[0].get('date')} | {r1_fix[0].get('home_team')} v {r1_fix[0].get('away_team')}")
