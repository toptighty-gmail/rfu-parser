# RFU Fixtures & League Tables Hub - Technical Handover & Architecture

Welcome to the **RFU Fixtures & League Tables Hub** codebase! This document provides a complete technical handover for developers and **Antigravity AI Agents** maintaining, testing, or extending this application.

---

## 🏛️ Application Architecture & Technology Stack

The application uses a **Flutter Web/Multi-platform UI**, **Supabase PostgreSQL & Storage database backend**, and a **Vercel Python Serverless Scraper API**:

```
                       ┌──────────────────────────────────────────────┐
                       │          Flutter Frontend (Web/App)         │
                       │  - Dark Glassmorphism Design System          │
                       │  - Division & Team Search, Standings, Fix.  │
                       │  - A4 Booklet & A3 Poster Print View Engine  │
                       └──────┬───────────────────────────────┬───────┘
                              │                               │
                  REST / API Calls                   Supabase Flutter SDK
                              │                               │
                              ▼                               ▼
         ┌─────────────────────────────────┐   ┌─────────────────────────────┐
         │   Vercel Python Serverless API  │   │      Supabase Backend       │
         │   - BeautifulSoup Scraper       │   │  - PostgreSQL: Fixtures     │
         │   - Live RFU Portal Crawler     │   │  - Storage: Team Logos      │
         │   - Exporter (JSON/CSV)         │   │  - Auth / RLS Security      │
         └─────────────────────────────────┘   └─────────────────────────────┘
```

### Components
- **Flutter GUI (`lib/`)**: Built using Flutter 3.x with Google Fonts (Outfit), glassmorphism design, responsive desktop/mobile grid layouts, division selector, team search, custom fixture editor modal, logo upload modal, and A4 Booklet / A3 Poster printable views.
- **Vercel Serverless Scraper API (`api/index.py` & `app.py`)**: Python WSGI endpoint running BeautifulSoup4 scraper to fetch live RFU league tables and team fixtures, exposing CORS-enabled JSON endpoints (`/api/parse`, `/api/crawl`, `/api/suggest-teams`).
- **Database & Storage (`supabase_schema.sql` & `lib/services/supabase_service.dart`)**: Supabase PostgreSQL table `custom_fixtures` for managing manual/friendly matches and Supabase Storage bucket `team-logos` with `team_logos` table mapping for custom team logo image uploads.

---

## 🔑 Environment Variables & Security

| Environment Variable | Description | Default / Example Value |
| :--- | :--- | :--- |
| `ADMIN_PASSWORD` | Password required to access Admin mode in GUI | `"rugby2026"` |
| `SECRET_KEY` | Flask session secret key | `"rfu-hub-secret-key-2026"` |
| `SUPABASE_URL` | Supabase API URL | `https://your-project.supabase.co` |
| `SUPABASE_ANON_KEY` | Supabase public anonymous key | `your-supabase-anon-key` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase admin service role key | `your-supabase-service-role-key` |

---

## 🚀 How to Run Locally

### 1. Run Python Backend API
```bash
python app.py
```
Backend API will listen on `http://127.0.0.1:5000`.

### 2. Run Flutter GUI Frontend
```bash
flutter run -d chrome
```

---

## ☁️ Deployment Guide

### A. Supabase Database & Storage Setup
1. Create a project on [Supabase](https://supabase.com).
2. Open the **SQL Editor** in your Supabase Dashboard.
3. Paste and run the contents of [supabase_schema.sql](file:///c:/FlutterApps/rfu-parser/supabase_schema.sql).

### B. Vercel Deployment
1. Import your GitHub repository to [Vercel](https://vercel.com).
2. Set environment variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `ADMIN_PASSWORD`) in Vercel Project Settings.
3. Deploy! Vercel automatically routes `/api/*` requests to `api/index.py` and serves the static Flutter Web build from `build/web`.

---

## 🧪 Running Automated Tests

Run the Python test suite:
```bash
pytest
```

Run Flutter analysis:
```bash
flutter analyze
```
