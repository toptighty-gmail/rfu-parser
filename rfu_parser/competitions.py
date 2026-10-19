"""Discover RFU competitions and their divisions from englandrugby.com.

Competitions come from two places: the competition directory on the Fixtures &
Results page, and the site search API, which returns competitions with the
RFU's own label ("Senior League", "Senior Cup", "Womens League", "Youth",
"Colts", "School", "BUSA", ...) and an isElite flag. Each competition's page
(search-results?competition=X&season=S) then lists its divisions: league
divisions, merit tables, cup rounds, international series.

Only senior competitions are kept. Age-grade (youth, colts, schools, girls'
and boys' competitions) and university rugby are left out by design.
"""
import re
from dataclasses import dataclass
from typing import Dict, List, Optional

from bs4 import BeautifulSoup

SEARCH_API = "https://www.englandrugby.com/api/fixtures-and-result/search"
FIXTURES_PAGE = "https://www.englandrugby.com/fixtures-and-results"
COMPETITION_PAGE = "https://www.englandrugby.com/fixtures-and-results/search-results?competition={cid}&season={season}"

# Search terms that between them surface the RFU's senior competitions (the
# search API returns a limited number of matches per term, so counties are
# searched individually as well).
SEARCH_TERMS = [
    "league", "leagues", "merit", "merit table", "cup", "plate", "vase", "shield", "trophy", "bowl",
    "salver", "women", "championship", "division", "counties", "national", "premiership",
    "international", "six nations", "nations", "world cup", "pennant", "reserve", "district", "vets",
    "invitation", "combination", "social", "floodlit", "challenge", "community", "intermediate", "senior",
    "army", "navy", "raf", "services", "manx",
    "cornwall", "devon", "somerset", "gloucestershire", "dorset", "wilts", "hampshire", "sussex", "kent",
    "surrey", "essex", "hertfordshire", "middlesex", "berkshire", "bucks", "oxfordshire", "cambridgeshire",
    "norfolk", "suffolk", "eastern counties", "lincolnshire", "nottinghamshire", "derbyshire",
    "leicestershire", "warwickshire", "staffordshire", "north midlands", "east midlands", "cheshire",
    "lancashire", "cumbria", "yorkshire", "durham", "northumberland", "london", "midlands", "northern",
    "south west",
]

# Display groups, in the order the app shows them.
ELITE = "Elite"
INTERNATIONALS = "Internationals"
MENS_LEAGUES = "Men's Leagues"
MERIT_TABLES = "Merit Tables"
WOMENS_LEAGUES = "Women's Leagues"
CUPS = "Cups"
WOMENS_CUPS = "Women's Cups"
CATEGORIES = [ELITE, INTERNATIONALS, MENS_LEAGUES, MERIT_TABLES, WOMENS_LEAGUES, CUPS, WOMENS_CUPS]

INTERNATIONAL_IDS = {0, 1, 2, 3, 4, 7, 8, 179, 1659, 1976, 2311, 2327}
# Premiership, Championship, PWR and European club competitions (incl. their old names)
ELITE_IDS = {5, 9, 10, 16, 173, 207, 208, 1655, 1656, 1752, 1764, 1988}

# Labels and names that mark age-grade or university competitions (kept out).
EXCLUDED_LABELS = {"youth", "colts", "school", "busa"}
AGE_GRADE_NAME = re.compile(r"\b(u ?1[0-8]s?|under ?1[0-8]|colts?|youth|girls?|boys|schools?|junior leagues?|"
                            r"age[- ]grade|ace|academy|bucs|universit(y|ies))\b", re.I)
# Placeholder or mistaken entries on the RFU side (e.g. "Paul Harris Devon League-wrong")
JUNK_NAME = re.compile(r"\b(wrong|test|do not use|duplicate)\b", re.I)


def clean_name(name: str) -> str:
    """Collapse whitespace; the RFU serves some apostrophes as U+FFFD."""
    return " ".join(str(name).replace("�", "’").split())


@dataclass
class Competition:
    rfu_competition_id: int
    name: str
    category: str
    rfu_type: str  # the RFU's own label, e.g. "Senior League"
    is_elite: bool


@dataclass
class DivisionLink:
    rfu_division_id: int
    name: str


