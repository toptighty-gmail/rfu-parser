import re
import time
import datetime
from collections import defaultdict

import requests

_env = open('.env', encoding='utf-8').read()
SUPABASE_URL = re.search(r'SUPABASE_URL=(.+)', _env).group(1).strip()
_key_match = re.search(r'SUPABASE_SERVICE_ROLE_KEY=(.+)', _env) or re.search(r'SUPABASE_ANON_KEY=(.+)', _env)
SERVICE_KEY = _key_match.group(1).strip()

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
}

LOG_PATH = 'scratch/fix_round_numbers.log'


def log(msg):
    line = f'{time.strftime("%Y-%m-%d %H:%M:%S")} | {msg}'
    print(line, flush=True)
    with open(LOG_PATH, 'a', encoding='utf-8') as f:
        f.write(line + '\n')


def fetch_all(endpoint, select, extra=''):
    rows = []
    offset = 0
    while True:
        r = requests.get(
            f'{SUPABASE_URL}/rest/v1/{endpoint}?select={select}{extra}&limit=1000&offset={offset}',
            headers=headers, timeout=30,
        )
        batch = r.json()
        if not isinstance(batch, list) or not batch:
            break
        rows.extend(batch)
        offset += 1000
        if len(batch) < 1000:
            break
    return rows


def parse_date(s):
    if not s:
        return None
    clean = re.sub(r'^[A-Za-z]+,\s*', '', s).strip()
    clean = re.sub(r'(\d+)(st|nd|rd|th)', r'\1', clean, flags=re.IGNORECASE)
    for fmt in ('%d %b %Y', '%d %B %Y'):
        try:
            return datetime.datetime.strptime(clean, fmt)
        except Exception:
            pass
    return None


ROUND_RE = re.compile(r'^Round (\d+)$')


def compute_correct_rounds(dates):
    """Mirrors the clustering algorithm in rfu_parser/scraper.py: dates
    within 3 days of the *first* date in the current cluster join it."""
    unique_dates = sorted(set(dates))
    clusters = []
    current = []
    for d in unique_dates:
        if not current:
            current.append(d)
        elif (d - current[0]).days <= 3:
            current.append(d)
        else:
            clusters.append(current)
            current = [d]
    if current:
        clusters.append(current)

    date_to_round = {}
    for idx, cluster in enumerate(clusters, start=1):
        for d in cluster:
            date_to_round[d] = idx
    return date_to_round


def patch_batch(ids, new_round):
    id_list = ','.join(ids)
    r = requests.patch(
        f"{SUPABASE_URL}/rest/v1/fixtures?id=in.({id_list})",
        headers=headers,
        json={'round_num': new_round},
        timeout=30,
    )
    return r


def main():
    log('=== Starting round-number recomputation (all seasons) ===')
    divisions = fetch_all('divisions', 'id,division_name,season')
    log(f'{len(divisions)} divisions loaded')

    fixtures = fetch_all('fixtures', 'id,division_id,date,round_num,is_custom')
    log(f'{len(fixtures)} fixtures loaded')

    by_div = defaultdict(list)
    for f in fixtures:
        by_div[f['division_id']].append(f)

    total_updated = 0
    total_batches = 0
    divisions_touched = 0
    divisions_failed = 0

    for i, d in enumerate(divisions, 1):
        rows = by_div.get(d['id'], [])
        if not rows:
            continue

        # Only real league fixtures with a plain "Round N" label participate
        # in date-based round clustering; custom/cup/friendly rows are left
        # exactly as they are.
        eligible = [
            f for f in rows
            if not f.get('is_custom') and f.get('round_num') and ROUND_RE.match(f['round_num'])
        ]
        if not eligible:
            continue

        dated = []
        for f in eligible:
            dt = parse_date(f['date'])
            if dt is not None:
                dated.append((f, dt))

        if not dated:
            continue

        date_to_round = compute_correct_rounds([dt for _, dt in dated])

        # Group fixture ids by their correct new round label, but only for
        # fixtures whose current label is wrong.
        to_update = defaultdict(list)
        for f, dt in dated:
            correct = f'Round {date_to_round[dt]}'
            if f['round_num'] != correct:
                to_update[correct].append(f['id'])

        if not to_update:
            continue

        div_updated = 0
        div_failed = False
        for new_round, ids in to_update.items():
            for j in range(0, len(ids), 50):
                chunk = ids[j:j + 50]
                try:
                    r = patch_batch(chunk, new_round)
                except Exception as e:
                    log(f"  ! request error for {d['division_name']} ({d['season']}) -> {new_round}: {e}")
                    div_failed = True
                    continue
                if r.status_code in (200, 204):
                    div_updated += len(chunk)
                    total_batches += 1
                else:
                    log(f"  ! patch failed for {d['division_name']} ({d['season']}) -> {new_round}: {r.status_code} {r.text[:150]}")
                    div_failed = True

        total_updated += div_updated
        divisions_touched += 1
        if div_failed:
            divisions_failed += 1

        if i % 25 == 0 or i == len(divisions):
            log(f'[{i}/{len(divisions)}] divisions processed, {divisions_touched} touched so far, {total_updated} fixtures updated so far')

    log(f'=== Done. Divisions touched={divisions_touched} (failures={divisions_failed}), '
        f'fixtures updated={total_updated}, PATCH batches={total_batches} ===')


if __name__ == '__main__':
    main()
