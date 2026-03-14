# Sierra — Email Setup Guide

## Option A: Supabase Built-in Email (Dev only — 4 emails/hour limit)

No extra setup required. Just make sure user accounts use real email addresses.

**Steps:**
1. Go to **Supabase Dashboard → Authentication → Users**
2. Find `fleetmanager@sierra.com` → **Edit** → change email to your actual address (e.g. `kanishk@youremail.com`)
3. Run this SQL to keep the `staff_members` table in sync:

```sql
UPDATE staff_members
SET email = 'kanishk@youremail.com'
WHERE id = '70c3213c-25ad-49e2-b175-f53dd5d00271';
```

---

## Option B: Resend (Production — 3,000 emails/month free)

1. Sign up at [https://resend.com](https://resend.com)
2. Add and verify your domain (e.g. `sierra.app` or your custom domain)
3. Create an API key in the Resend dashboard

4. Go to **Supabase Dashboard → Project Settings → Authentication → SMTP Settings**:
   - Enable custom SMTP: ✅
   - Host: `smtp.resend.com`
   - Port: `465`
   - Username: `resend`
   - Password: `[your Resend API key]`
   - Sender email: `noreply@yourdomain.com`
   - Sender name: `Sierra Fleet`

5. Test by triggering a password reset from the app.

---

## Email Templates

Go to **Supabase Dashboard → Authentication → Email Templates** to customise:
- Confirm signup
- Magic Link / OTP
- Change email
- Reset password

**Recommended OTP subject:** `Sierra — Your verification code`

**Recommended OTP body:**
```
Your Sierra Fleet verification code is: {{ .Token }}

This code expires in 10 minutes.
```

---

## Staff Application Notifications (Edge Function)

The `supabase/functions/notify-fleet-manager/` Edge Function fires when a new staff
application is submitted. It requires Resend to be configured.

**Deploy:**
```bash
supabase functions deploy notify-fleet-manager
```

**Set secrets:**
```bash
supabase secrets set \
  RESEND_API_KEY=re_xxxxxxxxxxxx \
  FLEET_MANAGER_EMAIL=admin@yourdomain.com \
  FROM_EMAIL=noreply@yourdomain.com
```

> **Note:** If `RESEND_API_KEY` is not set, the function returns `{"sent":false,"reason":"no_api_key"}` silently. The app continues normally regardless.
