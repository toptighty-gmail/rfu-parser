# RFU Fixtures & League Tables Parser

A Python application for parsing, structuring, exporting, and visualizing Rugby Football Union (RFU) fixtures and standings using **BeautifulSoup4** and **Requests**.

## Project Features
- **Scraper & Parser Engine (`rfu_parser/scraper.py`)**: Parses league table columns (Position, Team, Played, Won, Drawn, Lost, Points For/Against/Diff, Bonus Points, Total Points, Form) and match fixtures/results.
- **Rich Terminal CLI (`cli.py`)**: Renders beautifully formatted tables directly in terminal/PowerShell with form indicators and match status colors.
- **Flask Web Dashboard (`app.py`)**: Dark-mode glassmorphic web dashboard with real-time team filtering, view toggling, and instant exports.
- **Data Exporters (`rfu_parser/exporter.py`)**: One-click exports to JSON and CSV formats.
- **Unit Tests (`tests/test_parser.py`)**: Automated test suite with offline HTML snapshots.

---

## Quick Start

### 1. Requirements & Setup
```bash
pip install -r requirements.txt
```

### 2. Run Terminal CLI Parser
```bash
# Parse local sample snapshot and view terminal tables
python cli.py --sample

# Export standings & fixtures to JSON & CSV
python cli.py --sample --export-json rfu_output.json --export-csv rfu_data

# Parse live URL
python cli.py --url "https://www.englandrugby.com/fixtures-and-results"
```

### 3. Launch Web Dashboard
```bash
python app.py
```
Open [http://127.0.0.1:5000](http://127.0.0.1:5000) in your browser.

### 4. Run Test Suite
```bash
python -m pytest
```

---

## Flutter App Theming

The Flutter client (`lib/`) offers three built-in color themes plus a fully
editable **Custom** theme (`lib/theme/app_theme.dart`, `lib/theme/custom_theme_store.dart`,
`lib/widgets/custom_theme_editor_dialog.dart`):

- Open the theme picker (palette icon in the navbar) and pick **Custom**, or
  tap its pencil icon to edit it directly.
- Adjust Primary, Accent, Background, Surface, Text, Muted Text, and Border
  colors with an HSV/hex picker, and pick a font from a curated Google Fonts
  list. A live preview and a WCAG contrast warning update as you edit.
- **Apply** saves your choices (persisted locally) and switches the app to
  the Custom theme; **Cancel** discards unsaved edits; **Reset to Defaults**
  restores the Custom theme's original colors/font.

## Project Structure
```
rfu-parser/
├── rfu_parser/
│   ├── __init__.py
│   ├── models.py       # Dataclasses for LeagueTable, Fixture, etc.
│   ├── scraper.py      # BeautifulSoup parser engine
│   └── exporter.py     # JSON and CSV export logic
├── static/
│   ├── style.css       # Glassmorphism dark mode design system
│   └── app.js          # Interactive tab and search filtering JS
├── templates/
│   └── index.html      # Flask dashboard template
├── tests/
│   ├── sample_data/    # Offline HTML snapshots
│   └── test_parser.py  # Pytest suite
├── cli.py              # Rich CLI entrypoint
├── app.py              # Flask Web App backend
├── requirements.txt    # Package dependencies
└── README.md           # Instructions
```
