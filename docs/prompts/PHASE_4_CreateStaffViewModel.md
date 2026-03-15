# Phase 4 — CreateStaffViewModel.swift (Vinayak Two-Step Insert)

## File
`Sierra/FleetManager/ViewModels/CreateStaffViewModel.swift`

## What to implement

Exact vinayak pattern adapted for v2 schema:
1. Generate UUID client-side
2. Build `StaffMember` with all v2 fields
3. Call `StaffMemberService.addStaffMember(staff, password: tempPassword)` — single insert
4. Call `EmailService.sendCredentials(to:name:password:role:)` via SwiftSMTP
5. No `AuthManager.createStaffAccount()` call
6. No `AuthUserService` call
7. No RPC call

---

## Full `createStaff()` implementation

```swift
@MainActor
func createStaff() async {
    guard canSubmit, let role = selectedRole else { return }

    isLoading = true
    errorMessage = nil

    let tempPassword = generateTemporaryPassword()
    let trimmedName  = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    let newId        = UUID()
    let now          = Date()

    do {
        // Step 1: Build StaffMember with all v2 fields
        let newStaff = StaffMember(
            id:                    newId,
            name:                  trimmedName,
            role:                  role,               // UserRole directly — no StaffRole mapping
            status:                .pendingApproval,   // NOT .active — approval flow required
            email:                 trimmedEmail,
            phone:                 nil,
            availability:          .unavailable,
            dateOfBirth:           nil,
            gender:                nil,
            address:               nil,
            emergencyContactName:  nil,
            emergencyContactPhone: nil,
            aadhaarNumber:         nil,
            profilePhotoUrl:       nil,
            isFirstLogin:          true,
            isProfileComplete:     false,
            isApproved:            false,
            rejectionReason:       nil,
            joinedDate:            now,
            createdAt:             now,
            updatedAt:             now
        )

        // Step 2: Insert into staff_members with password column
        try await StaffMemberService.addStaffMember(newStaff, password: tempPassword)

        // Step 3: Email credentials via SwiftSMTP
        try await EmailService.sendCredentials(
            to:       trimmedEmail,
            name:     trimmedName,
            password: tempPassword,
            role:     role
        )

        isLoading        = false
        createdStaffName = trimmedName
        showSuccess      = true
        successMessage   = "Account created for \(trimmedName)"

        NotificationCenter.default.post(
            name: .staffCreated,
            object: nil,
            userInfo: ["name": trimmedName, "email": trimmedEmail, "role": role.rawValue]
        )
    } catch {
        isLoading     = false
        errorMessage  = "Failed to create staff account. Please try again."
    }
}
```

---

## Keep from vinayak
- `selectedRole: UserRole?` (not `StaffRole`) — no mapping line needed
- `generateTemporaryPassword()` — identical to vinayak
- `isValidEmail()` — identical
- `reset()` — identical
- `Notification.Name.staffCreated` extension
- All validation computed vars (`canSubmit`, `nameError`, `emailError`)

## Remove
- Any reference to `AuthManager.createStaffAccount()`
- Any reference to `AuthUserService`
- `StaffRole` mapping line (`let staffRole: StaffRole = ...`)
- `isApproved: true` — it must be `false`

## `EmailService.sendCredentials` signature expected
```swift
static func sendCredentials(
    to email: String,
    name: String,
    password: String,
    role: UserRole
) async throws
```
Verify `EmailService.swift` matches this. If it uses SwiftSMTP it will work.
The call must NOT be `try await` if `EmailService` wraps a fire-and-forget
`smtp.send()` — check the current implementation and match accordingly.
