import os
from flask import Flask, render_template, request, jsonify, send_file, send_from_directory, session
from rfu_parser.scraper import RFUParser
from rfu_parser.exporter import DataExporter
from rfu_parser.storage import CustomFixtureStorage
from rfu_parser.logo_storage import CustomLogoStorage

import time

def safe_print(*args, **kwargs):
    try:
        print(*args, **kwargs)
    except Exception:
        pass
    try:
        with open("debug_log.txt", "a") as f:
            f.write(" ".join(map(str, args)) + "\n")
    except Exception:
        pass

class SimpleCache:
    def __init__(self, ttl_seconds=600):
        self.cache = {}
        self.ttl = ttl_seconds

    def get(self, key):
        if key in self.cache:
            val, expiry = self.cache[key]
            if time.time() < expiry:
                return val
            else:
                del self.cache[key]
        return None

    def set(self, key, value):
        self.cache[key] = (value, time.time() + self.ttl)

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "rfu-hub-secret-key-2026")
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "rugby2026")

rfu_parser = RFUParser()

suggestions_cache = SimpleCache(ttl_seconds=3600)  # 1 hour
crawl_cache = SimpleCache(ttl_seconds=600)        # 10 minutes

FLUTTER_WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

@app.route("/")
def index():
    if os.path.exists(os.path.join(FLUTTER_WEB_DIR, "index.html")):
        return send_from_directory(FLUTTER_WEB_DIR, "index.html")
    return render_template("index.html")

@app.route("/<path:path>")
def serve_flutter_static(path):
    if path.startswith("api/"):
        return jsonify({"error": "API route not found"}), 404
    full_path = os.path.join(FLUTTER_WEB_DIR, path)
    if os.path.exists(full_path) and os.path.isfile(full_path):
        return send_from_directory(FLUTTER_WEB_DIR, path)
    if os.path.exists(os.path.join(FLUTTER_WEB_DIR, "index.html")):
        return send_from_directory(FLUTTER_WEB_DIR, "index.html")
    return jsonify({"error": "Not found"}), 404
    url = request.args.get("url", "").strip()
    team = request.args.get("team", "").strip()
    season = request.args.get("season", "").strip()
    selected_div = request.args.get("division", "").strip()

    all_sample_divs = rfu_parser.load_all_sample_divisions()
    error_msg = None
    data = None

    if url:
        data = rfu_parser.fetch_and_parse(url)
    elif selected_div:
        data = rfu_parser.get_sample_data(division_query=selected_div)
    elif team:
        # Try live crawl for team and season (defaulting to 2025-2026 if not specified)
        cache_key = f"{team.lower()}_{season or '2025-2026'}"
        crawled_data = crawl_cache.get(cache_key)
        if not crawled_data:
            try:
                safe_print("Invoking crawl_team_season with:", team, "Season:", season or "2025-2026")
                crawled_data = rfu_parser.crawl_team_season(team, season or "2025-2026")
                safe_print("CRAWLED DATA RESULT:", crawled_data)
                if crawled_data:
                    crawl_cache.set(cache_key, crawled_data)
            except Exception as ex:
                safe_print("CRAWLED DATA EXCEPTION IN ROUTE:", ex)
                crawled_data = None
        if crawled_data:
            data = crawled_data
        else:
            # Check if the team exists in the local offline files
            sample_data = rfu_parser.get_sample_data(team_query=team, season_query=season)
            team_found = False
            if sample_data:
                tokens = [t.lower() for t in team.strip().split() if len(t) > 1]
                if tokens:
                    for entry in sample_data.standings:
                        if all(tok in entry.team_name.lower() for tok in tokens):
                            team_found = True
                            break
                    if not team_found:
                        for fix in sample_data.fixtures:
                            if all(tok in fix.home_team.lower() for tok in tokens) or all(tok in fix.away_team.lower() for tok in tokens):
                                team_found = True
                                break
            if team_found:
                data = sample_data
            else:
                data = None
                error_msg = f"Could not find or fetch data for team '{team}' for season {season or '2025-2026'}. The England Rugby portal may be blocked, or the team did not participate in this season."

    seasons_list = [
        "2026-2027",
        "2025-2026",
        "2024-2025",
        "2023-2024",
        "2022-2023",
        "2021-2022",
        "2019-2020",
        "2018-2019"
    ]

    # Merge custom fixtures for season (and team if specified)
    active_season = season or (data.season if data else "2025-2026")
    custom_fixtures = CustomFixtureStorage.get_fixtures_for_season_and_team(active_season, team)
    if data and custom_fixtures:
        existing_custom_ids = {getattr(f, "id", "") for f in data.fixtures if getattr(f, "id", "")}
        for cf in custom_fixtures:
            if getattr(cf, "id", "") not in existing_custom_ids:
                data.fixtures.append(cf)

    # Group fixtures chronologically by round / match date
    from collections import defaultdict
    from datetime import datetime
    import re

    def parse_fixture_dt(date_str):
        if not date_str:
            return datetime.min
        clean = date_str.split(',', 1)[-1].strip() if ',' in date_str else date_str.strip()
        for fmt in ("%d %b %Y", "%Y-%m-%d", "%d/%m/%Y", "%d %B %Y"):
            try:
                return datetime.strptime(clean, fmt)
            except ValueError:
                pass
        return datetime.min

    grouped = defaultdict(list)
    if data:
        for f in data.fixtures:
            if getattr(f, "is_custom", False):
                r_name = f"Friendly ({f.date})" if f.date else "Friendly Match"
            else:
                r_name = f.round_num if f.round_num else "Scheduled"
            grouped[r_name].append(f.to_dict())

    def round_key(item):
        group_fixtures = item[1]
        dates = [parse_fixture_dt(fix.get("date")) for fix in group_fixtures if fix.get("date")]
        min_dt = min(dates) if dates else datetime.min
        match = re.search(r'\d+', item[0])
        num_val = int(match.group()) if match else 0
        return (min_dt, num_val)

    grouped_fixtures = sorted(grouped.items(), key=round_key)

    spotlight_logo = CustomLogoStorage.get_logo_for_team(team) if team else None
    if not spotlight_logo and data and team:
        for entry in data.standings:
            if team.lower() in entry.team_name.lower() and entry.logo_url:
                spotlight_logo = entry.logo_url
                break

    return render_template(
        "index.html",
        data=data.to_dict() if data else None,
        grouped_fixtures=grouped_fixtures,
        divisions=[d.division_name for d in all_sample_divs],
        seasons=seasons_list,
        selected_division=selected_div,
        current_season=season or (data.season if data else "2025-2026"),
        current_url=url,
        current_team=team,
        spotlight_logo=spotlight_logo,
        get_logo_for_team=CustomLogoStorage.get_logo_for_team,
        is_admin=session.get("is_admin", False),
        error_msg=error_msg
    )

