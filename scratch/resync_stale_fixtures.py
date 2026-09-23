import os
import re
import sys
import time
import datetime
import requests

repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)
from rfu_parser.scraper import RFUParser  # noqa: E402

env = open(os.path.join(repo_root, '.env'), encoding='utf-8').read()
SUPABASE_URL = re.search(r'SUPABASE_URL=(.+)', env).group(1).strip()
_key_match = re.search(r'SUPABASE_SERVICE_ROLE_KEY=(.+)', env) or re.search(r'SUPABASE_ANON_KEY=(.+)', env)
SERVICE_KEY = _key_match.group(1).strip()

headers = {
    'apikey': SERVICE_KEY,
    'Authorization': f'Bearer {SERVICE_KEY}',
    'Content-Type': 'application/json',
}
headers_rfu = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}

REQUEST_DELAY = 2.0
BACKOFF_DELAY = 45.0
MAX_RETRIES = 3
TODAY = datetime.datetime(2026, 9, 3)

LOG_PATH = os.path.join(os.path.dirname(__file__), 'resync_stale_fixtures.log')


def log(msg):
    line = f'{time.strftime("%Y-%m-%d %H:%M:%S")} | {msg}'
    print(line, flush=True)
    with open(LOG_PATH, 'a', encoding='utf-8') as f:
        f.write(line + '\n')


def fetch_all(endpoint, select, extra=''):
    rows = []
    offset = 0
    while True:
        r = requests.get(f'{SUPABASE_URL}/rest/v1/{endpoint}?select={select}{extra}&limit=1000&offset={offset}', headers=headers, timeout=30)
        batch = r.json()
        if not isinstance(batch, list) or not batch:
            break
        rows.extend(batch)
        offset += 1000
        if len(batch) < 1000:
            break
    return rows


def parse_db_date(s):
    if not s:
        return None
    clean = re.sub(r'^[A-Za-z]+,\s*', '', s).strip()
    clean = re.sub(r'(\d+)(st|nd|rd|th)', r'\1', clean, flags=re.IGNORECASE)
    for fmt in ['%d %b %Y', '%d %B %Y', '%B %d, %Y', '%d/%m/%Y', '%d/%m/%y']:
        try:
            return datetime.datetime.strptime(clean, fmt)
        except Exception:
            pass
    return None


def polite_get(session, url):
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = session.get(url, headers=headers_rfu, timeout=20)
        except Exception as e:
            log(f'  ! request error ({e}) attempt {attempt} for {url}')
            time.sleep(BACKOFF_DELAY)
            continue
        if r.status_code == 200 and len(r.text) > 1000:
            return r
        log(f'  ! got status={r.status_code} len={len(r.text)} on attempt {attempt}, backing off {BACKOFF_DELAY}s')
        time.sleep(BACKOFF_DELAY)
    log(f'  ! giving up on {url} after {MAX_RETRIES} attempts')
    return None


def norm(s):
    return (s or '').strip().lower()


def main():
    log('=== Starting stale-fixture resync ===')
    divs = fetch_all('divisions', 'id,season,division_name,source_url')
    div_info = {d['id']: d for d in divs}
    log(f'{len(divs)} divisions loaded')

    fx = fetch_all('fixtures', 'id,date,home_team,away_team,home_score,away_score,status,division_id')
    log(f'{len(fx)} fixtures loaded')

    stale_by_div = {}
    for f in fx:
        d = parse_db_date(f.get('date'))
        if d is None or d >= TODAY:
            continue
        no_score = f.get('home_score') is None or f.get('away_score') is None
        status = (f.get('status') or '').lower()
        if no_score and status != 'completed':
            stale_by_div.setdefault(f['division_id'], []).append(f)

    log(f'{len(stale_by_div)} divisions have at least one stale fixture ({sum(len(v) for v in stale_by_div.values())} rows total)')

    parser = RFUParser()
    session = requests.Session()

    total_updated = 0
    total_still_scheduled = 0
    total_no_match = 0
    divisions_processed = 0
    divisions_failed = 0

    div_ids = list(stale_by_div.keys())
    for i, div_id in enumerate(div_ids, 1):
        info = div_info.get(div_id)
        if not info or not info.get('source_url'):
            divisions_failed += 1
            continue

        resp = polite_get(session, info['source_url'])
        time.sleep(REQUEST_DELAY)
        if resp is None:
            divisions_failed += 1
            log(f"[{i}/{len(div_ids)}] FAILED to fetch {info['division_name']} ({info['season']})")
            continue

        try:
            crawled = parser.parse_fixtures(resp.text)
        except Exception as e:
            divisions_failed += 1
            log(f"[{i}/{len(div_ids)}] PARSE ERROR {info['division_name']} ({info['season']}): {e}")
            continue

        # Index crawled fixtures by exact (home, away) pair - stable identity within a season.
        crawled_by_pair = {}
        for cf in crawled:
            key = (norm(cf.home_team), norm(cf.away_team))
            crawled_by_pair[key] = cf

        updated_here = 0
        for db_f in stale_by_div[div_id]:
            key = (norm(db_f.get('home_team')), norm(db_f.get('away_team')))
            match = crawled_by_pair.get(key)
            if match is None:
                total_no_match += 1
                continue
            if match.status == 'Completed' and match.home_score is not None and match.away_score is not None:
                patch_payload = {'home_score': match.home_score, 'away_score': match.away_score, 'status': 'Completed'}
            elif match.status in ('HWO', 'AWO', 'Abandoned', 'Postponed'):
                # No numeric score exists for these outcomes, so only the status changes.
                patch_payload = {'status': match.status}
            else:
                patch_payload = None

            if patch_payload:
                r = requests.patch(
                    f"{SUPABASE_URL}/rest/v1/fixtures?id=eq.{db_f['id']}",
                    headers=headers,
                    json=patch_payload,
                )
                if r.status_code in (200, 204):
                    updated_here += 1
                    total_updated += 1
                else:
                    log(f"  ! patch failed for fixture {db_f['id']}: {r.status_code} {r.text[:150]}")
            else:
                total_still_scheduled += 1

        divisions_processed += 1
        if updated_here > 0 or i % 10 == 0 or i == len(div_ids):
            log(f"[{i}/{len(div_ids)}] {info['division_name']} ({info['season']}) -> updated={updated_here}/{len(stale_by_div[div_id])}")

    log(f'=== Done. Divisions processed={divisions_processed}, failed={divisions_failed}. '
        f'Fixtures updated={total_updated}, still genuinely scheduled/postponed={total_still_scheduled}, no crawl match={total_no_match} ===')


if __name__ == '__main__':
    main()
