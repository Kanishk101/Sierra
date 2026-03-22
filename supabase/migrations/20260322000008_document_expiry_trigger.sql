-- ============================================================
-- Migration: Document expiry notification trigger (H-12 fix)
-- Sierra Fleet Management System
-- Date: 2026-03-22 (seq 008)
--
-- Fixes audit issue H-12: "Document expiry check never auto-runs."
--
-- Without this: fleet managers only discover expired docs reactively
-- by opening the dashboard. A vehicle's insurance or permit can expire
-- while the vehicle is actively on trips — a serious compliance risk.
--
-- This trigger fires at the DB level when documents are inserted or
-- when their expiry_date changes. Works even when the app is not open.
-- Complements the Swift AppDataStore.checkExpiringDocuments() foreground check.
--
-- Thresholds:
--   > 30 days from now : no notification (not urgent)
--   <= 30 days         : notification with days-remaining in body
--   Past expiry        : EXPIRED label
--
-- De-duplication:
--   One notification per (document_id, admin_id) pair.
--   If expiry_date is updated, old notifications are deleted and new
--   ones are created with the revised date/status.
--
-- Depends on: Migration 004 (uses canonical 'fleetManager' role string)
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notify_document_expiry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_admin_id    UUID;
    v_vehicle_name TEXT;
    v_days_until  INT;
    v_status_text TEXT;
    v_title       TEXT;
    v_body        TEXT;
BEGIN
    -- Skip if document expires more than 30 days from now
    IF NEW.expiry_date > NOW() + INTERVAL '30 days' THEN
        RETURN NEW;
    END IF;

    -- Skip UPDATE when expiry_date didn't actually change
    IF TG_OP = 'UPDATE' AND OLD.expiry_date IS NOT DISTINCT FROM NEW.expiry_date THEN
        RETURN NEW;
    END IF;

    -- When expiry_date changes via UPDATE, delete old notifications
    -- so the new ones reflect the revised date.
    IF TG_OP = 'UPDATE' THEN
        DELETE FROM public.notifications
         WHERE entity_type    = 'vehicle_document'
           AND entity_id::text = NEW.id::text
           AND type           = 'Document Expiry';
    END IF;

    v_days_until := EXTRACT(DAY FROM (NEW.expiry_date - NOW()))::INT;

    SELECT COALESCE(name, 'Unknown Vehicle')
      INTO v_vehicle_name
      FROM public.vehicles
     WHERE id = NEW.vehicle_id;

    v_status_text := CASE
        WHEN NEW.expiry_date < NOW() THEN 'EXPIRED'
        WHEN v_days_until <= 7       THEN 'expires in ' || v_days_until || ' day(s)'
        WHEN v_days_until <= 30      THEN 'expires in ' || v_days_until || ' days'
        ELSE 'expiring soon'
    END;

    v_title := 'Document ' || v_status_text || ': ' || NEW.document_type;
    v_body  := v_vehicle_name
               || ' — ' || NEW.document_type
               || ' ' || v_status_text
               || '. Expiry: ' || TO_CHAR(NEW.expiry_date, 'DD Mon YYYY') || '.';

    -- Notify all active fleet managers (canonical role string from Migration 004)
    FOR v_admin_id IN
        SELECT id FROM public.staff_members
         WHERE role   = 'fleetManager'
           AND status = 'Active'
    LOOP
        -- De-duplicate: skip if notification already exists for this doc + admin
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
             WHERE entity_type    = 'vehicle_document'
               AND entity_id::text = NEW.id::text
               AND recipient_id   = v_admin_id::text
               AND type           = 'Document Expiry'
        ) THEN
            INSERT INTO public.notifications
                (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
            VALUES (
                gen_random_uuid(),
                v_admin_id::text,
                'Document Expiry',  -- Swift NotificationType.documentExpiry.rawValue
                v_title,
                v_body,
                'vehicle_document',
                NEW.id::text,
                false,
                NOW()
            );
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_document_expiry_notification ON public.vehicle_documents;

CREATE TRIGGER trg_document_expiry_notification
    AFTER INSERT OR UPDATE OF expiry_date
    ON public.vehicle_documents
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_document_expiry();

-- ------------------------------------------------------------
-- Backfill: notify for documents already expiring within 30 days
-- Only creates notifications that don't already exist.
-- ------------------------------------------------------------
DO $$
DECLARE
    doc         RECORD;
    adm         RECORD;
    days        INT;
    status_text TEXT;
    v_vname     TEXT;
    v_title     TEXT;
    v_body      TEXT;
    inserted    INT := 0;
BEGIN
    FOR doc IN
        SELECT d.id, d.vehicle_id, d.document_type, d.expiry_date
          FROM public.vehicle_documents d
         WHERE d.expiry_date <= NOW() + INTERVAL '30 days'
    LOOP
        days := EXTRACT(DAY FROM (doc.expiry_date - NOW()))::INT;
        status_text := CASE
            WHEN doc.expiry_date < NOW() THEN 'EXPIRED'
            WHEN days <= 7              THEN 'expires in ' || days || ' day(s)'
            ELSE 'expires in ' || days || ' days'
        END;

        SELECT COALESCE(name, 'Unknown Vehicle') INTO v_vname
          FROM public.vehicles WHERE id = doc.vehicle_id;

        v_title := 'Document ' || status_text || ': ' || doc.document_type;
        v_body  := v_vname || ' — ' || doc.document_type || ' ' || status_text
                   || '. Expiry: ' || TO_CHAR(doc.expiry_date, 'DD Mon YYYY') || '.';

        FOR adm IN
            SELECT id FROM public.staff_members
             WHERE role = 'fleetManager' AND status = 'Active'
        LOOP
            IF NOT EXISTS (
                SELECT 1 FROM public.notifications
                 WHERE entity_type    = 'vehicle_document'
                   AND entity_id::text = doc.id::text
                   AND recipient_id   = adm.id::text
                   AND type           = 'Document Expiry'
            ) THEN
                INSERT INTO public.notifications
                    (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
                VALUES (
                    gen_random_uuid(), adm.id::text,
                    'Document Expiry', v_title, v_body,
                    'vehicle_document', doc.id::text, false, NOW()
                );
                inserted := inserted + 1;
            END IF;
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Document expiry backfill complete. % notifications inserted.', inserted;
END;
$$;

-- ============================================================
-- END OF MIGRATION 008
-- ============================================================
