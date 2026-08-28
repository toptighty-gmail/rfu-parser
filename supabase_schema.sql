-- =====================================================================
-- RFU Hub Supabase Database & Storage Setup Schema
-- Execute this SQL in your Supabase SQL Editor (https://supabase.com)
-- =====================================================================

-- 1. Custom Fixtures Table
CREATE TABLE IF NOT EXISTS public.custom_fixtures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division TEXT NOT NULL,
    date TEXT NOT NULL,
    time TEXT DEFAULT '15:00',
    home_team TEXT NOT NULL,
    away_team TEXT NOT NULL,
    score TEXT DEFAULT 'v',
    status TEXT DEFAULT 'Scheduled',
    notes TEXT DEFAULT '',
    is_custom BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by division
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_division ON public.custom_fixtures(division);

-- Enable RLS for custom_fixtures
ALTER TABLE public.custom_fixtures ENABLE ROW LEVEL SECURITY;

-- Allow public read access to custom fixtures
CREATE POLICY "Allow public read access to custom_fixtures"
ON public.custom_fixtures FOR SELECT
USING (true);

-- Allow public/admin insert/update/delete access
CREATE POLICY "Allow public write access to custom_fixtures"
ON public.custom_fixtures FOR ALL
USING (true)
WITH CHECK (true);


-- 2. Team Logos Table
CREATE TABLE IF NOT EXISTS public.team_logos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_name TEXT UNIQUE NOT NULL,
    logo_url TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookup by team_name
CREATE INDEX IF NOT EXISTS idx_team_logos_team_name ON public.team_logos(LOWER(team_name));

-- Enable RLS for team_logos
ALTER TABLE public.team_logos ENABLE ROW LEVEL SECURITY;

-- Allow public read access to team logos
CREATE POLICY "Allow public read access to team_logos"
ON public.team_logos FOR SELECT
USING (true);

-- Allow public write access to team logos
CREATE POLICY "Allow public write access to team_logos"
ON public.team_logos FOR ALL
USING (true)
WITH CHECK (true);


-- 3. Storage Bucket for Team Logos
-- Create 'team-logos' public bucket if not already existing
INSERT INTO storage.buckets (id, name, public)
VALUES ('team-logos', 'team-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Public access policies for team-logos storage bucket
CREATE POLICY "Public Read Access for Team Logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'team-logos');

CREATE POLICY "Public Upload Access for Team Logos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'team-logos');

-- Public Update/Delete Access for Team Logos
CREATE POLICY "Public Update/Delete Access for Team Logos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'team-logos');


-- =====================================================================
-- 4. Live RFU Relational Tables (Divisions, Standings, Fixtures)
-- =====================================================================

-- Divisions Table
CREATE TABLE IF NOT EXISTS public.divisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_name TEXT NOT NULL,
    season TEXT NOT NULL,
    source_url TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(division_name, season)
);

CREATE INDEX IF NOT EXISTS idx_divisions_name_season ON public.divisions(division_name, season);
ALTER TABLE public.divisions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to divisions" ON public.divisions FOR SELECT USING (true);
CREATE POLICY "Allow public write access to divisions" ON public.divisions FOR ALL USING (true) WITH CHECK (true);

-- Standings Table
CREATE TABLE IF NOT EXISTS public.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_id UUID REFERENCES public.divisions(id) ON DELETE CASCADE,
    position INT NOT NULL,
    team_name TEXT NOT NULL,
    played INT DEFAULT 0,
    won INT DEFAULT 0,
    drawn INT DEFAULT 0,
    lost INT DEFAULT 0,
    points_for INT DEFAULT 0,
    points_against INT DEFAULT 0,
    points_diff INT DEFAULT 0,
    try_bonus INT DEFAULT 0,
    lose_bonus INT DEFAULT 0,
    points INT DEFAULT 0,
    form TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(division_id, team_name)
);

CREATE INDEX IF NOT EXISTS idx_standings_division ON public.standings(division_id);
ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to standings" ON public.standings FOR SELECT USING (true);
CREATE POLICY "Allow public write access to standings" ON public.standings FOR ALL USING (true) WITH CHECK (true);

-- Fixtures Table
CREATE TABLE IF NOT EXISTS public.fixtures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_id UUID REFERENCES public.divisions(id) ON DELETE CASCADE,
    date TEXT NOT NULL,
    time TEXT DEFAULT '15:00',
    home_team TEXT NOT NULL,
    away_team TEXT NOT NULL,
    home_score INT,
    away_score INT,
    status TEXT DEFAULT 'Scheduled',
    venue TEXT DEFAULT '',
    round_num TEXT DEFAULT '',
    is_custom BOOLEAN DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(division_id, home_team, away_team, round_num)
);

CREATE INDEX IF NOT EXISTS idx_fixtures_division ON public.fixtures(division_id);
ALTER TABLE public.fixtures ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to fixtures" ON public.fixtures FOR SELECT USING (true);
CREATE POLICY "Allow public write access to fixtures" ON public.fixtures FOR ALL USING (true) WITH CHECK (true);

