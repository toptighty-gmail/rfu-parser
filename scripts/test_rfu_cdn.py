import requests
import sys

test_ids = [
    (16976, 'Plymstock Oaks'),
    (5832, 'Crediton'),
    (7777, 'Exeter Saracens'),
    (7823, 'Exmouth'),
    (2153, 'Bideford'),
    (3314, 'Brixham'),
    (22933, 'Topsham'),
    (25785, 'Withycombe'),
    (10355, 'Honiton'),
    (19624, 'South Molton'),
    (21699, 'Tavistock'),
    (15907, 'Old Plymothian & Mannamedian'),
]

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

print("Testing direct England Rugby image CDN with Browser User-Agent:", flush=True)
for club_id, name in test_ids:
    url = f"https://images.englandrugby.com/club_images/{club_id}.png"
    try:
        r = requests.get(url, headers=headers, timeout=5)
        print(f"  [{r.status_code}] {name} (ID: {club_id}) -> Content-Type: {r.headers.get('Content-Type')}, Size: {len(r.content)} bytes", flush=True)
    except Exception as e:
        print(f"  [ERROR] {name} (ID: {club_id}) -> {e}", flush=True)
