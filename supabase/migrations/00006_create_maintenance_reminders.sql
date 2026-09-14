-- Migration: 00006_create_maintenance_reminders
-- Table: maintenance_reminders
-- Drives the maintenance feature (Wave 2 / H4).
-- Column names must match SupabaseMaintenanceRepository field mapping exactly:
--   label, interval_km, last_service_km, last_service_date, notes
-- RLS: owner identified by `user_id = auth.uid()`.
-- NOTE: legacy `reminders` table (00004) is kept intact — do not drop it.

CREATE TABLE IF NOT EXISTS public.maintenance_reminders (
  id                UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id           UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  -- Human-readable label shown in the UI (e.g. 'Cambio de aceite')
  label             TEXT        NOT NULL,
  -- Service recurrence interval in km (e.g. 5000 for every 5 000 km)
  interval_km       NUMERIC(10, 2) NOT NULL CHECK (interval_km > 0),
  -- Odometer reading at the last service (baseline for next-service calc)
  last_service_km   NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (last_service_km >= 0),
  -- Date/time of the last service performed (stored UTC)
  last_service_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Optional free-text notes
  notes             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT maintenance_reminders_pkey PRIMARY KEY (id)
);

-- ─────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────

-- Required for RLS policy performance (every query filters by user_id)
CREATE INDEX IF NOT EXISTS maintenance_reminders_user_id_idx
  ON public.maintenance_reminders (user_id);

-- Supports fetchReminders ORDER BY label ASC
CREATE INDEX IF NOT EXISTS maintenance_reminders_user_label_idx
  ON public.maintenance_reminders (user_id, label);

-- ─────────────────────────────────────────────
-- RLS: enable and lock down to owner only
-- ─────────────────────────────────────────────
ALTER TABLE public.maintenance_reminders ENABLE ROW LEVEL SECURITY;

-- SELECT: user can read their own reminders
CREATE POLICY maintenance_reminders_select_own ON public.maintenance_reminders
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- INSERT: user can create reminders for themselves only
CREATE POLICY maintenance_reminders_insert_own ON public.maintenance_reminders
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- UPDATE: user can edit their own reminders
CREATE POLICY maintenance_reminders_update_own ON public.maintenance_reminders
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- DELETE: user can remove their own reminders
CREATE POLICY maintenance_reminders_delete_own ON public.maintenance_reminders
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ─────────────────────────────────────────────
-- Trigger: keep updated_at current
-- ─────────────────────────────────────────────
CREATE TRIGGER maintenance_reminders_set_updated_at
  BEFORE UPDATE ON public.maintenance_reminders
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
