# Phase 2 — AuthManager.swift (Vinayak Auth Pattern)

## File
`Sierra/Auth/AuthManager.swift`

## What to implement

Rewrite `AuthManager` to use the exact vinayak pattern:
query `staff_members` directly for all auth operations.
No `supabase.auth.signIn()`, no `supabase.auth.update()`,
no `supabase.auth.resetPasswordForEmail()` — none of the Supabase Auth SDK.
All operations are plain `.from("staff_members")` table queries.

---

## `signIn(email:password:)` — rewrite

Vinayak pattern: query `staff_members` by email, compare `password` column directly.

```swift
func signIn(email: String, password: String) async throws -> UserRole {
    let rows: [StaffMemberDB] = try await supabase
        .from("staff_members")
        .select()
        .eq("email", value: email)
        .limit(1)
        .execute()
        .value

    guard let row = rows.first else {
        throw AuthError.invalidCredentials
    }

    guard row.password == password else {
        throw AuthError.invalidCredentials
    }

    let user = AuthUser(
        id: row.id,
        email: row.email,
        role: UserRole(rawValue: row.role) ?? .driver,
        isFirstLogin: row.is_first_login ?? true,
        isProfileComplete: row.is_profile_complete ?? false,
        isApproved: row.is_approved ?? false,
        name: row.name,
        rejectionReason: row.rejection_reason,
        phone: row.phone,
        createdAt: ISO8601DateFormatter().date(from: row.created_at ?? "") ?? Date()
    )

    let hashed = CryptoService.hash(password: password)
    _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
    _ = KeychainService.save(user, forKey: Keys.currentUser)

    currentUser = user
    pendingOTPEmail = user.email
    // NOTE: Do NOT set isAuthenticated here — 2FA must complete first
    return user.role
}
```

`StaffMemberDB` is defined in `StaffMemberService.swift` (Phase 3).
It must include `password: String`, `is_first_login: Bool?`,
`is_profile_complete: Bool?`, `is_approved: Bool?`, `rejection_reason: String?`,
`phone: String?`, `created_at: String?`.

---

## `updatePasswordAndFirstLogin(newPassword:)` — rewrite

Vinayak pattern: update `staff_members.password` and `is_first_login` directly.

```swift
func updatePasswordAndFirstLogin(newPassword: String) async throws {
    guard var user = currentUser else { throw AuthError.invalidCredentials }

    struct Payload: Encodable {
        let password: String
        let is_first_login: Bool
    }

    try await supabase
        .from("staff_members")
        .update(Payload(password: newPassword, is_first_login: false))
        .eq("id", value: user.id.uuidString)
        .execute()

    user.isFirstLogin = false
    currentUser = user
    _ = KeychainService.save(user, forKey: Keys.currentUser)

    let hashed = CryptoService.hash(password: newPassword)
    _ = KeychainService.save(hashed, forKey: Keys.hashedCred)
}
```

---

## `requestPasswordReset(email:)` — rewrite

Vinayak pattern: query `staff_members` for email existence,
generate OTP in-memory, send via `sendEmail()` SwiftSMTP.

```swift
func requestPasswordReset(email: String) async -> Bool {
    do {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value

        guard !rows.isEmpty else { return false }

        pendingOTPEmail = email
        let otp = String(format: "%06d", Int.random(in: 100000...999999))
        resetOTP = otp
        sendEmail(userEmail: email, otp: otp)
        return true
    } catch {
        return false
    }
}
```

---

## `resetPassword(code:newPassword:)` — rewrite

Vinayak pattern: verify OTP in-memory, then update `staff_members.password` directly.

```swift
func resetPassword(code: String, newPassword: String) async throws {
    try await Task.sleep(for: .milliseconds(600))
    guard code == resetOTP else { throw AuthError.invalidCredentials }
    guard let email = pendingOTPEmail else { throw AuthError.invalidCredentials }

    try await supabase
        .from("staff_members")
        .update(["password": newPassword])
        .eq("email", value: email)
        .execute()

    let hashed = CryptoService.hash(password: newPassword)
    _ = KeychainService.save(hashed, forKey: Keys.hashedCred)

    resetOTP = ""
    pendingOTPEmail = nil
}
```

---

## `generateOTP()` — keep as-is + ensure `sendEmail()` is called

```swift
@discardableResult
func generateOTP() -> String {
    let otp = String(format: "%06d", Int.random(in: 100000...999999))
    currentOTP = otp
    pendingOTPEmail = currentUser?.email
    if let email = pendingOTPEmail {
        sendEmail(userEmail: email, otp: otp)
    }
    return otp
}
```

---

## `completeAuthentication()` — simplify

Remove the `saveToken` parameter and `AppDataStore.shared.load*()` calls from here.
Keep it simple — just set `isAuthenticated = true`.
`AppDataStore` loading is triggered separately from the view layer after navigation.

```swift
func completeAuthentication() {
    isAuthenticated = true
}
```

---

## `emailExists(_:)` — rewrite

```swift
func emailExists(_ email: String) async -> Bool {
    do {
        let rows: [StaffMemberDB] = try await supabase
            .from("staff_members")
            .select()
            .eq("email", value: email)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    } catch { return false }
}
```

---

## Remove entirely
- `createStaffAccount()` — staff creation is now entirely in `CreateStaffViewModel`
- Any `supabase.auth.*` import or call
- The `saveToken` parameter from `completeAuthentication()`

## Keep as-is
- `verifyOTP(_:)` — string compare, no changes needed
- `verifyResetOTP(_:)` — string compare, no changes needed
- `maskedEmail` computed var
- `markProfileComplete()`, `markPasswordChanged()`, `refreshCurrentUser()`
  — these already use `.from("staff_members")` and are correct
- `signOut()`, `restoreSession()`, `destination(for:)`, auto-lock methods
- `AuthError` enum — add `.userNotFound` if not present

## State vars to add
```swift
private var resetOTP: String = ""
```
(separate from `currentOTP` which is for 2FA login OTP)
