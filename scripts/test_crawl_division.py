import json
import sys
import os
# Ensure project root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from rfu_parser.scraper import RFUParser

p = RFUParser()
url = "https://www.englandrugby.com/fixtures-and-results/search-results?competition=1699&season=2026-2027&division=75799"
try:
    res = p.fetch_and_parse(url, fallback_on_fail=False)
    print(json.dumps(res.to_dict(), indent=2))
except Exception as e:
    print("ERROR:", str(e))
    raise
