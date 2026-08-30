-- =====================================================================
-- RFU Hub Supabase Database & Storage Setup Schema (Relational Architecture)
-- Execute this SQL in your Supabase SQL Editor (https://supabase.com)
-- =====================================================================

-- 1. Competitions Table (Top-Level Container for 255+ RFU Competitions)
CREATE TABLE IF NOT EXISTS public.competitions (
    rfu_competition_id INT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT DEFAULT 'Senior Mens',
    is_elite BOOLEAN DEFAULT FALSE,
    season TEXT NOT NULL DEFAULT '2025-2026',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.competitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to competitions" ON public.competitions FOR SELECT USING (true);
CREATE POLICY "Allow public write access to competitions" ON public.competitions FOR ALL USING (true) WITH CHECK (true);

-- Seed Core Competitions
INSERT INTO public.competitions (rfu_competition_id, name, category, is_elite) VALUES
    (173, 'Gallagher Premiership / Championship', 'Elite Men', TRUE),
    (1605, 'National Leagues', 'Senior Mens', FALSE),
    (1699, 'South West Division', 'Senior Mens', FALSE),
    (261, 'London & SE Division', 'Senior Mens', FALSE),
    (1597, 'Midlands Division', 'Senior Mens', FALSE),
    (1623, 'Northern Division', 'Senior Mens', FALSE),
    (1764, 'Jaecoo Premiership Women''s Rugby', 'Elite Women', TRUE)
ON CONFLICT (rfu_competition_id) DO NOTHING;


-- 2. Teams Table (Centralized Canonical Clubs)
CREATE TABLE IF NOT EXISTS public.teams (
    rfu_team_id INT PRIMARY KEY,
    team_name TEXT UNIQUE NOT NULL,
    base_club_name TEXT NOT NULL,
    parent_club_id INT,
    county TEXT DEFAULT 'Devon',
    logo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teams_name ON public.teams(LOWER(team_name));
CREATE INDEX IF NOT EXISTS idx_teams_county ON public.teams(county);
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to teams" ON public.teams FOR SELECT USING (true);
CREATE POLICY "Allow public write access to teams" ON public.teams FOR ALL USING (true) WITH CHECK (true);


-- 3. Divisions Table (Relational with Competitions & Tier Levels)
CREATE TABLE IF NOT EXISTS public.divisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rfu_competition_id INT REFERENCES public.competitions(rfu_competition_id) ON DELETE SET NULL,
    rfu_division_id INT,
    division_name TEXT NOT NULL,
    tier_level INT DEFAULT 8,
    region TEXT DEFAULT 'South West',
    season TEXT NOT NULL DEFAULT '2025-2026',
    source_url TEXT DEFAULT '',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(division_name, season)
);

CREATE INDEX IF NOT EXISTS idx_divisions_name_season ON public.divisions(division_name, season);
CREATE INDEX IF NOT EXISTS idx_divisions_competition ON public.divisions(rfu_competition_id);
CREATE INDEX IF NOT EXISTS idx_divisions_tier ON public.divisions(tier_level);
ALTER TABLE public.divisions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to divisions" ON public.divisions FOR SELECT USING (true);
CREATE POLICY "Allow public write access to divisions" ON public.divisions FOR ALL USING (true) WITH CHECK (true);


-- 4. Standings Table (Relational with Divisions & Teams)
CREATE TABLE IF NOT EXISTS public.standings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_id UUID REFERENCES public.divisions(id) ON DELETE CASCADE,
    rfu_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
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
CREATE INDEX IF NOT EXISTS idx_standings_rfu_team ON public.standings(rfu_team_id);
ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to standings" ON public.standings FOR SELECT USING (true);
CREATE POLICY "Allow public write access to standings" ON public.standings FOR ALL USING (true) WITH CHECK (true);


-- 5. Fixtures Table (Relational with Divisions & Home/Away Teams)
CREATE TABLE IF NOT EXISTS public.fixtures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division_id UUID REFERENCES public.divisions(id) ON DELETE CASCADE,
    home_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
    away_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
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
CREATE INDEX IF NOT EXISTS idx_fixtures_home_team ON public.fixtures(home_team_id);
CREATE INDEX IF NOT EXISTS idx_fixtures_away_team ON public.fixtures(away_team_id);
ALTER TABLE public.fixtures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to fixtures" ON public.fixtures FOR SELECT USING (true);
CREATE POLICY "Allow public write access to fixtures" ON public.fixtures FOR ALL USING (true) WITH CHECK (true);


-- 6. Custom Fixtures Table (User Created Friendlies & Cups)
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
    context_team TEXT,
    rfu_team_id INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_fixtures_division ON public.custom_fixtures(division);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_team ON public.custom_fixtures(context_team);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_rfu_id ON public.custom_fixtures(rfu_team_id);
ALTER TABLE public.custom_fixtures ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to custom_fixtures" ON public.custom_fixtures FOR SELECT USING (true);
CREATE POLICY "Allow public write access to custom_fixtures" ON public.custom_fixtures FOR ALL USING (true) WITH CHECK (true);


-- 7. Team Logos Table (Legacy Index & Mapping)
CREATE TABLE IF NOT EXISTS public.team_logos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_name TEXT UNIQUE NOT NULL,
    logo_url TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_team_logos_team_name ON public.team_logos(LOWER(team_name));
ALTER TABLE public.team_logos ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to team_logos" ON public.team_logos FOR SELECT USING (true);
CREATE POLICY "Allow public write access to team_logos" ON public.team_logos FOR ALL USING (true) WITH CHECK (true);


-- 8. Storage Bucket for Team Logos
INSERT INTO storage.buckets (id, name, public)
VALUES ('rfu-parcer-team-logos', 'rfu-parcer-team-logos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public Read Access for Team Logos"
ON storage.objects FOR SELECT
USING (bucket_id = 'rfu-parcer-team-logos');

CREATE POLICY "Public Upload Access for Team Logos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'rfu-parcer-team-logos');

CREATE POLICY "Public Update/Delete Access for Team Logos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'rfu-parcer-team-logos');
