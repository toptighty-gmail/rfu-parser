-- =====================================================================
-- Teams that have synced lineups, per season (feeds the team dropdown in
-- the Player Appearances search). Run once in the Supabase SQL Editor
-- after 2026-10-18_player_appearances.sql. Safe to re-run.
-- Built from matches (one row per match) rather than appearances (~36 per
-- match) so it stays quick to aggregate.
-- =====================================================================

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
