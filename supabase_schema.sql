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


-- 6. Custom Fixtures Table (Relational with Teams for Context, Home & Away)
CREATE TABLE IF NOT EXISTS public.custom_fixtures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    division TEXT NOT NULL,
    division_id UUID REFERENCES public.divisions(id) ON DELETE CASCADE,
    home_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
    away_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
    rfu_team_id INT REFERENCES public.teams(rfu_team_id) ON DELETE SET NULL,
    context_team TEXT,
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

CREATE INDEX IF NOT EXISTS idx_custom_fixtures_division ON public.custom_fixtures(division);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_team ON public.custom_fixtures(context_team);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_rfu_id ON public.custom_fixtures(rfu_team_id);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_home_team ON public.custom_fixtures(home_team_id);
CREATE INDEX IF NOT EXISTS idx_custom_fixtures_away_team ON public.custom_fixtures(away_team_id);
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


-- 8. App Settings Table (Site-Wide Defaults, e.g. the default color theme)
CREATE TABLE IF NOT EXISTS public.app_settings (
    id INT PRIMARY KEY DEFAULT 1,
    default_theme_mode TEXT NOT NULL DEFAULT 'cool_minimalist',
    -- BIGINT, not INT: Color.toARGB32() is unsigned 32-bit (up to ~4.29
    -- billion for a fully-opaque color), which overflows Postgres INT's
    -- signed 32-bit range (max ~2.15 billion).
    custom_primary BIGINT,
    custom_accent BIGINT,
    custom_background BIGINT,
    custom_surface BIGINT,
    custom_text BIGINT,
    custom_text_muted BIGINT,
    custom_border BIGINT,
    custom_font_family TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT app_settings_single_row CHECK (id = 1)
);

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access to app_settings" ON public.app_settings FOR SELECT USING (true);
CREATE POLICY "Allow public write access to app_settings" ON public.app_settings FOR ALL USING (true) WITH CHECK (true);


-- 9. Storage Bucket for Team Logos
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


