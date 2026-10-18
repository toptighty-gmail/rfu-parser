-- =====================================================================
-- Player appearances (lineups scraped from RFU match-centre pages)
-- Run once in the Supabase SQL Editor. Safe to re-run.
-- Written by scripts/sync_lineups.py using the service-role key; the
-- public (anon) key can only read these tables.
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
