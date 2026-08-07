-- =============================================================================
-- 0003_updated_at_triggers.sql
-- Auto-bump updated_at on tests, questions, and passages.
-- updated_at is the ENTIRE delta-sync mechanism — every edit must bump it or
-- students never receive the change. A DB trigger is more reliable than
-- trusting every client write path to remember.
-- =============================================================================

-- ── Generic trigger function ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- ── tests ─────────────────────────────────────────────────────────────────────

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE  trigger_name = 'trg_tests_updated_at'
    AND    event_object_table = 'tests'
  ) THEN
    CREATE TRIGGER trg_tests_updated_at
      BEFORE UPDATE ON tests
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ── questions ─────────────────────────────────────────────────────────────────

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE  trigger_name = 'trg_questions_updated_at'
    AND    event_object_table = 'questions'
  ) THEN
    CREATE TRIGGER trg_questions_updated_at
      BEFORE UPDATE ON questions
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- ── passages ──────────────────────────────────────────────────────────────────

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE  trigger_name = 'trg_passages_updated_at'
    AND    event_object_table = 'passages'
  ) THEN
    CREATE TRIGGER trg_passages_updated_at
      BEFORE UPDATE ON passages
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;

-- Note: chapters and subjects have NO updated_at column by design.
-- They full-sync on every client open, so edits propagate regardless.

-- =============================================================================
-- ROLLBACK (reference only)
-- =============================================================================
-- DROP TRIGGER IF EXISTS trg_tests_updated_at     ON tests;
-- DROP TRIGGER IF EXISTS trg_questions_updated_at ON questions;
-- DROP TRIGGER IF EXISTS trg_passages_updated_at  ON passages;
-- DROP FUNCTION IF EXISTS set_updated_at();
-- =============================================================================
