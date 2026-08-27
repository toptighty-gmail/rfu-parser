import os
import json
import uuid
import re
from datetime import datetime
from typing import List, Dict, Any, Optional
from rfu_parser.models import Fixture

import tempfile

PRIMARY_STORAGE_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "custom_fixtures.json")
FALLBACK_STORAGE_FILE = os.path.join(tempfile.gettempdir(), "rfu_custom_fixtures.json")

def _normalize_team_name(name: str) -> str:
    if not name:
        return ""
    clean = name.lower()
    # Strip common noise words for core comparison
    for word in ["rfc", "rugby", "football", "club", "1st", "xv"]:
        clean = re.sub(r'\b' + word + r'\b', '', clean)
    return " ".join(clean.split())

class CustomFixtureStorage:
    @staticmethod
    def _read_raw() -> List[Dict[str, Any]]:
        # Prefer fallback file if present and readable, otherwise check primary file
        for path in [FALLBACK_STORAGE_FILE, PRIMARY_STORAGE_FILE]:
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        if isinstance(data, list):
                            return data
                except Exception as ex:
                    print(f"Error reading from {path}: {ex}")
        return []

    @staticmethod
    def _write_raw(fixtures: List[Dict[str, Any]]) -> None:
        # Write to BOTH primary and fallback files simultaneously to guarantee full sync
        written = False
        try:
            with open(PRIMARY_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(fixtures, f, indent=2, ensure_ascii=False)
            written = True
        except Exception as e:
            print("Primary storage write failed:", e)

        try:
            with open(FALLBACK_STORAGE_FILE, "w", encoding="utf-8") as f:
                json.dump(fixtures, f, indent=2, ensure_ascii=False)
            written = True
        except Exception as e:
            print("Fallback storage write failed:", e)

        if not written:
            print("CRITICAL: Failed to write custom fixtures to any storage location!")

    @classmethod
    def get_all(cls) -> List[Dict[str, Any]]:
        return cls._read_raw()

    @classmethod
    def add_fixture(
        cls,
        date_str: str,
        home_team: str,
        away_team: str,
        season: str,
        time_str: str = "15:00",
        home_score: Optional[int] = None,
        away_score: Optional[int] = None,
        status: str = "Scheduled",
        venue: str = "Friendly Match",
        competition: str = "Friendly"
    ) -> Dict[str, Any]:
        raw = cls._read_raw()
        
        # Parse date to standardize format if possible (e.g. YYYY-MM-DD to "Saturday, 15 Oct 2025")
        raw_date = date_str.strip()
        formatted_date = raw_date
        date_iso = raw_date
        try:
            dt = datetime.strptime(raw_date, "%Y-%m-%d")
            formatted_date = dt.strftime("%A, %d %b %Y")
        except ValueError:
            pass

        fixture_id = str(uuid.uuid4())
        item = {
            "id": fixture_id,
            "date": formatted_date,
            "date_iso": date_iso,
            "time": time_str.strip() or "15:00",
            "home_team": home_team.strip(),
            "away_team": away_team.strip(),
            "home_score": home_score,
            "away_score": away_score,
            "status": status.strip() if status else ("Completed" if home_score is not None and away_score is not None else "Scheduled"),
            "venue": venue.strip() or "Friendly Match",
            "competition": competition.strip() or "Friendly",
            "round_num": "Friendly",
            "season": season.strip().replace("/", "-"),
            "is_custom": True
        }
        raw.append(item)
        cls._write_raw(raw)
        return item

    @classmethod
    def update_fixture(cls, fixture_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        raw = cls._read_raw()
        updated_item = None
        for item in raw:
            if item.get("id") == fixture_id:
                if "home_team" in updates:
                    item["home_team"] = updates["home_team"].strip()
                if "away_team" in updates:
                    item["away_team"] = updates["away_team"].strip()
                if "date" in updates:
                    d_str = updates["date"].strip()
                    item["date_iso"] = d_str
                    try:
                        dt = datetime.strptime(d_str, "%Y-%m-%d")
                        d_str = dt.strftime("%A, %d %b %Y")
                    except ValueError:
                        pass
                    item["date"] = d_str
                if "time" in updates:
                    item["time"] = updates["time"].strip()
                if "home_score" in updates:
                    val = updates["home_score"]
                    item["home_score"] = int(val) if val is not None and str(val).isdigit() else None
                if "away_score" in updates:
                    val = updates["away_score"]
                    item["away_score"] = int(val) if val is not None and str(val).isdigit() else None
                if "status" in updates:
                    item["status"] = updates["status"]
                elif item.get("home_score") is not None and item.get("away_score") is not None:
                    item["status"] = "Completed"
                if "venue" in updates:
                    item["venue"] = updates["venue"].strip()
                if "season" in updates:
                    item["season"] = updates["season"].strip().replace("/", "-")
                updated_item = item
                break

        if updated_item:
            cls._write_raw(raw)
        return updated_item

    @classmethod
    def delete_fixture(cls, fixture_id: str) -> bool:
        raw = cls._read_raw()
        initial_len = len(raw)
        filtered = [item for item in raw if item.get("id") != fixture_id]
        if len(filtered) < initial_len:
            cls._write_raw(filtered)
            return True
        return False

    @classmethod
    def get_fixtures_for_season_and_team(cls, season: str, team: Optional[str] = None) -> List[Fixture]:
        raw = cls._read_raw()
        clean_season = season.strip().replace("/", "-")
        matched = []
        target_norm = _normalize_team_name(team) if team else ""

        for item in raw:
            item_season = item.get("season", "").strip().replace("/", "-")
            # Season match (exact or partial year overlap)
            if clean_season in item_season or item_season in clean_season:
                if target_norm:
                    home_norm = _normalize_team_name(item.get("home_team", ""))
                    away_norm = _normalize_team_name(item.get("away_team", ""))
                    
                    # Match if target team is home or away team (exact normalized match or full token overlap)
                    home_match = (target_norm == home_norm) or (target_norm in home_norm) or (home_norm in target_norm)
                    away_match = (target_norm == away_norm) or (target_norm in away_norm) or (away_norm in target_norm)
                    
                    # Extra check for team numbers (e.g. "II" or "2nd") to avoid leaking main team to II team or vice versa
                    if " ii" in target_norm and " ii" not in home_norm and " ii" not in away_norm:
                        home_match = away_match = False
                    elif " ii" not in target_norm and (" ii" in home_norm or " ii" in away_norm):
                        if home_match and " ii" in home_norm and " ii" not in target_norm:
                            home_match = False
                        if away_match and " ii" in away_norm and " ii" not in target_norm:
                            away_match = False

                    if not (home_match or away_match):
                        continue

                fix = Fixture(
                    date=item.get("date", ""),
                    date_iso=item.get("date_iso", item.get("date", "")),
                    time=item.get("time", "15:00"),
                    home_team=item.get("home_team", ""),
                    away_team=item.get("away_team", ""),
                    home_score=item.get("home_score"),
                    away_score=item.get("away_score"),
                    status=item.get("status", "Scheduled"),
                    venue=item.get("venue", "Friendly"),
                    competition=item.get("competition", "Friendly"),
                    round_num=item.get("round_num", "Friendly")
                )
                setattr(fix, "id", item.get("id"))
                setattr(fix, "is_custom", True)
                setattr(fix, "date_iso", item.get("date_iso", item.get("date", "")))
                matched.append(fix)
        return matched
