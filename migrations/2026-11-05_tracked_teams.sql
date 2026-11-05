-- =====================================================================
-- Teams to keep up to date (ticked in the app's team list in Admin mode)
-- Run once in the Supabase SQL Editor. Safe to re-run.
-- =====================================================================
-- The scheduled "Sync player lineups" job (scripts/sync_lineups.py --tracked)
-- only visits the divisions of these teams, and only fetches their matches,
-- so the RFU site's firewall sees far fewer requests. Other teams still load
-- on demand through the live crawl when someone opens them.
--
-- team_name is the canonical name used in standings (e.g. "Plymstock Oaks II").

CREATE TABLE IF NOT EXISTS public.tracked_teams (
    team_name TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.tracked_teams ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access to tracked_teams" ON public.tracked_teams;
CREATE POLICY "Allow public read access to tracked_teams" ON public.tracked_teams FOR SELECT USING (true);
-- Like the other app tables, writes use the public key; the tick boxes are
-- only shown in Admin mode.
DROP POLICY IF EXISTS "Allow public write access to tracked_teams" ON public.tracked_teams;
CREATE POLICY "Allow public write access to tracked_teams" ON public.tracked_teams FOR ALL USING (true) WITH CHECK (true);

-- Start with the club's own sides
INSERT INTO public.tracked_teams (team_name) VALUES ('Plymstock Oaks'), ('Plymstock Oaks II')
ON CONFLICT DO NOTHING;
