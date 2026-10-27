-- =====================================================================
-- Store whether a manually added fixture is a friendly or a cup game (and
-- which cup). Until now the add-fixture dialog's Cup choice was dropped on
-- insert, so every custom fixture read back as a friendly. Run once in the
-- Supabase SQL Editor. Safe to re-run.
--
-- Existing rows stay NULL, which the app still reads as "Friendly"; edit a
-- cup fixture and save it again to record its cup.
-- =====================================================================

ALTER TABLE public.custom_fixtures
    ADD COLUMN IF NOT EXISTS competition TEXT,
    ADD COLUMN IF NOT EXISTS round_num TEXT;
