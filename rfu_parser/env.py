"""Credentials for maintenance scripts, read from the environment or the repo's
.env file (which is git-ignored). Keys must never be written into source files:
this repository is public.
"""
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_env_file(path=None):
    """Minimal .env loader; variables already set in the environment win."""
    path = path or os.path.join(REPO_ROOT, ".env")
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def supabase_secret_key():
    """The Supabase secret key (sb_secret_...), or the legacy service-role key."""
    load_env_file()
    key = os.environ.get("SUPABASE_SECRET_KEY") or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not key:
        raise SystemExit("Set SUPABASE_SECRET_KEY in .env (or the environment) to run this script.")
    return key
