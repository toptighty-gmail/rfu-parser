import requests
import json
import re

SUPABASE_URL = 'https://tgexkxrhcyxvnqafbdff.supabase.co'
SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnZXhreHJoY3l4dm5xYWZiZGZmIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NTI1MTkzMCwiZXhwIjoyMTAwODI3OTMwfQ.76Xky0DgpllldhRuMCjMFSkELciJCw_cSIIqQYNauoc'

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates'
}

def sanitize_slug(name):
    return re.sub(r'[^a-zA-Z0-9]+', '_', name.strip().lower()).strip('_')

def get_base_club_name(team_name):
    name = re.sub(r'\b(I{1,3}|IV|V|VI|1st|2nd|3rd|4th|Club XV|Colts|Ladies|Women|Nomads|Wanderers|Extra|Development)\b', '', team_name, flags=re.IGNORECASE)
    name = re.sub(r'\s+', ' ', name).strip()
    return name if name else team_name

def determine_competition_and_tier(div_name):
    d = div_name.lower().strip()
    comp_id = 1699 # Default South West
    tier = 8       # Default Counties 2
    region = 'South West'

    if 'premiership' in d:
        comp_id = 173
        tier = 1
        region = 'National'
    elif 'championship' in d:
        comp_id = 173
        tier = 2
        region = 'National'
    elif 'national 1' in d or 'national league 1' in d:
        comp_id = 1605
        tier = 3
        region = 'National'
    elif 'national 2' in d or 'national league 2' in d:
        comp_id = 1605
        tier = 4
        region = 'National'
    elif 'regional 1' in d:
        tier = 5
        if 'south west' in d: comp_id = 1699; region = 'South West'
        elif 'midlands' in d: comp_id = 1597; region = 'Midlands'
        elif 'south central' in d or 'south east' in d: comp_id = 261; region = 'London & SE'
        elif 'north' in d: comp_id = 1623; region = 'North'
    elif 'regional 2' in d:
        tier = 6
        if any(w in d for w in ['devon', 'cornwall', 'severn', 'south west']): comp_id = 1699; region = 'South West'
        elif 'midlands' in d: comp_id = 1597; region = 'Midlands'
        elif any(w in d for w in ['thames', 'london', 'se', 'south']): comp_id = 261; region = 'London & SE'
        elif 'north' in d: comp_id = 1623; region = 'North'
    elif 'counties 1' in d:
        tier = 7
        if any(w in d for w in ['western', 'devon', 'somerset', 'cornwall']): comp_id = 1699; region = 'South West'
        elif 'midlands' in d: comp_id = 1597; region = 'Midlands'
        elif any(w in d for w in ['kent', 'surrey', 'sussex', 'essex', 'herts']): comp_id = 261; region = 'London & SE'
        elif any(w in d for w in ['yorkshire', 'lancs', 'cumbria']): comp_id = 1623; region = 'North'
    elif 'counties 2' in d:
        tier = 8
        if any(w in d for w in ['devon', 'cornwall', 'somerset', 'gloucester']): comp_id = 1699; region = 'South West'
        elif 'midlands' in d: comp_id = 1597; region = 'Midlands'
        elif any(w in d for w in ['kent', 'surrey', 'sussex', 'essex', 'herts']): comp_id = 261; region = 'London & SE'
        elif any(w in d for w in ['yorkshire', 'lancs', 'cumbria']): comp_id = 1623; region = 'North'
    elif 'counties 3' in d:
        tier = 9
        if any(w in d for w in ['devon', 'cornwall', 'somerset', 'gloucester']): comp_id = 1699; region = 'South West'
    elif 'counties 4' in d:
        tier = 10
        if any(w in d for w in ['devon', 'cornwall', 'somerset', 'gloucester']): comp_id = 1699; region = 'South West'

    return comp_id, tier, region