-- =====================================================================
-- Player appearances (see migrations/2026-10-18_player_appearances.sql)
-- =====================================================================
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- 10. Players (one row per RFU playerId)
CREATE TABLE IF NOT EXISTS public.players (
    rfu_player_id INT PRIMARY KEY,
    display_name TEXT NOT NULL,
    name_withheld BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_players_name_trgm
    ON public.players USING gin (display_name extensions.gin_trgm_ops);

-- Once a player has asked for their name to be withheld, never let a later
-- scrape (e.g. an older match page that still shows the name) reveal it again.
CREATE OR REPLACE FUNCTION public.keep_player_name_withheld()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    IF OLD.name_withheld AND NOT NEW.name_withheld THEN
        NEW.name_withheld := TRUE;
        NEW.display_name := OLD.display_name;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_keep_player_name_withheld ON public.players;
CREATE TRIGGER trg_keep_player_name_withheld
    BEFORE UPDATE ON public.players
    FOR EACH ROW EXECUTE FUNCTION public.keep_player_name_withheld();

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to players" ON public.players;
CREATE POLICY "Allow public read access to players" ON public.players FOR SELECT USING (true);


-- 11. Matches (one row per RFU matchId; tracks lineup scrape state).
-- Keyed by the RFU id rather than fixtures.id because fixture rows are
-- deleted and re-inserted on every fixtures resync.
CREATE TABLE IF NOT EXISTS public.matches (
    rfu_match_id INT PRIMARY KEY,
    division_id UUID REFERENCES public.divisions(id) ON DELETE SET NULL,
    rfu_competition_id INT,
    rfu_division_id INT,
    season TEXT NOT NULL,
    match_date DATE,
    home_team TEXT NOT NULL,
    away_team TEXT NOT NULL,
    home_team_id INT,
    away_team_id INT,
    home_score INT,
    away_score INT,
    lineup_status TEXT NOT NULL DEFAULT 'none' CHECK (lineup_status IN ('ok', 'none')),
    lineup_checked_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matches_division ON public.matches(division_id);
CREATE INDEX IF NOT EXISTS idx_matches_season ON public.matches(season);
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to matches" ON public.matches;
CREATE POLICY "Allow public read access to matches" ON public.matches FOR SELECT USING (true);


-- 12. Appearances (one row per player per match-day squad)
CREATE TABLE IF NOT EXISTS public.appearances (
    rfu_match_id INT NOT NULL REFERENCES public.matches(rfu_match_id) ON DELETE CASCADE,
    rfu_player_id INT NOT NULL REFERENCES public.players(rfu_player_id) ON DELETE CASCADE,
    rfu_team_id INT,
    team_name TEXT NOT NULL,
    season TEXT NOT NULL,
    division_id UUID REFERENCES public.divisions(id) ON DELETE SET NULL,
    match_date DATE,
    shirt TEXT NOT NULL DEFAULT '',
    shirt_number INT,
    -- Named on the bench (S1, S2, ...). The lineup doesn't say whether they came on.
    is_substitute BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (rfu_match_id, rfu_player_id)
);

CREATE INDEX IF NOT EXISTS idx_appearances_player ON public.appearances(rfu_player_id);
CREATE INDEX IF NOT EXISTS idx_appearances_season_team ON public.appearances(season, rfu_team_id);
ALTER TABLE public.appearances ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to appearances" ON public.appearances;
CREATE POLICY "Allow public read access to appearances" ON public.appearances FOR SELECT USING (true);


-- 13. Per-player, per-team season totals for the player search.
-- e.g. /rest/v1/player_season_appearances?season=eq.2025-2026&display_name=ilike.*smith*
CREATE OR REPLACE VIEW public.player_season_appearances
WITH (security_invoker = true) AS
SELECT
    a.season,
    a.rfu_player_id,
    p.display_name,
    p.name_withheld,
    a.rfu_team_id,
    MAX(a.team_name) AS team_name,
    COUNT(*) AS appearances,
    COUNT(*) FILTER (WHERE NOT a.is_substitute) AS starts,
    COUNT(*) FILTER (WHERE a.is_substitute) AS bench,
    MIN(a.match_date) AS first_match_date,
    MAX(a.match_date) AS last_match_date
FROM public.appearances a
JOIN public.players p ON p.rfu_player_id = a.rfu_player_id
GROUP BY a.season, a.rfu_player_id, p.display_name, p.name_withheld, a.rfu_team_id;


-- 14. Teams with synced lineups (see migrations/2026-10-18b_player_appearance_teams.sql)
CREATE OR REPLACE VIEW public.player_appearance_teams
WITH (security_invoker = true) AS
SELECT
    t.season,
    t.rfu_team_id,
    MAX(t.team_name) AS team_name,
    COUNT(*) AS matches
FROM (
    SELECT season, home_team_id AS rfu_team_id, home_team AS team_name
    FROM public.matches
    WHERE lineup_status = 'ok' AND home_team_id IS NOT NULL
    UNION ALL
    SELECT season, away_team_id, away_team
    FROM public.matches
    WHERE lineup_status = 'ok' AND away_team_id IS NOT NULL
) t
GROUP BY t.season, t.rfu_team_id;


-- 15. Competition catalogue (see migrations/2026-10-19_competition_catalog.sql)
ALTER TABLE public.competitions ADD COLUMN IF NOT EXISTS rfu_type TEXT;

-- Which competition/season pairs have been read from the RFU site, so a
-- discovery run can resume and past seasons are not fetched again.
CREATE TABLE IF NOT EXISTS public.competition_seasons (
    rfu_competition_id INT NOT NULL REFERENCES public.competitions(rfu_competition_id) ON DELETE CASCADE,
    season TEXT NOT NULL,
    division_count INT NOT NULL DEFAULT 0,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (rfu_competition_id, season)
);

ALTER TABLE public.competition_seasons ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to competition_seasons" ON public.competition_seasons;
CREATE POLICY "Allow public read access to competition_seasons" ON public.competition_seasons FOR SELECT USING (true);

CREATE INDEX IF NOT EXISTS idx_divisions_season_competition ON public.divisions(season, rfu_competition_id);
