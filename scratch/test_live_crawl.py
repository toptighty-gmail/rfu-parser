from rfu_parser.scraper import RFUParser

parser = RFUParser()

print("--- Testing Team Crawl: Exeter Chiefs ---")
res = parser.crawl_team_season("Exeter Chiefs", "2025-2026")
if res:
    print(f"Success! Division: {res.division_name}, Standings: {len(res.standings)}, Fixtures: {len(res.fixtures)}")
else:
    print("Crawl failed for Exeter Chiefs")

print("\n--- Testing Team Crawl: Tribute ---")
res2 = parser.crawl_team_season("Topsham", "2025-2026")
if res2:
    print(f"Success! Division: {res2.division_name}, Standings: {len(res2.standings)}, Fixtures: {len(res2.fixtures)}")
else:
    print("Crawl failed for Topsham")
