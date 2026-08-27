import argparse
import sys
import os

# Ensure UTF-8 output encoding for Windows command line
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text

from rfu_parser.scraper import RFUParser
from rfu_parser.exporter import DataExporter

console = Console()

def display_standings(result, highlight_team=None):
    table = Table(
        title=f"=== {result.division_name} - League Standings ({result.season}) ===",
        show_header=True,
        header_style="bold cyan",
        title_style="bold yellow"
    )

    table.add_column("Pos", justify="center", style="bold yellow")
    table.add_column("Team Name", style="bold white", min_width=24)
    table.add_column("P", justify="right")
    table.add_column("W", justify="right", style="green")
    table.add_column("D", justify="right", style="yellow")
    table.add_column("L", justify="right", style="red")
    table.add_column("PF", justify="right")
    table.add_column("PA", justify="right")
    table.add_column("PD", justify="right", style="bold")
    table.add_column("TB", justify="right", style="dim")
    table.add_column("LB", justify="right", style="dim")
    table.add_column("Pts", justify="right", style="bold green")
    table.add_column("Form", justify="center")

    tokens = [t.lower() for t in highlight_team.strip().split() if len(t) > 1] if highlight_team else []

    for entry in result.standings:
        is_highlighted = bool(tokens and all(token in entry.team_name.lower() for token in tokens))

        form_formatted = Text()
        for char in entry.form:
            if char == 'W':
                form_formatted.append(char, style="bold green")
            elif char == 'L':
                form_formatted.append(char, style="bold red")
            elif char == 'D':
                form_formatted.append(char, style="bold yellow")
            else:
                form_formatted.append(char)

        team_display = f"> {entry.team_name} <" if is_highlighted else entry.team_name
        style_override = "bold yellow on blue" if is_highlighted else None

        table.add_row(
            str(entry.position),
            team_display,
            str(entry.played),
            str(entry.won),
            str(entry.drawn),
            str(entry.lost),
            str(entry.points_for),
            str(entry.points_against),
            f"{'+' if entry.points_diff > 0 else ''}{entry.points_diff}",
            str(entry.try_bonus),
            str(entry.lose_bonus),
            str(entry.points),
            form_formatted,
            style=style_override
        )

    console.print(table)

def display_fixtures(result, highlight_team=None):
    table = Table(
        title=f"=== {result.division_name} - Fixtures & Results ===",
        show_header=True,
        header_style="bold magenta",
        title_style="bold yellow"
    )

    table.add_column("Round", style="dim", justify="center")
    table.add_column("Date & Time", style="cyan")
    table.add_column("Home Team", justify="right", style="bold white")
    table.add_column("Score / Status", justify="center", style="bold yellow")
    table.add_column("Away Team", justify="left", style="bold white")
    table.add_column("Venue", style="dim")

    tokens = [t.lower() for t in highlight_team.strip().split() if len(t) > 1] if highlight_team else []

    for fix in result.fixtures:
        is_highlighted = bool(tokens and (
            all(token in fix.home_team.lower() for token in tokens) or
            all(token in fix.away_team.lower() for token in tokens)
        ))

        score_text = fix.result_str if fix.status == "Completed" else "vs"
        score_style = "bold green" if fix.status == "Completed" else "bold yellow"

        style_override = "bold yellow" if is_highlighted else None

        table.add_row(
            fix.round_num or "-",
            f"{fix.date} {fix.time}".strip(),
            fix.home_team,
            Text(score_text, style=score_style),
            fix.away_team,
            fix.venue,
            style=style_override
        )

    console.print(table)

def main():
    parser = argparse.ArgumentParser(description="RFU Fixtures & League Tables BeautifulSoup CLI Parser")
    parser.add_argument("--url", type=str, help="URL of the RFU fixtures/standings webpage")
    parser.add_argument("--team", type=str, help="Filter standings and fixtures by specific team name")
    parser.add_argument("--season", type=str, help="Specify season (e.g. 2025/2026, 2026/2027)")
    parser.add_argument("--sample", action="store_true", help="Force use of local sample data")
    parser.add_argument("--export-json", type=str, help="Path to save JSON output")
    parser.add_argument("--export-csv", type=str, help="Path prefix to save CSV outputs")

    args = parser.parse_args()

    console.print(Panel("[bold green]RFU Fixtures & League Table Scraper & Parser[/bold green]\n[dim]Powered by Python & BeautifulSoup[/dim]"))

    rfu_parser = RFUParser()

    if args.url and not args.sample:
        console.print(f"[bold blue]Fetching live URL:[bold blue] {args.url}")
        result = rfu_parser.fetch_and_parse(args.url)
    else:
        console.print("[bold yellow]Loading RFU sample data snapshot...[/bold yellow]")
        result = rfu_parser.get_sample_data(team_query=args.team, season_query=args.season)

    console.print()
    display_standings(result, highlight_team=args.team)
    console.print()
    display_fixtures(result, highlight_team=args.team)

    if args.export_json:
        json_path = DataExporter.to_json(result, args.export_json)
        console.print(f"\n[bold green][SUCCESS] Exported data to JSON: {json_path}[/bold green]")

    if args.export_csv:
        csv_standings = DataExporter.to_csv_standings(result, f"{args.export_csv}_standings.csv")
        csv_fixtures = DataExporter.to_csv_fixtures(result, f"{args.export_csv}_fixtures.csv")
        console.print(f"\n[bold green][SUCCESS] Exported standings CSV: {csv_standings}[/bold green]")
        console.print(f"[bold green][SUCCESS] Exported fixtures CSV: {csv_fixtures}[/bold green]")

if __name__ == "__main__":
    main()
