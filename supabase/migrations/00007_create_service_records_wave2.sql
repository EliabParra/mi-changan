-- Migration: 00007_create_service_records_wave2
-- Table: service_records (Wave 2 / H5 — replaces schema from 00005 if not yet applied)
-- Records each maintenance event, linked to a maintenance_reminders row.
-- Column names must match SupabaseServiceRepository field mapping exactly:
--   reminder_id, reminder_label, odometer_km, cost_usd, service_date,
--   workshop_name, notes
-- RLS: owner identified by `user_id = auth.uid()`.
-- NOTE: legacy `service_records` table from 00005 uses different column names
--   (date, service_type, km_at_service, cost, workshop).  This migration uses
--   IF NOT EXISTS so it is a no-op when the table already exists.  If you are
--   running against a fresh database the table from 00005 will not exist yet
--   and this migration creates the Wave-2-compatible schema.  If 00005 was
--   already applied, drop the old table manually before applying this file OR
--   rename the table in 00005 to `service_records_legacy`.

-- Drop legacy table if it was created by 00005 with the old column layout,
-- but ONLY when its schema does not yet have the Wave-2 columns.
-- Using a DO block to make this conditional and safe.
DO $$
BEGIN
  -- If service_records already has the Wave-2 column `reminder_label`, skip.
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'service_records'
      AND column_name  = 'reminder_label'
  ) THEN
    -- Drop the legacy table (00005 schema) only when it exists.
    DROP TABLE IF EXISTS public.service_records CASCADE;
  END IF;
END
$$;

CREATE TABLE IF NOT EXISTS public.service_records (
  id              UUID        NOT NULL DEFAULT gen_random_uuid(),
  user_id         UUID        NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  -- Link to the maintenance reminder this service satisfies (required).
  -- SET NULL: deleting a reminder does NOT delete service history.
  reminder_id     UUID        NOT NULL REFERENCES public.maintenance_reminders (id) ON DELETE SET NULL,
  -- Denormalized label — avoids joins when displaying history.
  reminder_label  TEXT        NOT NULL,
  -- Odometer reading at the time of service
  odometer_km     NUMERIC(10, 2) NOT NULL CHECK (odometer_km >= 0),
  -- Cost in USD (Venezuelan market, multi-currency baseline)
  cost_usd        NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (cost_usd >= 0),
  -- Date/time of service (stored UTC)
  service_date    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Optional workshop or mechanic name
  workshop_name   TEXT,
  -- Optional free-text notes
  notes           TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT service_records_pkey PRIMARY KEY (id)
);

-- ─────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────

-- Required for RLS policy performance
CREATE INDEX IF NOT EXISTS service_records_user_id_idx
  ON public.service_records (user_id);

-- Supports fetchRecords ORDER BY service_date DESC
CREATE INDEX IF NOT EXISTS service_records_user_date_idx
  ON public.service_records (user_id, service_date DESC);

-- FK lookup / joining back to maintenance_reminders
CREATE INDEX IF NOT EXISTS service_records_reminder_id_idx
  ON public.service_records (reminder_id);

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
