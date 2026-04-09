-- Migration: 00004_create_reminders
-- Table: reminders
-- Drives maintenance alerts: each row defines a recurring km-interval reminder.
-- RLS: owner identified by `user_id = auth.uid()`.

CREATE TABLE IF NOT EXISTS public.reminders (
  id                UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id           UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  message           TEXT        NOT NULL,
  -- How many km between services (e.g. 5000 for oil change every 5k km)
  interval_km       NUMERIC(10, 2) NOT NULL CHECK (interval_km > 0),
  -- The km reading at which this reminder was last serviced
  last_service_km   NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (last_service_km >= 0),
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT reminders_pkey PRIMARY KEY (id)
);

-- Index for RLS policy performance
CREATE INDEX IF NOT EXISTS reminders_user_id_idx ON public.reminders (user_id);

-- ─────────────────────────────────────────────
-- RLS: enable and lock down to owner only
-- ─────────────────────────────────────────────
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- SELECT: user can read their own reminders
CREATE POLICY reminders_select_own ON public.reminders
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- INSERT: user can create reminders for themselves only
CREATE POLICY reminders_insert_own ON public.reminders
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- UPDATE: user can edit their own reminders
CREATE POLICY reminders_update_own ON public.reminders
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- DELETE: user can remove their own reminders
CREATE POLICY reminders_delete_own ON public.reminders
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ─────────────────────────────────────────────
-- Trigger: keep updated_at current
-- ─────────────────────────────────────────────
CREATE TRIGGER reminders_set_updated_at
  BEFORE UPDATE ON public.reminders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