def classify(cid: int, name: str, rfu_type: Optional[str], is_elite: bool) -> Optional[str]:
    """Display group for a competition, or None to leave it out."""
    label = (rfu_type or "").strip().lower()
    if label in EXCLUDED_LABELS or AGE_GRADE_NAME.search(name) or JUNK_NAME.search(name):
        return None
    if cid in INTERNATIONAL_IDS or re.search(r"\binternationals?\b", name, re.I):
        return INTERNATIONALS
    if cid in ELITE_IDS or is_elite:
        return ELITE
    if label == "womens league":
        return WOMENS_LEAGUES
    if label == "womens cup":
        return WOMENS_CUPS
    if label == "senior cup":
        return WOMENS_CUPS if re.search(r"\bwom[ae]n'?s?\b|\bladies\b", name, re.I) else CUPS
    if label == "senior league":
        if re.search(r"\bwom[ae]n'?s?\b|\bladies\b", name, re.I):
            return WOMENS_LEAGUES
        return MERIT_TABLES if re.search(r"\bmerit\b", name, re.I) else MENS_LEAGUES
    return None  # unknown label: not something we can place


def merge_competitions(search_results: List[dict], directory: Dict[int, str]) -> Dict[int, Competition]:
    """Classify competitions from search API items (CompetitionType) and the
    directory page. The directory's name is preferred where both have one
    (it is the friendlier one, e.g. "Devon Merit Tables" rather than
    "Paul Harris Devon League"); directory-only entries carry no RFU label,
    so only the known elite and international ones are kept from it.
    """
    items = {}
    for item in search_results:
        if item.get("listType") == "CompetitionType":
            items[int(item["_id"])] = item
    found = {}
    for cid in set(items) | set(directory):
        item = items.get(cid, {})
        search_name = clean_name(item.get("name", ""))
        name = clean_name(directory.get(cid) or search_name)
        rfu_type = item.get("league") or ""
        is_elite = bool(item.get("isElite"))
        # Either name can reveal an age-grade or junk entry, so both must pass
        if search_name and classify(cid, search_name, rfu_type, is_elite) is None:
            continue
        category = classify(cid, name, rfu_type, is_elite)
        if category:
            found[cid] = Competition(cid, name, category, rfu_type, is_elite)
    return found


def competitions_from_directory(html: str) -> Dict[int, str]:
    """{competition id: name} from the Fixtures & Results page's directory links."""
    soup = BeautifulSoup(html, "html.parser")
    found = {}
    for a in soup.find_all("a", href=True):
        m = re.search(r"[?&]competition=(\d+)", a["href"])
        name = clean_name(a.get_text(" ", strip=True))
        if m and name and "division=" not in a["href"]:
            found.setdefault(int(m.group(1)), name)
    return found


def parse_competition_divisions(html: str, competition_id: int, competition_name: str) -> List[DivisionLink]:
    """The divisions a competition page lists for its season.

    Competitions with several divisions (leagues, merit tables, cup rounds)
    list them as accordion cards. A competition with a single division (e.g.
    internationals) has no list - just "View all" and fixture-card links to
    it - so that one division takes the competition's name.
    """
    soup = BeautifulSoup(html, "html.parser")

    def own_division_id(href: str) -> Optional[int]:
        # Pages also carry quick links to other competitions' divisions
        m = re.search(r"[?&]division=(\d+)", href)
        comp = re.search(r"[?&]competition=(\d+)", href)
        if not m or not comp or int(comp.group(1)) != competition_id:
            return None
        if "team=" in href or "matchId=" in href:
            return None
        return int(m.group(1))

    divisions: Dict[int, str] = {}
    for a in soup.find_all("a", class_="c026_accordion_items_card_link", href=True):
        did = own_division_id(a["href"])
        name = clean_name(a.get_text(" ", strip=True))
        if did is not None and name:
            divisions.setdefault(did, name)
    if divisions:
        return [DivisionLink(did, name) for did, name in divisions.items()]

    single = {did for a in soup.find_all("a", href=True) if (did := own_division_id(a["href"])) is not None}
    if len(single) == 1:
        return [DivisionLink(single.pop(), competition_name)]
    return [DivisionLink(did, f"{competition_name} ({did})") for did in sorted(single)]
