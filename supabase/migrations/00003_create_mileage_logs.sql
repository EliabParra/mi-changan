-- Migration: 00003_create_mileage_logs
-- Table: mileage_logs
-- Core data table: each row records a km reading with optional GPS coordinates.
-- RLS: owner identified by `user_id = auth.uid()`.

CREATE TABLE IF NOT EXISTS public.mileage_logs (
  id          UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  date        DATE        NOT NULL,
  km_value    NUMERIC(10, 2) NOT NULL CHECK (km_value >= 0),
  -- 'manual' = user typed, 'gps' = location-derived
  type        TEXT        NOT NULL CHECK (type IN ('manual', 'gps')),
  -- GPS coords: nullable — only present when type = 'gps'
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT mileage_logs_pkey PRIMARY KEY (id)
);

-- Index for RLS policy performance
CREATE INDEX IF NOT EXISTS mileage_logs_user_id_idx ON public.mileage_logs (user_id);
-- Index for common query pattern: list logs for a user ordered by date
CREATE INDEX IF NOT EXISTS mileage_logs_user_date_idx ON public.mileage_logs (user_id, date DESC);

-- ─────────────────────────────────────────────
-- RLS: enable and lock down to owner only
-- ─────────────────────────────────────────────
ALTER TABLE public.mileage_logs ENABLE ROW LEVEL SECURITY;

-- SELECT: user can read their own logs
CREATE POLICY mileage_logs_select_own ON public.mileage_logs
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- INSERT: user can insert logs for themselves only
CREATE POLICY mileage_logs_insert_own ON public.mileage_logs
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- UPDATE: user can correct their own logs
CREATE POLICY mileage_logs_update_own ON public.mileage_logs
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- DELETE: user can remove their own logs
CREATE POLICY mileage_logs_delete_own ON public.mileage_logs
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);
