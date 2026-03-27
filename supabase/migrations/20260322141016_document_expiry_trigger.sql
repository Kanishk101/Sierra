
CREATE OR REPLACE FUNCTION public.fn_notify_document_expiry()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_admin_id    UUID;
    v_vehicle_name TEXT;
    v_days_until  INT;
    v_status_text TEXT;
    v_title       TEXT;
    v_body        TEXT;
BEGIN
    IF NEW.expiry_date > NOW() + INTERVAL '30 days' THEN RETURN NEW; END IF;
    IF TG_OP = 'UPDATE' AND OLD.expiry_date IS NOT DISTINCT FROM NEW.expiry_date THEN RETURN NEW; END IF;

    -- On expiry_date change, clear stale notifications so new ones reflect the updated date
    IF TG_OP = 'UPDATE' THEN
        DELETE FROM public.notifications
        WHERE entity_type = 'vehicle_document'
          AND entity_id::text = NEW.id::text
          AND type = 'Document Expiry';
    END IF;

    v_days_until := EXTRACT(DAY FROM (NEW.expiry_date - NOW()))::INT;
    SELECT COALESCE(name, 'Unknown Vehicle') INTO v_vehicle_name
      FROM public.vehicles WHERE id = NEW.vehicle_id;

    v_status_text := CASE
        WHEN NEW.expiry_date < NOW() THEN 'EXPIRED'
        WHEN v_days_until <= 7       THEN 'expires in ' || v_days_until || ' day(s)'
        ELSE                              'expires in ' || v_days_until || ' days'
    END;

    v_title := 'Document ' || v_status_text || ': ' || NEW.document_type;
    v_body  := v_vehicle_name || ' — ' || NEW.document_type || ' ' || v_status_text
               || '. Expiry: ' || TO_CHAR(NEW.expiry_date, 'DD Mon YYYY') || '.';

    FOR v_admin_id IN
        SELECT id FROM public.staff_members WHERE get_my_role_for(id) = 'fleetManager'
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
            WHERE entity_type = 'vehicle_document'
              AND entity_id::text = NEW.id::text
              AND recipient_id = v_admin_id
              AND type = 'Document Expiry'
        ) THEN
            INSERT INTO public.notifications
                (recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at, created_at)
            VALUES (
                v_admin_id, 'Document Expiry', v_title, v_body,
                'vehicle_document', NEW.id, false, NOW(), NOW()
            );
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_document_expiry_notification ON public.vehicle_documents;
CREATE TRIGGER trg_document_expiry_notification
    AFTER INSERT OR UPDATE OF expiry_date ON public.vehicle_documents
    FOR EACH ROW EXECUTE FUNCTION public.fn_notify_document_expiry();
;
