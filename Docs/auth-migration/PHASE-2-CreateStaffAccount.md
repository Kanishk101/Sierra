# Phase 2 — `create-staff-account` Edge Function + `StaffMemberService.swift`

> **Depends on:** Phase 1 complete and building.

---

## Context

`create-staff-account` already calls `adminClient.auth.admin.createUser()` correctly.
But its `staff_members` insert payload **must not include a `password` field** —
the column is gone and PostgREST will return a 400 if you send it.

`StaffMemberService.swift` may reference `password` in selects or updates.
All such references must be removed.

---

## Exact prompt — paste into Cursor

```
Update the create-staff-account Supabase edge function and
StaffMemberService.swift to remove all references to the dropped
staff_members.password column.

Context:
  - staff_members.password has been DROPPED from the database.
  - Sending `password` in any PostgREST insert/update/select against
    staff_members will cause a 400 error.
  - Supabase Auth handles credentials. create-staff-account already calls
    adminClient.auth.admin.createUser({ email, password, email_confirm: true })
    which is correct and must NOT be changed.

────────────────────────────────────────────────
PART A: supabase/functions/create-staff-account/index.ts
────────────────────────────────────────────────

Find the adminClient.from("staff_members").insert({...}) call.

REMOVE the `password` key-value pair from the insert object entirely.
Do NOT change the auth.admin.createUser() call above it — that uses the
password correctly to create the Supabase Auth entry.

The insert object must contain only these fields
(keep any extras that are NOT the password column):
  id, name, email, role, status, availability,
  is_first_login, is_profile_complete, is_approved

────────────────────────────────────────────────
PART B: Sierra/Shared/Services/StaffMemberService.swift
────────────────────────────────────────────────

Search the entire file for the string "password" used as a database column
in .select(), .update(), .insert(), or .eq() calls against staff_members.

For each match apply the fix:
  .select("..., password, ...")     → remove "password" from the string
  .update({..., password: ..., ...}) → remove only the password key-value
  .update(["password": ...])        → remove the entire call if password is
                                       the only key; remove just that key if not
  .insert({..., password: ..., ...}) → remove only the password key-value
  .eq("password", ...)              → remove this entire filter

Do NOT touch any of these (they are correct Auth SDK calls):
  supabase.auth.update(user: UserAttributes(password:))
  supabase.auth.signInWithPassword(...)
  CryptoService.hash(password:)
  KeychainService.save(hashed, ...)

After changes, grep for the literal string "password" in StaffMemberService.swift
and confirm every remaining occurrence is one of the Auth SDK calls above.
```

---

## Build verification

- [ ] Build succeeds — zero errors
- [ ] `create-staff-account` insert object has no `password` key
- [ ] `StaffMemberService.swift` has no `.select`/`.update`/`.insert` with `"password"` against staff_members
- [ ] Creating a new staff member from the Fleet Manager UI succeeds (no 400 from PostgREST)
- [ ] The new user can log in with the password the admin set at creation time
