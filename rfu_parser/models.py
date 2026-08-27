from dataclasses import dataclass, field, asdict
from typing import List, Optional, Dict, Any

@dataclass
class LeagueTableEntry:
    position: int
    team_name: str
    played: int
    won: int
    drawn: int
    lost: int
    points_for: int = 0
    points_against: int = 0
    points_diff: int = 0
    try_bonus: int = 0
    lose_bonus: int = 0
    points: int = 0
    form: str = ""  # e.g. "WWLDW"
    logo_url: str = ""

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

@dataclass
class LeagueTable:
    division_name: str
    season: str
    entries: List[LeagueTableEntry] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "division_name": self.division_name,
            "season": self.season,
            "entries": [e.to_dict() for e in self.entries]
        }

@dataclass
class Fixture:
    date: str
    time: str
    home_team: str
    away_team: str
    home_score: Optional[int] = None
    away_score: Optional[int] = None
    status: str = "Scheduled"  # "Scheduled", "Completed", "Postponed", "Live"
    venue: str = ""
    competition: str = ""
    round_num: str = ""
    id: str = ""
    is_custom: bool = False
    date_iso: str = ""

    @property
    def result_str(self) -> str:
        if self.home_score is not None and self.away_score is not None:
            return f"{self.home_score} - {self.away_score}"
        return "v"

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["result_str"] = self.result_str
        return d

@dataclass
class RFUDataResult:
    division_name: str
    season: str
    standings: List[LeagueTableEntry] = field(default_factory=list)
    fixtures: List[Fixture] = field(default_factory=list)

    def filter_by_team(self, team_name: str) -> "RFUDataResult":
        tokens = [t.lower() for t in team_name.strip().split() if len(t) > 1]
        if not tokens:
            return self

        matched_standings = [
            s for s in self.standings
            if all(token in s.team_name.lower() for token in tokens)
        ]
        matched_fixtures = [
            f for f in self.fixtures
            if all(token in f.home_team.lower() for token in tokens) or all(token in f.away_team.lower() for token in tokens)
        ]
        return RFUDataResult(
            division_name=self.division_name,
            season=self.season,
            standings=matched_standings,
            fixtures=matched_fixtures
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "division_name": self.division_name,
            "season": self.season,
            "standings": [s.to_dict() for s in self.standings],
            "fixtures": [f.to_dict() for f in self.fixtures]
        }
