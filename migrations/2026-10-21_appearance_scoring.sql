-- =====================================================================
-- Tries, conversions, penalties, drop goals and cards per appearance,
-- from the "key match events" on RFU match-centre pages. Run once in the
-- Supabase SQL Editor after 2026-10-18_player_appearances.sql. Safe to re-run.
--
-- Matches stored before this have events_checked = FALSE; the lineup sync
-- re-fetches them once (scripts/sync_lineups.py --missing-events does all of
-- them in one go, any season).
-- =====================================================================

ALTER TABLE public.appearances
    ADD COLUMN IF NOT EXISTS tries INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS conversions INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS penalties INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS drop_goals INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS yellow_cards INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS red_cards INT NOT NULL DEFAULT 0;

-- Whether the match's events have been read into its appearances
ALTER TABLE public.matches
    ADD COLUMN IF NOT EXISTS events_checked BOOLEAN NOT NULL DEFAULT FALSE;

-- New columns go at the end: CREATE OR REPLACE VIEW can only append.
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
    MAX(a.match_date) AS last_match_date,
    SUM(a.tries) AS tries,
    SUM(a.conversions) AS conversions,
    SUM(a.penalties) AS penalties,
    SUM(a.drop_goals) AS drop_goals,
    SUM(a.yellow_cards) AS yellow_cards,
    SUM(a.red_cards) AS red_cards
FROM public.appearances a
JOIN public.players p ON p.rfu_player_id = a.rfu_player_id
GROUP BY a.season, a.rfu_player_id, p.display_name, p.name_withheld, a.rfu_team_id;
