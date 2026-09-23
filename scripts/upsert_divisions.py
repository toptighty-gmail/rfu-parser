"""
Upsert divisions/standings/fixtures into Supabase from a crawler JSON or by crawling live.

Usage examples:
  # Use an existing JSON file produced by the scraper
  python scripts/upsert_divisions.py --file output/division_75799.json --upsert-standings --upsert-fixtures

  # Crawl live for a division and upsert
  python scripts/upsert_divisions.py --division 75799 --season 2026-2027 --upsert-standings

Options:
  --file PATH            Path to a JSON file produced by the scraper (takes priority)
  --division ID          RFU division id to crawl (e.g. 75799)
  --season SEASON        Season string for crawling (e.g. 2026-2027)
  --upsert-standings     Upsert standings table
  --upsert-fixtures      Upsert fixtures table
  --dry-run              Do everything except POST to Supabase

This script reads SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_KEY) from .env at the repo root.
It uses the REST API endpoints: /rest/v1/divisions, /rest/v1/standings, /rest/v1/fixtures

Be careful: this performs writes. Prefer to run with --dry-run first.
"""

import os
import sys
import json
import argparse
import time
from urllib.parse import quote

import requests

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
ENV_PATH = os.path.join(ROOT, '.env')


def load_env(path):
    env = {}
    try:
        with open(path, 'r', encoding='utf-8') as f:
            for ln in f:
                line = ln.strip()
                if not line or line.startswith('#') or '=' not in line:
                    continue
                k, v = line.split('=', 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    except FileNotFoundError:
        pass
    return env


def get_supabase_client(env):
    url = env.get('SUPABASE_URL') or env.get('SUPABASE_PROJECT_URL')
    key = env.get('SUPABASE_SERVICE_ROLE_KEY') or env.get('SUPABASE_KEY') or env.get('SUPABASE_ANON_KEY')
    if not url or not key:
        raise RuntimeError('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_KEY) must be set in .env')
    return url.rstrip('/'), key


def post_json(endpoint, key, payload, dry_run=False, params=None):
    headers = {
        'apikey': key,
        'Authorization': f'Bearer {key}',
        'Content-Type': 'application/json'
    }
    url = endpoint
    if params:
        url = url + params
    if dry_run:
        print('DRY-RUN POST to', url)
        print('payload:', json.dumps(payload, indent=2)[:2000])
        return None
    resp = requests.post(url, json=payload, headers=headers, timeout=30)
    try:
        resp.raise_for_status()
    except Exception:
        print('POST failed:', resp.status_code, resp.text[:1000])
        raise
    return resp


def get_json(endpoint, key, params=''):
    headers = {
        'apikey': key,
        'Authorization': f'Bearer {key}',
        'Content-Type': 'application/json'
    }
    url = endpoint + params
    resp = requests.get(url, headers=headers, timeout=30)
    if resp.status_code != 200:
        print('GET failed:', resp.status_code, resp.text[:1000])
        resp.raise_for_status()
    return resp.json()


def upsert_division(base, key, result, dry_run=False):
    # Build division payload
    div_payload = {
        'division_name': result.get('division_name'),
        'season': result.get('season'),
        'source_url': result.get('source_url', '')
    }
    if result.get('rfu_competition_id') is not None:
        div_payload['rfu_competition_id'] = result.get('rfu_competition_id')
    if result.get('rfu_division_id') is not None:
        div_payload['rfu_division_id'] = result.get('rfu_division_id')

    endpoint = base + '/rest/v1/divisions'
    # Use the DB unique key to resolve conflicts (division_name, season)
    params = '?on_conflict=division_name,season'
    print('Upserting division:', div_payload['division_name'], div_payload.get('season'))
    try:
        post_json(endpoint, key, [div_payload], dry_run=dry_run, params=params)
    except Exception as e:
        # If conflict due to unique constraint, try to PATCH existing row instead
        print('POST failed, attempting to PATCH existing division row:', e)
        q = f"?division_name=eq.{quote(div_payload['division_name'])}&season=eq.{quote(div_payload['season'])}&select=id"
        rows = get_json(base + '/rest/v1/divisions', key, params=q)
        if rows:
            division_id = rows[0].get('id')
            print('Existing division found id:', division_id)
            if not dry_run:
                # Perform PATCH to update the existing division by id
                patch_url = base + f"/rest/v1/divisions?id=eq.{division_id}"
                headers = {
                    'apikey': key,
                    'Authorization': f'Bearer {key}',
                    'Content-Type': 'application/json'
                }
                resp = requests.patch(patch_url, json=div_payload, headers=headers, timeout=30)
                try:
                    resp.raise_for_status()
                except Exception:
                    print('PATCH failed:', resp.status_code, resp.text[:1000])
                    raise
            return division_id
        else:
            print('Failed to resolve division id after POST failure')
            raise

    # Fetch division id
    q = f"?division_name=eq.{quote(div_payload['division_name'])}&season=eq.{quote(div_payload['season'])}&select=id"
    rows = get_json(base + '/rest/v1/divisions', key, params=q)
    if rows:
        division_id = rows[0].get('id')
        print('Division id resolved to:', division_id)
        return division_id
    print('Failed to resolve division id after upsert')
    return None


def upsert_standings(base, key, division_id, standings, dry_run=False):
    if not standings:
        print('No standings to upsert')
        return 0
    payload = []
    for s in standings:
        payload.append({
            'division_id': division_id,
            'position': s.get('position'),
            'team_name': s.get('team_name'),
            'played': s.get('played'),
            'won': s.get('won'),
            'drawn': s.get('drawn'),
            'lost': s.get('lost'),
            'points_for': s.get('points_for'),
            'points_against': s.get('points_against'),
            'points_diff': s.get('points_diff'),
            'try_bonus': s.get('try_bonus'),
            'lose_bonus': s.get('lose_bonus'),
            'points': s.get('points'),
            'form': s.get('form', '')
        })
    print(f'Upserting {len(payload)} standings rows')
    endpoint = base + '/rest/v1/standings'
    params = '?on_conflict=division_id,team_name'
    # Try bulk POST first; if it fails due to conflicts, fallback to per-row PATCH
    try:
        post_json(endpoint, key, payload, dry_run=dry_run, params=params)
        return len(payload)
    except Exception as e:
        print('Bulk standings POST failed, attempting per-row upsert with PATCH fallback:', e)
        count = 0
        for row in payload:
            try:
                post_json(endpoint, key, [row], dry_run=dry_run, params=params)
                count += 1
            except Exception:
                # find existing row id
                q = f"?division_id=eq.{quote(division_id)}&team_name=eq.{quote(row['team_name'])}&select=id"
                existing = get_json(base + '/rest/v1/standings', key, params=q)
                if existing:
                    existing_id = existing[0].get('id')
                    print('Patching existing standing id', existing_id)
                    if not dry_run:
                        patch_url = base + f"/rest/v1/standings?id=eq.{existing_id}"
                        headers = {
                            'apikey': key,
                            'Authorization': f'Bearer {key}',
                            'Content-Type': 'application/json'
                        }
                        resp = requests.patch(patch_url, json=row, headers=headers, timeout=30)
                        try:
                            resp.raise_for_status()
                        except Exception:
                            print('PATCH failed for standing:', resp.status_code, resp.text[:1000])
                            raise
                    count += 1
                else:
                    print('Could not find existing standing to patch for', row['team_name'])
        return count


def upsert_fixtures(base, key, division_id, fixtures, dry_run=False):
    if not fixtures:
        print('No fixtures to upsert')
        return 0
    payload = []
    for f in fixtures:
        payload.append({
            'division_id': division_id,
            'date': f.get('date'),
            'time': f.get('time') or '15:00',
            'home_team': f.get('home_team'),
            'away_team': f.get('away_team'),
            'home_score': f.get('home_score'),
            'away_score': f.get('away_score'),
            'status': f.get('status') or 'Scheduled',
            'venue': f.get('venue') or '',
            'round_num': f.get('round_num') or '',
            'is_custom': f.get('is_custom', False)
        })
    print(f'Upserting {len(payload)} fixtures rows')
    endpoint = base + '/rest/v1/fixtures'
    params = '?on_conflict=division_id,home_team,away_team,round_num'
    # Try bulk POST first; if conflict, fallback to per-row upsert with PATCH
    try:
        batch_size = 200
        sent = 0
        for i in range(0, len(payload), batch_size):
            chunk = payload[i:i+batch_size]
            post_json(endpoint, key, chunk, dry_run=dry_run, params=params)
            sent += len(chunk)
            time.sleep(0.15)
        return sent
    except Exception as e:
        print('Bulk fixtures POST failed, falling back to per-row upsert:', e)
        sent = 0
        for row in payload:
            try:
                post_json(endpoint, key, [row], dry_run=dry_run, params=params)
                sent += 1
            except Exception:
                # Attempt to find existing fixture
                q = f"?division_id=eq.{quote(division_id)}&home_team=eq.{quote(row['home_team'])}&away_team=eq.{quote(row['away_team'])}&round_num=eq.{quote(row['round_num'])}&select=id"
                existing = get_json(base + '/rest/v1/fixtures', key, params=q)
                if existing:
                    existing_id = existing[0].get('id')
                    print('Patching existing fixture id', existing_id)
                    if not dry_run:
                        patch_url = base + f"/rest/v1/fixtures?id=eq.{existing_id}"
                        headers = {
                            'apikey': key,
                            'Authorization': f'Bearer {key}',
                            'Content-Type': 'application/json'
                        }
                        resp = requests.patch(patch_url, json=row, headers=headers, timeout=30)
                        try:
                            resp.raise_for_status()
                        except Exception:
                            print('PATCH failed for fixture:', resp.status_code, resp.text[:1000])
                            raise
                    sent += 1
                else:
                    print('Could not find existing fixture to patch for', row['home_team'], 'v', row['away_team'])
        return sent


def crawl_division_and_prepare(division_id, season):
    # Use the project's scraper
    sys.path.insert(0, ROOT)
    from rfu_parser.scraper import RFUParser
    p = RFUParser()
    comp_id = '1699'
    season_str = season.replace('/', '-').strip()
    url = f"https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season_str}&division={division_id}"
    res = p.fetch_and_parse(url, fallback_on_fail=False)
    d = res.to_dict()
    # attach rfu ids
    d['rfu_division_id'] = int(division_id)
    d['rfu_competition_id'] = int(comp_id)
    return d


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--file', help='JSON file path (scraper output)')
    parser.add_argument('--division', help='RFU division id to crawl')
    parser.add_argument('--season', help='Season string for crawling (e.g. 2026-2027)')
    parser.add_argument('--upsert-standings', action='store_true')
    parser.add_argument('--upsert-fixtures', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    base, key = get_supabase_client(env)

    # Prepare data
    if args.file:
        if not os.path.exists(args.file):
            print('File not found:', args.file)
            sys.exit(1)
        with open(args.file, 'r', encoding='utf-8') as f:
            data = json.load(f)
    elif args.division and args.season:
        print('Crawling live division...')
        data = crawl_division_and_prepare(args.division, args.season)
    else:
        print('Either --file or both --division and --season are required')
        sys.exit(1)

    # Upsert division
    division_id = upsert_division(base, key, data, dry_run=args.dry_run)
    if not division_id:
        print('Aborting: cannot determine division_id')
        sys.exit(1)

    # Upsert standings
    standings_count = 0
    if args.upsert_standings:
        standings_count = upsert_standings(base, key, division_id, data.get('standings', []), dry_run=args.dry_run)

    # Upsert fixtures
    fixtures_count = 0
    if args.upsert_fixtures:
        fixtures_count = upsert_fixtures(base, key, division_id, data.get('fixtures', []), dry_run=args.dry_run)

    print('\nSummary:')
    print('Division upserted id:', division_id)
    print('Standings rows upserted:', standings_count)
    print('Fixtures rows upserted:', fixtures_count)


if __name__ == '__main__':
    main()