@app.route("/api/admin/login", methods=["POST"])
def admin_login():
    req = request.get_json(silent=True) or {}
    password = req.get("password", "")
    if password == ADMIN_PASSWORD:
        session["is_admin"] = True
        return jsonify({"success": True, "is_admin": True})
    return jsonify({"success": False, "error": "Invalid admin password"}), 401

@app.route("/api/admin/logout", methods=["POST"])
def admin_logout():
    session.pop("is_admin", None)
    return jsonify({"success": True, "is_admin": False})

@app.route("/api/admin/status", methods=["GET"])
def admin_status():
    return jsonify({"is_admin": bool(session.get("is_admin", False))})

# Logo Management API Routes
@app.route("/api/logos/<filename>", methods=["GET"])
def get_custom_logo_file(filename):
    filepath = CustomLogoStorage.get_logo_filepath(filename)
    if filepath and os.path.exists(filepath):
        return send_file(filepath)
    return jsonify({"error": "Logo file not found"}), 404

@app.route("/api/admin/logos", methods=["GET"])
def list_custom_logos():
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401
    return jsonify({"logos": CustomLogoStorage.get_all_logos()})

@app.route("/api/admin/logos/upload", methods=["POST"])
def upload_custom_logo():
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401

    team_name = request.form.get("team_name", "").strip()
    if not team_name:
        return jsonify({"error": "Team name is required"}), 400

    if "file" not in request.files:
        return jsonify({"error": "No file attached"}), 400

    file = request.files["file"]
    if not file or file.filename == "":
        return jsonify({"error": "No file selected"}), 400

    file_bytes = file.read()
    logo_url = CustomLogoStorage.save_logo(team_name, file_bytes, file.filename)
    if logo_url:
        return jsonify({"success": True, "logo_url": logo_url, "team_name": team_name})
    return jsonify({"error": "Failed to save logo file"}), 500

@app.route("/api/admin/logos/<path:team_name>", methods=["DELETE"])
def delete_custom_logo(team_name):
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401

    success = CustomLogoStorage.delete_logo(team_name)
    if success:
        return jsonify({"success": True})
    return jsonify({"error": "Logo not found"}), 404

