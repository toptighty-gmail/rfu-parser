import os
import json
import re
import tempfile
from typing import Dict, Optional

PRIMARY_LOGOS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static", "uploads", "logos")
FALLBACK_LOGOS_DIR = os.path.join(tempfile.gettempdir(), "rfu_uploads", "logos")

PRIMARY_MAP_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "custom_logos.json")
FALLBACK_MAP_FILE = os.path.join(tempfile.gettempdir(), "rfu_custom_logos.json")

def _ensure_dirs():
    for d in [PRIMARY_LOGOS_DIR, FALLBACK_LOGOS_DIR]:
        try:
            os.makedirs(d, exist_ok=True)
        except Exception as e:
            print(f"Directory creation failed for {d}: {e}")

_ensure_dirs()

def _normalize_key(team_name: str) -> str:
    clean = team_name.lower().strip()
    for word in ["rfc", "rugby", "football", "club"]:
        clean = re.sub(r'\b' + word + r'\b', '', clean)
    return " ".join(clean.split())

class CustomLogoStorage:
    @staticmethod
    def _read_map() -> Dict[str, str]:
        for path in [FALLBACK_MAP_FILE, PRIMARY_MAP_FILE]:
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                        if isinstance(data, dict):
                            return data
                except Exception as ex:
                    print(f"Error reading logo map {path}: {ex}")
        return {}

    @staticmethod
    def _write_map(mapping: Dict[str, str]) -> None:
        for path in [PRIMARY_MAP_FILE, FALLBACK_MAP_FILE]:
            try:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(mapping, f, indent=2, ensure_ascii=False)
            except Exception as e:
                print(f"Writing logo map to {path} failed: {e}")

    @classmethod
    def get_logo_for_team(cls, team_name: str) -> Optional[str]:
        if not team_name:
            return None
        mapping = cls._read_map()
        key = _normalize_key(team_name)
        if key in mapping:
            filename = mapping[key]
            if cls.get_logo_filepath(filename):
                return f"/api/logos/{filename}"
        return None

    @classmethod
    def get_all_logos(cls) -> Dict[str, str]:
        return cls._read_map()

    @classmethod
    def save_logo(cls, team_name: str, file_data: bytes, original_filename: str) -> Optional[str]:
        if not team_name or not file_data:
            return None

        ext = os.path.splitext(original_filename)[1].lower() or ".png"
        if ext not in [".png", ".jpg", ".jpeg", ".webp", ".svg", ".gif"]:
            ext = ".png"

        key = _normalize_key(team_name)
        safe_filename = f"{re.sub(r'[^a-z0-9_-]', '_', key)}{ext}"

        saved = False
        for d in [PRIMARY_LOGOS_DIR, FALLBACK_LOGOS_DIR]:
            try:
                os.makedirs(d, exist_ok=True)
                target_path = os.path.join(d, safe_filename)
                with open(target_path, "wb") as f:
                    f.write(file_data)
                saved = True
            except Exception as e:
                print(f"Saving logo file to {d} failed: {e}")

        if saved:
            mapping = cls._read_map()
            mapping[key] = safe_filename
            cls._write_map(mapping)
            return f"/api/logos/{safe_filename}"
        return None

    @classmethod
    def delete_logo(cls, team_name: str) -> bool:
        key = _normalize_key(team_name)
        mapping = cls._read_map()
        if key in mapping:
            filename = mapping.pop(key)
            cls._write_map(mapping)
            for d in [PRIMARY_LOGOS_DIR, FALLBACK_LOGOS_DIR]:
                file_path = os.path.join(d, filename)
                if os.path.exists(file_path):
                    try:
                        os.remove(file_path)
                    except Exception as e:
                        print(f"Removing logo file {file_path} failed: {e}")
            return True
        return False

    @classmethod
    def get_logo_filepath(cls, filename: str) -> Optional[str]:
        # Sanitize filename
        clean_name = os.path.basename(filename)
        for d in [FALLBACK_LOGOS_DIR, PRIMARY_LOGOS_DIR]:
            path = os.path.join(d, clean_name)
            if os.path.exists(path):
                return path
        return None
