# Fix B — Document Expiry Auto-Check 🟠 HIGH

**Audit ID:** H-12  
**Priority:** High — admins currently only discover expired documents reactively, never proactively

---

## The Problem

`checkOverdueMaintenance()` runs on app foreground and de-duplicates via existing notifications. There is no equivalent for vehicle documents. `documentsExpiringSoon()` is computed on `AppDataStore` and surfaced in the dashboard, but there is no alert mechanism — admins must manually open the dashboard to notice expired docs.

The SRS requires proactive document expiry notifications.

---

## Tasks

### Task 1 — Add `checkExpiringDocuments()` to `AppDataStore.swift`

Add this method in the `// MARK: - Overdue Maintenance Check` section, right after `checkOverdueMaintenance()`:

```swift
// MARK: - Expiring Documents Check
// Mirrors checkOverdueMaintenance() pattern.
// Runs on app foreground; inserts one .documentExpiry notification per admin
// per document, de-duplicated by entityId so it fires once per document.

func checkExpiringDocuments() async {
    guard subscribedNotificationsUserId != nil else { return }

    let adminIds = staff
        .filter { $0.role == .fleetManager && $0.status == .active }
        .map { $0.id }
    guard !adminIds.isEmpty else { return }

    let expiringDocs = vehicleDocuments.filter { $0.isExpiringSoon || $0.isExpired }
    guard !expiringDocs.isEmpty else { return }

    for doc in expiringDocs {
        // De-duplicate: skip if ANY admin already got a notification for this doc
        let alreadyNotified = notifications.contains {
            $0.type == .documentExpiry && $0.entityId == doc.id
        }
        guard !alreadyNotified else { continue }

        let vehicleName = vehicles.first { $0.id == doc.vehicleId }?.name ?? "Unknown vehicle"
        let statusLabel = doc.isExpired ? "EXPIRED" : "expiring soon"
        let expiryStr   = doc.expiryDate.formatted(.dateTime.day().month(.abbreviated).year())

        for adminId in adminIds {
            try? await NotificationService.insertNotification(
                recipientId: adminId,
                type: .documentExpiry,
                title: "Document \(statusLabel): \(doc.documentType.rawValue)",
                body: "\(vehicleName) — \(doc.documentType.rawValue) \(statusLabel). Expires \(expiryStr).",
                entityType: "vehicle_document",
                entityId: doc.id
            )
        }
    }
}
```

---

### Task 2 — Wire into `SierraApp.swift` foreground hook

In the `.active` scene phase case in `SierraApp.swift`, add the call alongside `checkOverdueMaintenance()`:

```swift
case .active:
    AuthManager.shared.appWillEnterForeground()
    Task { await AppDataStore.shared.checkOverdueMaintenance() }
    Task { await AppDataStore.shared.checkExpiringDocuments() }   // ← add this
```

---

### Task 3 — Postgres trigger for real-time alerting

Create `supabase/migrations/20260322000005_document_expiry_trigger.sql`:

```sql
-- ============================================================
-- Migration: Document expiry trigger
-- Fires when a vehicle_document row is inserted or when expiry_date is updated.
-- Notifies all fleet managers if the document expires within 30 days.
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
    v_status      TEXT;
    v_title       TEXT;
    v_body        TEXT;
BEGIN
    -- Only act if document expires within 30 days or is already expired
    IF NEW.expiry_date > NOW() + INTERVAL '30 days' THEN
        RETURN NEW;
    END IF;

    v_days_until := EXTRACT(DAY FROM (NEW.expiry_date - NOW()));

    SELECT COALESCE(name, 'Unknown Vehicle')
      INTO v_vehicle_name
      FROM public.vehicles
     WHERE id = NEW.vehicle_id;

    v_status := CASE
        WHEN NEW.expiry_date < NOW() THEN 'EXPIRED'
        WHEN v_days_until <= 7       THEN 'expires in ' || v_days_until || ' days'
        ELSE 'expiring soon'
    END;

    v_title := 'Document ' || v_status || ': ' || NEW.document_type;
    v_body  := v_vehicle_name || ' — ' || NEW.document_type
               || ' ' || v_status
               || '. Expiry: ' || TO_CHAR(NEW.expiry_date, 'DD Mon YYYY');

    -- Notify all fleet managers (using canonical role string from Fix A)
    FOR v_admin_id IN
        SELECT id FROM public.staff_members WHERE role = 'fleetManager'
    LOOP
        -- Only insert if no existing notification for this document already
        IF NOT EXISTS (
            SELECT 1 FROM public.notifications
             WHERE entity_type = 'vehicle_document'
               AND entity_id   = NEW.id::text
               AND recipient_id = v_admin_id::text
               AND type = 'Document Expiry'
        ) THEN
            INSERT INTO public.notifications
                (id, recipient_id, type, title, body, entity_type, entity_id, is_read, sent_at)
            VALUES
                (gen_random_uuid(), v_admin_id::text, 'Document Expiry',
                 v_title, v_body, 'vehicle_document', NEW.id::text, false, NOW());
        END IF;
    END LOOP;

    RETURN NEW;
END;
$$;

-- Attach to INSERT and UPDATE of expiry_date
DROP TRIGGER IF EXISTS trg_document_expiry_notification ON public.vehicle_documents;

CREATE TRIGGER trg_document_expiry_notification
    AFTER INSERT OR UPDATE OF expiry_date
    ON public.vehicle_documents
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_notify_document_expiry();
```

**Note:** This migration depends on Fix A being applied first (uses `role = 'fleetManager'`).

---

## Acceptance Criteria

- When the app comes to foreground, expired/expiring documents generate `.documentExpiry` notifications for all fleet managers
- Notifications are de-duplicated — a document that expired last week doesn't generate a new notification every time the app opens
- When a new `vehicle_document` row is inserted with `expiry_date < NOW() + 30 days`, the DB trigger fires and inserts notifications without requiring the app to be open
- The `DashboardHomeView` expiring docs section count matches what admins received notifications for
