-- Migration: 00002_create_vehicle_settings
-- Table: vehicle_settings
-- KV store pattern for per-user vehicle configuration.
-- RLS: owner identified by `user_id = auth.uid()`.

CREATE TABLE IF NOT EXISTS public.vehicle_settings (
  id          UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  key         TEXT        NOT NULL,
  value       TEXT        NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT vehicle_settings_pkey PRIMARY KEY (id),
  -- Enforce one value per key per user
  CONSTRAINT vehicle_settings_user_key_unique UNIQUE (user_id, key)
);

-- Index for RLS policy performance: (select auth.uid()) = user_id scans this
CREATE INDEX IF NOT EXISTS vehicle_settings_user_id_idx ON public.vehicle_settings (user_id);

-- ─────────────────────────────────────────────
-- RLS: enable and lock down to owner only
-- ─────────────────────────────────────────────
ALTER TABLE public.vehicle_settings ENABLE ROW LEVEL SECURITY;

-- SELECT: user can read their own settings
CREATE POLICY vehicle_settings_select_own ON public.vehicle_settings
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- INSERT: user can insert settings for themselves only
CREATE POLICY vehicle_settings_insert_own ON public.vehicle_settings
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- UPDATE: user can update their own settings
CREATE POLICY vehicle_settings_update_own ON public.vehicle_settings
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- DELETE: user can remove their own settings
CREATE POLICY vehicle_settings_delete_own ON public.vehicle_settings
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ─────────────────────────────────────────────
-- Trigger: keep updated_at current
-- ─────────────────────────────────────────────
CREATE TRIGGER vehicle_settings_set_updated_at
  BEFORE UPDATE ON public.vehicle_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