@app.route("/api/fixtures/custom", methods=["POST"])
def add_custom_fixture():
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401
    
    data = request.get_json(silent=True) or {}
    date_str = data.get("date", "").strip()
    home_team = data.get("home_team", "").strip()
    away_team = data.get("away_team", "").strip()
    season = data.get("season", "2025-2026").strip()
    
    if not date_str or not home_team or not away_team:
        return jsonify({"error": "Date, Home Team, and Away Team are required."}), 400

    item = CustomFixtureStorage.add_fixture(
        date_str=date_str,
        home_team=home_team,
        away_team=away_team,
        season=season,
        time_str=data.get("time", "15:00"),
        home_score=data.get("home_score"),
        away_score=data.get("away_score"),
        status=data.get("status", "Scheduled"),
        venue=data.get("venue", "Friendly Match")
    )
    return jsonify({"success": True, "fixture": item})

@app.route("/api/fixtures/custom/<fixture_id>", methods=["PUT"])
def update_custom_fixture(fixture_id):
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401
    
    data = request.get_json(silent=True) or {}
    item = CustomFixtureStorage.update_fixture(fixture_id, data)
    if not item:
        return jsonify({"error": "Fixture not found"}), 404
    return jsonify({"success": True, "fixture": item})

@app.route("/api/fixtures/custom/<fixture_id>", methods=["DELETE"])
def delete_custom_fixture(fixture_id):
    if not session.get("is_admin"):
        return jsonify({"error": "Admin login required"}), 401
    
    ok = CustomFixtureStorage.delete_fixture(fixture_id)
    if not ok:
        return jsonify({"error": "Fixture not found"}), 404
    return jsonify({"success": True})

@app.route("/api/parse", methods=["GET"])
@app.route("/parse", methods=["GET"])
def api_parse():
    url = request.args.get("url", "").strip()
    team = request.args.get("team", "").strip()
    season = request.args.get("season", "2026-2027").strip()
    division = request.args.get("division", "").strip()

    data = None
    if url:
        data = rfu_parser.fetch_and_parse(url)
    elif team:
        cache_key = f"{team.lower()}_{season}"
        crawled = crawl_cache.get(cache_key)
        if not crawled:
            try:
                crawled = rfu_parser.crawl_team_season(team, season)
                if crawled:
                    crawl_cache.set(cache_key, crawled)
            except Exception as e:
                safe_print("Live crawl exception:", e)
                crawled = None
        data = crawled or rfu_parser.get_sample_data(team_query=team, season_query=season)
    elif division:
        data = rfu_parser.get_sample_data(division_query=division, season_query=season)
    else:
        data = rfu_parser.get_sample_data(season_query=season)

    return jsonify(data.to_dict() if data else {})

@app.route("/api/export/csv", methods=["GET"])
@app.route("/export/csv", methods=["GET"])
def api_export_csv():
    team = request.args.get("team", "").strip()
    season = request.args.get("season", "").strip()
    data = rfu_parser.get_sample_data(team_query=team, season_query=season)
    file_path = os.path.join(os.path.dirname(__file__), "rfu_standings.csv")
    DataExporter.to_csv_standings(data, file_path)
    return send_file(file_path, as_attachment=True, download_name="rfu_standings.csv")

from rfu_parser.teams_db import search_teams_fallback

@app.route("/api/suggest-teams")
@app.route("/suggest-teams")
def suggest_teams():
    q = request.args.get("q", "").strip().lower()
    if len(q) < 2:
        return jsonify({"status": "success", "data": []})

    cached_res = suggestions_cache.get(q)
    if cached_res:
        return jsonify(cached_res)

    import requests
    from urllib.parse import quote
    search_url = f"https://www.englandrugby.com/api/fixtures-and-result/search?name={quote(q)}"
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
    }
    items = []
    try:
        r = requests.get(search_url, headers=headers, timeout=4)
        if r.status_code == 200:
            res_data = r.json()
            items = res_data.get("data", [])
    except Exception as e:
        safe_print("Suggest teams error:", e)

    if items:
        items_sorted = sorted(items, key=lambda x: x.get("name", "").lower())
        res = {"status": "success", "data": items_sorted}
        suggestions_cache.set(q, res)
        return jsonify(res)

    # Instant fallback to local RFU teams DB
    fallback_items = search_teams_fallback(q)
    return jsonify({"status": "success", "data": fallback_items})


if __name__ == "__main__":
    safe_print("Starting RFU Parser Web App on http://127.0.0.1:5000")
    app.run(host="127.0.0.1", port=5000, debug=True, use_reloader=False)
