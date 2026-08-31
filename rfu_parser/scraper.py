import os
import re
import requests
from urllib.parse import quote
from datetime import datetime
from bs4 import BeautifulSoup
from typing import List, Optional, Union
from rfu_parser.models import LeagueTable, LeagueTableEntry, Fixture, RFUDataResult

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
)


def _team_suffix_signature(name: str) -> tuple:
    """Which numeral/qualifier suffix a (lowercased) team name carries.

    Mirrors FixtureList.isExactTeamMatch's suffix guard on the Dart side, so a
    club's 1st team is never confused with its II/III/IV/Colts sides - those
    are different teams playing in different divisions.
    """
    n = name.strip().lower()
    has_ii = bool(re.search(r"\b(ii|2nd|extra)\b", n))
    has_iii = bool(re.search(r"\b(iii|3rd)\b", n))
    has_iv = bool(re.search(r"\b(iv|4th)\b", n))
    has_colts = bool(re.search(r"\bcolts\b", n))
    return (has_ii, has_iii, has_iv, has_colts)

class RFUParser:
    def __init__(self, user_agent: str = DEFAULT_USER_AGENT):
        self.headers = {
            "User-Agent": user_agent,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Ch-Ua": "\"Chromium\";v=\"122\", \"Not(A:Brand\";v=\"24\", \"Google Chrome\";v=\"122\"",
            "Sec-Ch-Ua-Mobile": "?0",
            "Sec-Ch-Ua-Platform": "\"Windows\"",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1"
        }

    def fetch_url(self, url: str, timeout: int = 15) -> str:
        """Fetch raw HTML from a URL with custom user-agent."""
        import cloudscraper
        scraper = cloudscraper.create_scraper()
        response = scraper.get(url, timeout=timeout)
        response.raise_for_status()
        return response.text

    def crawl_team_season(self, team_name: str, season: str) -> Optional[RFUDataResult]:
        """Crawl the RFU website to dynamically resolve a team's division ID and fetch its full season table & fixtures."""
        if not team_name or not season:
            return None

        formatted_season = season.replace("/", "-").strip()
        t_clean = team_name.strip().lower()

        # 0. Check pre-resolved Direct Division URL Mappings first (bypasses WAF & fast 0.3s response)
        from rfu_parser.teams_db import TEAM_DIRECT_URLS
        if t_clean in TEAM_DIRECT_URLS:
            url_template = TEAM_DIRECT_URLS[t_clean]
            direct_url = url_template.format(season=formatted_season)
            try:
                res = self.fetch_and_parse(direct_url, fallback_on_fail=False)
                if res and res.standings:
                    return res
            except Exception as e:
                print("Direct URL fetch failed, trying live search API:", e)

        # 1. Resolve Team Name to Team ID via live search API
        search_url = f"https://www.englandrugby.com/api/fixtures-and-result/search?name={quote(team_name)}"
        try:
            r = requests.get(search_url, headers=self.headers, timeout=10)
            if r.status_code != 200:
                print("CRAWLER ERROR (step 1 - resolve status):", r.status_code)
                return None
            data = r.json()
            teams_list = data.get("data", [])
            if not teams_list:
                return None
            
            # Match exact team variation if possible. Never fall back to an
            # arbitrary result (e.g. teams_list[0]) - a club's "II"/"2nd"/Colts
            # side is a different team with a different division, so silently
            # picking the wrong one would present that team's entire division
            # as if it belonged to the searched team.
            target_clean = team_name.strip().lower()
            selected_team = None
            for t in teams_list:
                if t.get("name", "").strip().lower() == target_clean:
                    selected_team = t
                    break
            if selected_team is None:
                target_sig = _team_suffix_signature(target_clean)
                for t in teams_list:
                    name = t.get("name", "").strip().lower()
                    if _team_suffix_signature(name) == target_sig and (
                        target_clean in name or name in target_clean
                    ):
                        selected_team = t
                        break
            if selected_team is None:
                print(
                    "CRAWLER ERROR (step 1 - no safe match for '%s' among %s)"
                    % (team_name, [t.get("name") for t in teams_list])
                )
                return None
            team_id = selected_team.get("_id")
        except Exception as e:
            print("CRAWLER ERROR (step 1 - resolve exception):", e)
            return None

        # Format season (e.g. 2025/2026 -> 2025-2026)
        formatted_season = season.replace("/", "-").strip()

        # 2. Query team matches for that season to extract the division ID
        team_season_url = f"https://www.englandrugby.com/fixtures-and-results/search-results?team={team_id}&season={formatted_season}"
        try:
            html_content = self.fetch_url(team_season_url)
            soup = BeautifulSoup(html_content, "html.parser")
            
            # Find any division links
            division_links = soup.find_all("a", href=re.compile(r"division=\d+"))
            if not division_links:
                print("CRAWLER ERROR (step 2 - division links): No links found for team", team_name)
                return None
            
            # Count occurrences of each unique division URL to find the main league
            from collections import Counter
            href_counts = Counter(link.get("href") for link in division_links if link.get("href"))
            if not href_counts:
                return None
            
            # Select the href that appears most frequently (main league division)
            best_href, _ = href_counts.most_common(1)[0]
            
            # Extract division parameters from the best link
            comp_match = re.search(r"competition=(\d+)", best_href)
            div_match = re.search(r"division=(\d+)", best_href)
            
            comp_id = comp_match.group(1) if comp_match else "1699"
            div_id = div_match.group(1) if div_match else None
            
            if not div_id:
                return None
        except Exception as e:
            print("CRAWLER ERROR (step 2 - extract):", e)
            return None

        # 3. Fetch and parse the full division data
        try:
            division_url = f"https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={formatted_season}&division={div_id}"
            return self.fetch_and_parse(division_url, fallback_on_fail=False)
        except Exception as e:
            print("CRAWLER ERROR (step 3 - fetch division):", e)
            return None

    def parse_table(self, html_content: str) -> LeagueTable:
        """Parse RFU league standings from HTML content using BeautifulSoup."""
        soup = BeautifulSoup(html_content, "html.parser")

        div_title_elem = soup.find(class_=re.compile(r"league-name|division-title|league-title|page-title"))
        division_name = div_title_elem.get_text(strip=True) if div_title_elem else "Counties 1 Tribute Ale Western West"

        season_elem = soup.find(class_=re.compile(r"c029-number-card-division-heading|season-info|season"))
        season = season_elem.get_text(strip=True) if season_elem else "2025/2026 Season"
        if season and ("All filters" in season or "Season" in season):
            clean_elem = soup.find(class_="c029-number-card-division-heading")
            if clean_elem:
                season = clean_elem.get_text(strip=True)
            else:
                match = re.search(r"\d{4}-\d{4}", season)
                if match:
                    season = match.group(0)

        entries: List[LeagueTableEntry] = []

        table = soup.find("table")
        if table:
            rows = table.find_all("tr")
            for row in rows:
                cols = row.find_all(["td", "th"])
                if not cols or cols[0].name == "th":
                    continue

                cell_texts = [col.get_text(strip=True) for col in cols]
                if len(cell_texts) < 7:
                    continue

                try:
                    def clean_int(val: str, default: int = 0) -> int:
                        cleaned = re.sub(r"[^\d-]", "", val)
                        return int(cleaned) if cleaned else default

                    pos = clean_int(cell_texts[0], len(entries) + 1)
                    team_name = cell_texts[1]
                    
                    # Extract logo URL from the img tag or resolve via official RFU Club ID CDN
                    logo_url = ""
                    if len(cols) > 1:
                        img_tag = cols[1].find("img")
                        if img_tag and img_tag.has_attr("src"):
                            logo_url = img_tag["src"]
                            if logo_url.startswith("/"):
                                logo_url = "https://www.englandrugby.com" + logo_url

                    if not logo_url:
                        logo_url = self.resolve_club_logo(team_name)

                    played = clean_int(cell_texts[2])
                    won = clean_int(cell_texts[3])
                    drawn = clean_int(cell_texts[4])
                    lost = clean_int(cell_texts[5])

                    pf = clean_int(cell_texts[6]) if len(cell_texts) > 6 else 0
                    pa = clean_int(cell_texts[7]) if len(cell_texts) > 7 else 0
                    pd = clean_int(cell_texts[8]) if len(cell_texts) > 8 else (pf - pa)

                    tb = clean_int(cell_texts[9]) if len(cell_texts) > 9 else 0
                    lb = clean_int(cell_texts[10]) if len(cell_texts) > 10 else 0
                    pts = clean_int(cell_texts[11]) if len(cell_texts) > 11 else (won * 4 + drawn * 2 + tb + lb)
                    form = cell_texts[12] if len(cell_texts) > 12 else ""

                    entry = LeagueTableEntry(
                        position=pos,
                        team_name=team_name,
                        played=played,
                        won=won,
                        drawn=drawn,
                        lost=lost,
                        points_for=pf,
                        points_against=pa,
                        points_diff=pd,
                        try_bonus=tb,
                        lose_bonus=lb,
                        points=pts,
                        form=form,
                        logo_url=logo_url
                    )
                    entries.append(entry)
                except Exception:
                    continue

        return LeagueTable(division_name=division_name, season=season, entries=entries)

    def resolve_club_logo(self, team_name: str) -> str:
        """Resolve official RFU club logo CDN URL based on club ID."""
        if not team_name:
            return ""
        clean = team_name.strip().lower()
        
        # Check pre-resolved teams DB first
        try:
            from rfu_parser.teams_db import RFU_TEAMS_DB
            for t in RFU_TEAMS_DB:
                if clean in t.get("name", "").lower() or t.get("name", "").lower() in clean:
                    club_id = t.get("_id")
                    if club_id:
                        return f"https://images.englandrugby.com/club_images/{club_id}.png"
        except Exception:
            pass

        # Live RFU API search
        try:
            search_term = re.sub(r'\b(II|III|RFC|Club|XV)\b', '', team_name, flags=re.IGNORECASE).strip() or team_name
            url = f"https://www.englandrugby.com/api/fixtures-and-result/search?name={quote(search_term)}"
            r = requests.get(url, headers=self.headers, timeout=3)
            if r.status_code == 200:
                data = r.json().get("data", [])
                if data:
                    club_id = data[0].get("_id")
                    if club_id:
                        return f"https://images.englandrugby.com/club_images/{club_id}.png"
        except Exception:
            pass
        return ""

    def parse_fixtures(self, html_content: str) -> List[Fixture]:
        """Parse RFU match fixtures and results from HTML content."""
        soup = BeautifulSoup(html_content, "html.parser")
        fixtures: List[Fixture] = []

        # Try to parse live England Rugby portal structure first
        wrappers = soup.find_all(class_='resultWrapper')
        if wrappers:
            temp_fixtures = []
            for wrapper in wrappers:
                date_tag = wrapper.find(class_='coh-style-card-left-date')
                if not date_tag:
                    continue
                date_str = date_tag.get_text(strip=True)

                # Try to parse date string for round sorting
                try:
                    clean_date_str = date_str.split(',', 1)[-1].strip()
                    dt = datetime.strptime(clean_date_str, "%d %b %Y")
                except Exception:
                    dt = datetime.min

                cards = wrapper.find_all(class_='coh-style-card-scores')
                for card in cards:
                    home_tag = card.find(class_='coh-style-hometeam')
                    away_tag = card.find(class_='coh-style-away-team')
                    if not home_tag or not away_tag:
                        continue

                    home_a = home_tag.find('a')
                    home_team = home_a.get_text(strip=True) if home_a else home_tag.get_text(strip=True)
                    
                    away_a = away_tag.find('a')
                    away_team = away_a.get_text(strip=True) if away_a else away_tag.get_text(strip=True)

                    home_score = None
                    away_score = None
                    status = "Scheduled"

                    score_div = card.find(class_='fnr-scores')
                    if score_div:
                        score_tags = score_div.find_all('a')
                        if len(score_tags) >= 2:
                            try:
                                home_score = int(score_tags[0].get_text(strip=True))
                                away_score = int(score_tags[1].get_text(strip=True))
                                status = "Completed"
                            except ValueError:
                                pass

                    venue_tag = card.find(class_='coh-style-verticle-left')
                    venue = venue_tag.get_text(strip=True) if venue_tag else ""

                    # Extract kickoff time (e.g. 14:00, 14:15, 14:30, 15:00, 16:00, 17:30, 19:45)
                    card_text = card.get_text()
                    time_match = re.search(r'\b([012]?\d:[0-5]\d)\b', card_text)
                    ko_time = time_match.group(1) if time_match else "15:00"

                    temp_fixtures.append({
                        'date_dt': dt,
                        'date': date_str,
                        'time': ko_time,
                        'home_team': home_team,
                        'away_team': away_team,
                        'home_score': home_score,
                        'away_score': away_score,
                        'status': status,
                        'venue': venue
                    })

            # Sort chronologically by date
            temp_fixtures.sort(key=lambda x: x['date_dt'])

            # Assign round numbers dynamically
            unique_dates = sorted(list(set(f['date_dt'] for f in temp_fixtures)))
            rounds = []
            current_round_dates = []
            for d in unique_dates:
                if not current_round_dates:
                    current_round_dates.append(d)
                else:
                    if (d - current_round_dates[0]).days <= 3:
                        current_round_dates.append(d)
                    else:
                        rounds.append(list(current_round_dates))
                        current_round_dates = [d]
            if current_round_dates:
                rounds.append(list(current_round_dates))

            date_to_round = {}
            for round_idx, round_dates in enumerate(rounds, start=1):
                for rd in round_dates:
                    date_to_round[rd] = round_idx

            for f_dict in temp_fixtures:
                round_num = date_to_round.get(f_dict['date_dt'], 1)
                fixtures.append(Fixture(
                    date=f_dict['date'],
                    time=f_dict['time'],
                    home_team=f_dict['home_team'],
                    away_team=f_dict['away_team'],
                    home_score=f_dict['home_score'],
                    away_score=f_dict['away_score'],
                    status=f_dict['status'],
                    venue=f_dict['venue'],
                    round_num=f"Round {round_num}"
                ))

        # Fallback to legacy parser for tests/snapshots
        if not fixtures:
            cards = soup.find_all(class_=re.compile(r"fixture-card|match-item|fixture-row"))
            for card in cards:
                date_elem = card.find(class_=re.compile(r"match-date|date"))
                time_elem = card.find(class_=re.compile(r"match-time|time"))
                home_elem = card.find(class_=re.compile(r"home-team|team-home"))
                away_elem = card.find(class_=re.compile(r"away-team|team-away"))
                score_elem = card.find(class_=re.compile(r"score|result"))
                venue_elem = card.find(class_=re.compile(r"venue|location"))
                status_elem = card.find(class_=re.compile(r"status"))

                date_str = date_elem.get_text(strip=True) if date_elem else ""
                time_str = time_elem.get_text(strip=True) if time_elem else ""
                home_team = home_elem.get_text(strip=True) if home_elem else "TBD"
                away_team = away_elem.get_text(strip=True) if away_elem else "TBD"
                venue = venue_elem.get_text(strip=True) if venue_elem else ""
                status = status_elem.get_text(strip=True) if status_elem else "Scheduled"
                round_num = card.get("data-round", "")

                home_score = None
                away_score = None

                if score_elem:
                    score_text = score_elem.get_text(strip=True)
                    match = re.search(r"(\d+)\s*-\s*(\d+)", score_text)
                    if match:
                        home_score = int(match.group(1))
                        away_score = int(match.group(2))
                        status = "Completed"

                fixtures.append(Fixture(
                    date=date_str,
                    time=time_str,
                    home_team=home_team,
                    away_team=away_team,
                    home_score=home_score,
                    away_score=away_score,
                    status=status,
                    venue=venue,
                    round_num=str(round_num)
                ))

        return fixtures

    def load_all_sample_divisions(self, sample_dir: Optional[str] = None) -> List[RFUDataResult]:
        """Load all sample RFU divisions available in sample_data directory."""
        if not sample_dir:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            sample_dir = os.path.join(base_dir, "tests", "sample_data")

        results: List[RFUDataResult] = []

        files = [
            "counties_1_western_west_2526.html",
            "counties_2_devon.html",
            "sample_table.html",
            "gallagher_premiership.html"
        ]

        for fname in files:
            fpath = os.path.join(sample_dir, fname)
            if os.path.exists(fpath):
                with open(fpath, "r", encoding="utf-8") as f:
                    content = f.read()

                t_data = self.parse_table(content)
                f_data = self.parse_fixtures(content)
                if not f_data and fname == "sample_table.html":
                    fix_path = os.path.join(sample_dir, "sample_fixtures.html")
                    if os.path.exists(fix_path):
                        with open(fix_path, "r", encoding="utf-8") as ff:
                            f_data = self.parse_fixtures(ff.read())

                # Compute form dynamically from fixtures
                self.compute_form_for_teams(t_data.entries, f_data)

                res = RFUDataResult(
                    division_name=t_data.division_name,
                    season=t_data.season,
                    standings=t_data.entries,
                    fixtures=f_data
                )
                results.append(res)

        return results

    def generate_division_data(self, division_name: str, season: str) -> RFUDataResult:
        div_clean = division_name.strip()
        dq = div_clean.lower()

        if "premiership" in dq or "championship" in dq:
            teams = [
                "Bath Rugby", "Leicester Tigers", "Northampton Saints", "Saracens",
                "Harlequins", "Sale Sharks", "Exeter Chiefs", "Bristol Bears",
                "Gloucester Rugby", "Newcastle Falcons", "Ealing Trailfinders", "Coventry"
            ]
        elif "national" in dq:
            teams = [
                "Plymouth Albion", "Rams RFC", "Rosslyn Park", "Blackheath",
                "Bishop's Stortford", "Birmingham Moseley", "Sale FC", "Cinderford",
                "Leicester Lions", "Sedgley Park", "Dings Crusaders", "Esher"
            ]
        elif "regional 2" in dq:
            teams = [
                "Topsham", "Crediton", "Cullompton", "Burnham-on-Sea",
                "Wellington", "Bridgwater & Albion", "Chard", "Sidmouth",
                "Teignmouth", "Newton Abbot", "North Petherton", "Winscombe"
            ]
        elif "regional 1" in dq or "regional" in dq:
            teams = [
                "Devonport Services", "Camborne", "Redruth", "Exmouth",
                "Barnstaple", "Ivybridge", "Brixham", "Chew Valley",
                "Lydney", "Matson", "St Austell", "Old Redcliffians"
            ]
        elif "counties 2" in dq:
            teams = [
                "Topsham II", "Newton Abbot II", "Torquay Athletic", "Honiton",
                "Withycombe", "Tiverton", "South Molton", "Exeter Athletic",
                "Tavistock II", "Devonport Services II", "Plymstock Oaks II", "Barnstaple II"
            ]
        else:
            teams = [
                "Plymstock Oaks", "Topsham", "Newton Abbot", "Cullompton",
                "Crediton", "Okehampton", "Sidmouth", "Teignmouth",
                "Truro", "Wadebridge Camels", "Tavistock", "Paignton"
            ]

        import random
        seed = sum(ord(c) for c in div_clean)
        rnd = random.Random(seed)
        shuffled_teams = list(teams)
        rnd.shuffle(shuffled_teams)

        is_current_season = ("2027" in season or "2026-2027" in season or "2026/2027" in season)
        played_count = 14 if is_current_season else 22

        entries = []
        for idx, tname in enumerate(shuffled_teams, start=1):
            won = max(0, played_count - idx + rnd.randint(-1, 1))
            lost = max(0, played_count - won - rnd.randint(0, 1))
            drawn = max(0, played_count - won - lost)
            pf = won * 28 + rnd.randint(50, 150)
            pa = lost * 24 + rnd.randint(40, 120)
            pd = pf - pa
            tb = won + rnd.randint(1, 4)
            lb = lost // 2 + rnd.randint(0, 2)
            pts = (won * 4) + (drawn * 2) + tb + lb

            entries.append(LeagueTableEntry(
                position=idx,
                team_name=tname,
                played=played_count,
                won=won,
                drawn=drawn,
                lost=lost,
                points_for=pf,
                points_against=pa,
                points_diff=pd,
                try_bonus=tb,
                lose_bonus=lb,
                points=pts,
                form="WWLDW" if won > lost else "LLWLD"
            ))

        entries.sort(key=lambda x: (x.points, x.points_diff), reverse=True)
        for idx, entry in enumerate(entries, start=1):
            entry.position = idx

        match = re.search(r'(\d{4})', season)
        start_year = int(match.group(1)) if match else 2026
        end_year = start_year + 1

        fixtures = []
        n = len(shuffled_teams)
        rotation = list(shuffled_teams)

        total_rounds = 22
        months_years_schedule = [
            ("Sep", start_year), ("Sep", start_year), ("Oct", start_year), ("Oct", start_year),
            ("Nov", start_year), ("Nov", start_year), ("Dec", start_year), ("Dec", start_year),
            ("Jan", end_year), ("Jan", end_year), ("Feb", end_year), ("Feb", end_year),
            ("Mar", end_year), ("Mar", end_year), ("Apr", end_year), ("Apr", end_year),
            ("Apr", end_year), ("May", end_year), ("May", end_year), ("May", end_year),
            ("May", end_year), ("Jun", end_year)
        ]

        for r in range(total_rounds):
            round_num = r + 1
            is_second_half = r >= 11
            month, yr = months_years_schedule[r % len(months_years_schedule)]
            day_num = 26 if r == 0 else (6 + (r * 7) % 22)
            date_str = f"Saturday, {day_num} {month} {yr}"

            is_past = not is_current_season or (round_num <= 2)

            for i in range(n // 2):
                t1 = rotation[i]
                t2 = rotation[n - 1 - i]

                home_team = t2 if is_second_half else t1
                away_team = t1 if is_second_half else t2

                h_score = (24 + (i + r) % 15) if is_past else None
                a_score = (17 + (i * 3 + r) % 12) if is_past else None
                status = "Completed" if is_past else "Scheduled"

                fixtures.append(Fixture(
                    date=date_str,
                    time="15:00",
                    home_team=home_team,
                    away_team=away_team,
                    home_score=h_score,
                    away_score=a_score,
                    status=status,
                    venue="",
                    round_num=f"Round {round_num}"
                ))

            rotation = [rotation[0]] + [rotation[-1]] + rotation[1:-1]

        return RFUDataResult(
            division_name=div_clean,
            season=season,
            standings=entries,
            fixtures=fixtures
        )

    def format_standings_for_season(self, standings: List[LeagueTableEntry], season_query: Optional[str]) -> List[LeagueTableEntry]:
        # Do not extrapolate real data. Just return the standings as they are.
        return standings

    def format_fixtures_for_season(self, fixtures: List[Fixture], season_query: Optional[str]) -> List[Fixture]:
        # Do not mangle dates or extrapolate fixtures. Just return the live fixtures.
        return fixtures

    def get_tier_key(self, name: str) -> str:
        name_clean = name.lower()
        for tier in [
            "regional 1", "regional 2",
            "counties 1", "counties 2", "counties 3",
            "national 1", "national 2",
            "premiership", "championship"
        ]:
            if tier in name_clean:
                return tier
        if "regional" in name_clean:
            return "regional"
        if "counties" in name_clean:
            return "counties"
        if "national" in name_clean:
            return "national"
        return name_clean

    def get_sample_data(
        self,
        sample_dir: Optional[str] = None,
        team_query: Optional[str] = None,
        season_query: Optional[str] = None,
        division_query: Optional[str] = None
    ) -> RFUDataResult:
        """Load and parse sample RFU data with season, team, and division routing."""
        all_divisions = self.load_all_sample_divisions(sample_dir)
        if not all_divisions:
            return RFUDataResult(division_name="Counties 1 Tribute Ale Western West", season="2025/2026 Season")

        candidates = all_divisions

        # 1. Filter by season if matches exist in sample files
        if season_query:
            sq = season_query.strip().lower().replace("/", "-")
            season_matches = [d for d in candidates if sq in d.season.lower().replace("/", "-")]
            if season_matches:
                candidates = season_matches

        # 2. Division query matching
        if division_query and division_query.strip() and division_query != "ALL / Select Division":
            dq = division_query.strip().lower()
            req_tier = self.get_tier_key(dq)

            # Exact or close match in pre-baked sample files
            for div in candidates:
                div_name_clean = div.division_name.lower()
                sample_tier = self.get_tier_key(div_name_clean)

                if req_tier == sample_tier:
                    return RFUDataResult(
                        division_name=division_query.strip(),
                        season=season_query or div.season,
                        standings=self.format_standings_for_season(div.standings, season_query),
                        fixtures=self.format_fixtures_for_season(div.fixtures, season_query),
                        source_url=div.source_url
                    )

            # Generate tier-specific data for requested division so standings and fixtures always match tier and season
            return self.generate_division_data(division_query.strip(), season_query or "2026-2027")

        # 3. Team query matching
        if team_query and team_query.strip():
            tokens = [t.lower() for t in team_query.strip().split() if len(t) > 1]
            if tokens:
                for div in candidates:
                    for entry in div.standings:
                        if all(token in entry.team_name.lower() for token in tokens):
                            return RFUDataResult(
                                division_name=div.division_name,
                                season=season_query or div.season,
                                standings=self.format_standings_for_season(div.standings, season_query),
                                fixtures=self.format_fixtures_for_season(div.fixtures, season_query),
                                source_url=div.source_url
                            )
                    for fix in div.fixtures:
                        if all(token in fix.home_team.lower() for token in tokens) or all(token in fix.away_team.lower() for token in tokens):
                            return RFUDataResult(
                                division_name=div.division_name,
                                season=season_query or div.season,
                                standings=self.format_standings_for_season(div.standings, season_query),
                                fixtures=self.format_fixtures_for_season(div.fixtures, season_query),
                                source_url=div.source_url
                            )

        # 4. Default fallback
        res = candidates[0]
        return RFUDataResult(
            division_name=res.division_name,
            season=season_query or res.season,
            standings=self.format_standings_for_season(res.standings, season_query),
            fixtures=self.format_fixtures_for_season(res.fixtures, season_query),
            source_url=res.source_url
        )

    def fetch_and_parse(self, url: str, fallback_on_fail: bool = True) -> RFUDataResult:
        """Fetch remote URL and parse standings & fixtures, fallback to sample data if fetch fails."""
        try:
            html_content = self.fetch_url(url)
            table_data = self.parse_table(html_content)
            fixtures_data = self.parse_fixtures(html_content)
            
            # Compute form dynamically from fixtures
            self.compute_form_for_teams(table_data.entries, fixtures_data)
            
            return RFUDataResult(
                division_name=table_data.division_name,
                season=table_data.season,
                standings=table_data.entries,
                fixtures=fixtures_data,
                source_url=url
            )
        except Exception as e:
            if not fallback_on_fail:
                raise e
            res = self.get_sample_data()
            res.source_url = url
            return res

    def compute_form_for_teams(self, standings: List[LeagueTableEntry], fixtures: List[Fixture]):
        """Compute recent match outcomes (W/D/L) for each team based on completed fixtures."""
        from collections import defaultdict
        
        # Group completed fixtures by team
        team_matches = defaultdict(list)
        for fix in fixtures:
            if fix.status == "Completed" and fix.home_score is not None and fix.away_score is not None:
                home = fix.home_team.strip().lower()
                away = fix.away_team.strip().lower()
                team_matches[home].append((fix, "home"))
                team_matches[away].append((fix, "away"))
                
        # Parse fixture dates to sort chronologically
        def parse_date(fix_tuple):
            fix = fix_tuple[0]
            try:
                # Remove weekday if present, e.g. "Saturday, 25 Apr 2026"
                d_str = fix.date.split(",")[-1].strip()
                return datetime.strptime(d_str, "%d %b %Y")
            except Exception:
                try:
                    # fallback to general parsing
                    return datetime.strptime(fix.date.strip(), "%d %b %Y")
                except Exception:
                    return datetime.min

        # Sort matches and build form string (up to latest 6 games)
        for entry in standings:
            team_key = entry.team_name.strip().lower()
            matches = team_matches.get(team_key, [])
            if not matches:
                # Try token matching as fallback in case names differ slightly
                tokens = [t for t in team_key.split() if len(t) > 1]
                if tokens:
                    for k, v in team_matches.items():
                        if all(tok in k for tok in tokens):
                            matches = v
                            break
            
            if matches:
                matches_sorted = sorted(matches, key=parse_date)
                last_matches = matches_sorted[-6:]
                
                form_chars = []
                for fix, side in last_matches:
                    h_score = fix.home_score
                    a_score = fix.away_score
                    if side == "home":
                        if h_score > a_score:
                            form_chars.append("W")
                        elif h_score < a_score:
                            form_chars.append("L")
                        else:
                            form_chars.append("D")
                    else:
                        if a_score > h_score:
                            form_chars.append("W")
                        elif a_score < h_score:
                            form_chars.append("L")
                        else:
                            form_chars.append("D")
                entry.form = "".join(form_chars)

    def fetch_live_rfu_web_data(self, division_name: Optional[str] = None, season: Optional[str] = None) -> RFUDataResult:
        """Crawl live RFU website directly from England Rugby servers for live standings and fixtures."""
        div_clean = (division_name or "").strip().lower()
        season_str = (season or "2026-2027").strip().replace("/", "-")

        # Map known division IDs on RFU site
        rfu_division_ids = {
            "counties 2": "75799",
            "counties 2 tribute ale devon": "75799",
            "counties 2 devon": "75799",
            "counties 1": "66453",
            "counties 1 tribute ale western west": "66453",
            "counties 1 western west": "66453",
            "regional 1": "66440",
            "regional 1 south east": "66440",
            "regional 2": "66445",
            "regional 2 tribute south west": "66445",
            "national 1": "66430",
            "premiership": "68225",
            "gallagher premiership": "68225"
        }

        div_id = None
        for key, id_val in rfu_division_ids.items():
            if key in div_clean:
                div_id = id_val
                break

        if not div_id:
            # Fallback map lookup by tier
            tier = self.get_tier_key(div_clean)
            div_id = rfu_division_ids.get(tier, "75799")

        comp_id = "1699"
        url = f"https://www.englandrugby.com/fixtures-and-results/search-results?competition={comp_id}&season={season_str}&division={div_id}"

        try:
            import cloudscraper
            scraper = cloudscraper.create_scraper()
            resp = scraper.get(
                url,
                timeout=15
            )
            if resp.status_code == 200:
                table_data = self.parse_table(resp.text)
                fixtures_data = self.parse_fixtures(resp.text)
                parsed = RFUDataResult(
                    division_name=division_name or "",
                    season=season_str,
                    standings=table_data.entries if table_data else [],
                    fixtures=fixtures_data,
                    source_url=url,
                    rfu_competition_id=int(comp_id) if comp_id and comp_id.isdigit() else None,
                    rfu_division_id=int(div_id) if div_id and div_id.isdigit() else None
                )
                if parsed and parsed.standings:
                    parsed.season = season_str
                    parsed.standings = self.format_standings_for_season(parsed.standings, season_str)
                    parsed.fixtures = self.format_fixtures_for_season(parsed.fixtures, season_str)
                    return parsed
        except Exception as e:
            print(f"Live crawling attempt for {url} failed: {e}.")
            raise Exception("Cloudflare blocked the request or the live RFU site is unreachable.")

        raise Exception("Failed to parse live RFU data.")

    def sync_result_to_supabase(self, result: RFUDataResult, supabase_url: str, supabase_key: str) -> bool:
        """Upsert live parsed division, standings, and fixtures into Supabase database tables."""
        if not supabase_url or not supabase_key or "your-supabase-project" in supabase_url:
            return False

        headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates"
        }

        base_endpoint = supabase_url.rstrip('/') + "/rest/v1"

        try:
            # 1. Upsert Division
            div_payload = {
                "division_name": result.division_name,
                "season": result.season,
                "source_url": result.source_url or ""
            }
            if result.rfu_competition_id is not None:
                div_payload["rfu_competition_id"] = result.rfu_competition_id
            if result.rfu_division_id is not None:
                div_payload["rfu_division_id"] = result.rfu_division_id
                
            requests.post(
                f"{base_endpoint}/divisions?on_conflict=division_name,season",
                json=[div_payload],
                headers=headers,
                timeout=10
            )

            # Fetch division_id
            div_resp = requests.get(
                f"{base_endpoint}/divisions?division_name=eq.{quote(result.division_name)}&season=eq.{quote(result.season)}&select=id",
                headers=headers,
                timeout=10
            )
            rows = div_resp.json() if div_resp.status_code == 200 else []
            division_id = rows[0].get("id") if rows else None

            if not division_id:
                return False

            # 2. Upsert Standings
            if result.standings:
                standings_payload = []
                for s in result.standings:
                    standings_payload.append({
                        "division_id": division_id,
                        "position": s.position,
                        "team_name": s.team_name,
                        "played": s.played,
                        "won": s.won,
                        "drawn": s.drawn,
                        "lost": s.lost,
                        "points_for": s.points_for,
                        "points_against": s.points_against,
                        "points_diff": s.points_diff,
                        "try_bonus": s.try_bonus,
                        "lose_bonus": s.lose_bonus,
                        "points": s.points,
                        "form": s.form or ""
                    })
                requests.post(
                    f"{base_endpoint}/standings?on_conflict=division_id,team_name",
                    json=standings_payload,
                    headers=headers,
                    timeout=10
                )

            # 3. Upsert Fixtures
            if result.fixtures:
                fixtures_payload = []
                for f in result.fixtures:
                    fixtures_payload.append({
                        "division_id": division_id,
                        "date": f.date,
                        "time": f.time or "15:00",
                        "home_team": f.home_team,
                        "away_team": f.away_team,
                        "home_score": f.home_score,
                        "away_score": f.away_score,
                        "status": f.status or "Scheduled",
                        "venue": f.venue or "",
                        "round_num": f.round_num or "",
                        "is_custom": f.is_custom
                    })
                requests.post(
                    f"{base_endpoint}/fixtures?on_conflict=division_id,home_team,away_team,round_num",
                    json=fixtures_payload,
                    headers=headers,
                    timeout=10
                )

            print(f"Successfully synced {result.division_name} ({result.season}) to Supabase DB.")
            return True
        except Exception as e:
            print(f"Error syncing {result.division_name} to Supabase: {e}")
            return False

