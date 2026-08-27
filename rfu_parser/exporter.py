import csv
import json
from typing import Dict, Any
from rfu_parser.models import RFUDataResult

class DataExporter:
    @staticmethod
    def to_json(data: RFUDataResult, filepath: str) -> str:
        """Export RFU data result to a JSON file."""
        data_dict = data.to_dict()
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data_dict, f, indent=2)
        return filepath

    @staticmethod
    def to_csv_standings(data: RFUDataResult, filepath: str) -> str:
        """Export standings table to a CSV file."""
        if not data.standings:
            return ""

        headers = ["Position", "Team", "Played", "Won", "Drawn", "Lost", "PF", "PA", "PD", "Try Bonus", "Lose Bonus", "Points", "Form"]
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            for entry in data.standings:
                writer.writerow([
                    entry.position,
                    entry.team_name,
                    entry.played,
                    entry.won,
                    entry.drawn,
                    entry.lost,
                    entry.points_for,
                    entry.points_against,
                    entry.points_diff,
                    entry.try_bonus,
                    entry.lose_bonus,
                    entry.points,
                    entry.form
                ])
        return filepath

    @staticmethod
    def to_csv_fixtures(data: RFUDataResult, filepath: str) -> str:
        """Export fixtures to a CSV file."""
        if not data.fixtures:
            return ""

        headers = ["Date", "Time", "Home Team", "Result/Status", "Away Team", "Venue", "Round"]
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            for fix in data.fixtures:
                writer.writerow([
                    fix.date,
                    fix.time,
                    fix.home_team,
                    fix.result_str if fix.status == "Completed" else fix.status,
                    fix.away_team,
                    fix.venue,
                    fix.round_num
                ])
        return filepath