def main():
    print("==========================================", flush=True)
    print("RELATIONAL SCHEMA DATA BACKFILL", flush=True)
    print("==========================================", flush=True)

    # 1. Backfill 'teams' table from 'team_logos' and custom_club_ids.json
    print("1. Populating 'teams' table...", flush=True)
    with open('scripts/custom_club_ids.json', 'r', encoding='utf-8') as f:
        custom_ids = json.load(f)

    # Fetch team logos
    r_logos = requests.get(f'{SUPABASE_URL}/rest/v1/team_logos?select=*', headers=headers)
    logos = r_logos.json() if r_logos.status_code == 200 else []

    # Map name -> logo
    logo_map = {l['team_name'].lower().strip(): l['logo_url'] for l in logos if l.get('team_name')}

    teams_payload = []
    seen_ids = set()
    synthetic_id = 90000

    for l in logos:
        tname = l['team_name'].strip()
        clean = tname.lower()
        base = get_base_club_name(tname)
        base_clean = base.lower()

        # Find RFU Team ID
        rfu_id = None
        if clean in custom_ids and custom_ids[clean]:
            rfu_id = custom_ids[clean]
        elif base_clean in custom_ids and custom_ids[base_clean]:
            rfu_id = custom_ids[base_clean]

        if not rfu_id:
            # Assign synthetic sequential ID for teams without explicit RFU ID
            synthetic_id += 1
            rfu_id = synthetic_id

        # If rfu_id duplicate (e.g. 1st and 2nd team sharing parent club id)
        actual_id = rfu_id
        if actual_id in seen_ids:
            synthetic_id += 1
            actual_id = synthetic_id
        seen_ids.add(actual_id)

        county = 'Devon'
        if any(w in clean for w in ['cornwall', 'st austell', 'camborne', 'redruth', 'penryn', 'wadebridge', 'st ives', 'st agnes', 'falmouth']):
            county = 'Cornwall'
        elif any(w in clean for w in ['somerset', 'bath', 'taunton', 'bristol', 'wellington', 'clevedon', 'chard', 'keynsham', 'gordano']):
            county = 'Somerset'
        elif any(w in clean for w in ['gloucester', 'cinderford', 'lydney', 'matson', 'chew valley']):
            county = 'Gloucestershire'

        teams_payload.append({
            'rfu_team_id': actual_id,
            'team_name': tname,
            'base_club_name': base,
            'parent_club_id': rfu_id,
            'county': county,
            'logo_url': l.get('logo_url')
        })

    # Chunk upsert teams
    for i in range(0, len(teams_payload), 50):
        chunk = teams_payload[i:i+50]
        requests.post(f'{SUPABASE_URL}/rest/v1/teams', headers=headers, json=chunk)
    print(f"  [OK] Upserted {len(teams_payload)} teams into 'teams' table.", flush=True)

    # 2. Backfill 'divisions' table with competition_id, tier_level, region
    print("2. Backfilling 'divisions' metadata...", flush=True)
    r_divs = requests.get(f'{SUPABASE_URL}/rest/v1/divisions?select=*', headers=headers)
    divs = r_divs.json() if r_divs.status_code == 200 else []

    div_count = 0
    for d in divs:
        dname = d['division_name']
        comp_id, tier, region = determine_competition_and_tier(dname)
        requests.patch(
            f"{SUPABASE_URL}/rest/v1/divisions?id=eq.{d['id']}",
            headers=headers,
            json={
                'rfu_competition_id': comp_id,
                'tier_level': tier,
                'region': region
            }
        )
        div_count += 1
    print(f"  [OK] Updated metadata for {div_count} divisions.", flush=True)

    # 3. Backfill 'standings' table with rfu_team_id
    print("3. Linking 'standings' rows to canonical rfu_team_id...", flush=True)
    # Build name -> team_id lookup
    name_to_id = {t['team_name'].lower().strip(): t['rfu_team_id'] for t in teams_payload}

    r_standings = requests.get(f'{SUPABASE_URL}/rest/v1/standings?select=id,team_name', headers=headers)
    standings = r_standings.json() if r_standings.status_code == 200 else []

    linked_st = 0
    for s in standings:
        sname = s.get('team_name', '').lower().strip()
        if sname in name_to_id:
            tid = name_to_id[sname]
            requests.patch(
                f"{SUPABASE_URL}/rest/v1/standings?id=eq.{s['id']}",
                headers=headers,
                json={'rfu_team_id': tid}
            )
            linked_st += 1
    print(f"  [OK] Linked {linked_st}/{len(standings)} standings rows to team IDs.", flush=True)

    # 4. Backfill 'fixtures' table with home_team_id & away_team_id
    print("4. Linking 'fixtures' rows to home & away team IDs...", flush=True)
    r_fixtures = requests.get(f'{SUPABASE_URL}/rest/v1/fixtures?select=id,home_team,away_team', headers=headers)
    fixtures = r_fixtures.json() if r_fixtures.status_code == 200 else []

    linked_fix = 0
    for f in fixtures:
        hname = f.get('home_team', '').lower().strip()
        aname = f.get('away_team', '').lower().strip()
        hid = name_to_id.get(hname)
        aid = name_to_id.get(aname)

        patch_data = {}
        if hid: patch_data['home_team_id'] = hid
        if aid: patch_data['away_team_id'] = aid

        if patch_data:
            requests.patch(
                f"{SUPABASE_URL}/rest/v1/fixtures?id=eq.{f['id']}",
                headers=headers,
                json=patch_data
            )
            linked_fix += 1
    print(f"  [OK] Linked {linked_fix}/{len(fixtures)} fixtures rows to team IDs.", flush=True)

    print("\n==========================================", flush=True)
    print("DATA BACKFILL COMPLETE!", flush=True)
    print("==========================================", flush=True)

if __name__ == '__main__':
    main()
