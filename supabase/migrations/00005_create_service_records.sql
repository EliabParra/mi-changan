-- Migration: 00005_create_service_records
-- Table: service_records
-- Records each maintenance event. Optionally linked to a reminder that triggered it.
-- RLS: owner identified by `user_id = auth.uid()`.
-- FK to reminders uses SET NULL — deleting a reminder does NOT delete its history.

CREATE TABLE IF NOT EXISTS public.service_records (
  id            UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  -- Optional link to the reminder this service satisfies
  reminder_id   UUID        REFERENCES public.reminders (id) ON DELETE SET NULL,
  date          DATE        NOT NULL,
  service_type  TEXT        NOT NULL,
  km_at_service NUMERIC(10, 2) NOT NULL CHECK (km_at_service >= 0),
  cost          NUMERIC(12, 2) CHECK (cost >= 0),
  workshop      TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT service_records_pkey PRIMARY KEY (id)
);

-- Index for RLS policy performance
CREATE INDEX IF NOT EXISTS service_records_user_id_idx ON public.service_records (user_id);
-- Index for common query: list service records for a user ordered by date
CREATE INDEX IF NOT EXISTS service_records_user_date_idx ON public.service_records (user_id, date DESC);
-- Index on reminder_id for FK lookups / joining
CREATE INDEX IF NOT EXISTS service_records_reminder_id_idx ON public.service_records (reminder_id);

-- ─────────────────────────────────────────────
-- RLS: enable and lock down to owner only
-- ─────────────────────────────────────────────
ALTER TABLE public.service_records ENABLE ROW LEVEL SECURITY;

-- SELECT: user can read their own service history
CREATE POLICY service_records_select_own ON public.service_records
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- INSERT: user can log services for themselves only
CREATE POLICY service_records_insert_own ON public.service_records
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- UPDATE: user can correct their own service records
CREATE POLICY service_records_update_own ON public.service_records
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- DELETE: user can remove their own service records
CREATE POLICY service_records_delete_own ON public.service_records
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ─────────────────────────────────────────────
-- Trigger: keep updated_at current
-- ─────────────────────────────────────────────
CREATE TRIGGER service_records_set_updated_at
  BEFORE UPDATE ON public.service_records
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
