-- =====================================================================
-- Full RFU competition catalogue (scripts/discover_competitions.py)
-- Run once in the Supabase SQL Editor. Safe to re-run.
-- =====================================================================

-- The RFU's own label for a competition ("Senior League", "Senior Cup",
-- "Womens League", ...); competitions.category holds the app's display group
-- ("Men's Leagues", "Merit Tables", "Cups", "Internationals", ...).
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
