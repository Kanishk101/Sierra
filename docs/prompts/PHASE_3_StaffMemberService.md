# Phase 3 — StaffMemberService.swift (V2 Schema + Password Column)

## File
`Sierra/Shared/Services/StaffMemberService.swift`

## What to implement

Adapt the vinayak `StaffMemberService` + `StaffMemberDB` pattern
to the v2 schema. Key changes:
1. `StaffMemberInsertPayload` must include the `password` column
2. `StaffMemberDB` must include all v2 columns including `password`
3. The mapper `toStaffMember()` / `toAuthUser()` must map all v2 fields
4. Keep all existing v2 service methods (`setApprovalStatus`, `markProfileComplete`, etc.)

---

## `StaffMemberInsertPayload` — full v2 payload WITH password

```swift
struct StaffMemberInsertPayload: Encodable {
    let id: String
    let name: String?
    let role: String
    let status: String
    let email: String
    let password: String          // NEW — vinayak pattern
    let phone: String?
    let availability: String
    let is_first_login: Bool
    let is_profile_complete: Bool
    let is_approved: Bool
    let rejection_reason: String?
    let date_of_birth: String?    // ISO8601 date string or nil
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?       // ISO8601 timestamp string or nil

    init(from s: StaffMember, password: String = "") {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateIso = ISO8601DateFormatter()
        dateIso.formatOptions = [.withFullDate]

        self.id                    = s.id.uuidString
        self.name                  = s.name
        self.role                  = s.role.rawValue
        self.status                = s.status.rawValue
        self.email                 = s.email
        self.password              = password
        self.phone                 = s.phone
        self.availability          = s.availability.rawValue
        self.is_first_login        = s.isFirstLogin
        self.is_profile_complete   = s.isProfileComplete
        self.is_approved           = s.isApproved
        self.rejection_reason      = s.rejectionReason
        self.date_of_birth         = s.dateOfBirth.map { dateIso.string(from: $0) }
        self.gender                = s.gender
        self.address               = s.address
        self.emergency_contact_name  = s.emergencyContactName
        self.emergency_contact_phone = s.emergencyContactPhone
        self.aadhaar_number        = s.aadhaarNumber
        self.profile_photo_url     = s.profilePhotoUrl
        self.joined_date           = s.joinedDate.map { iso.string(from: $0) }
    }
}
```

---

## `StaffMemberUpdatePayload` — same as insert but without `id` and `password`

Update payload used for profile updates, approval status, etc.
Password is updated separately via a dedicated payload in `AuthManager`.

```swift
struct StaffMemberUpdatePayload: Encodable {
    let name: String?
    let role: String
    let status: String
    let email: String
    let phone: String?
    let availability: String
    let is_first_login: Bool
    let is_profile_complete: Bool
    let is_approved: Bool
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?

    init(from s: StaffMember) {
        // same as insert minus id, password, joined_date
    }
}
```

---

## `StaffMemberDB` — full v2 decode struct WITH password

```swift
struct StaffMemberDB: Decodable {
    let id: UUID
    let name: String?
    let role: String
    let status: String
    let email: String
    let password: String           // NEW
    let phone: String?
    let availability: String
    let is_first_login: Bool?
    let is_profile_complete: Bool?
    let is_approved: Bool?
    let rejection_reason: String?
    let date_of_birth: String?
    let gender: String?
    let address: String?
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let aadhaar_number: String?
    let profile_photo_url: String?
    let joined_date: String?
    let created_at: String?
    let updated_at: String?
}
```

---

## `StaffMemberDB` mapper — `toStaffMember()` and `toAuthUser()`

```swift
extension StaffMemberDB {
    func toStaffMember() -> StaffMember {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateIso = ISO8601DateFormatter()
        dateIso.formatOptions = [.withFullDate]

        return StaffMember(
            id: id,
            name: name,
            role: UserRole(rawValue: role) ?? .driver,
            status: StaffStatus(rawValue: status) ?? .pendingApproval,
            email: email,
            phone: phone,
            availability: StaffAvailability(rawValue: availability) ?? .unavailable,
            dateOfBirth: dateIso.date(from: date_of_birth ?? ""),
            gender: gender,
            address: address,
            emergencyContactName: emergency_contact_name,
            emergencyContactPhone: emergency_contact_phone,
            aadhaarNumber: aadhaar_number,
            profilePhotoUrl: profile_photo_url,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            rejectionReason: rejection_reason,
            joinedDate: iso.date(from: joined_date ?? ""),
            createdAt: iso.date(from: created_at ?? "") ?? Date(),
            updatedAt: iso.date(from: updated_at ?? "") ?? Date()
        )
    }

    func toAuthUser() -> AuthUser {
        AuthUser(
            id: id,
            email: email,
            role: UserRole(rawValue: role) ?? .driver,
            isFirstLogin: is_first_login ?? true,
            isProfileComplete: is_profile_complete ?? false,
            isApproved: is_approved ?? false,
            name: name,
            rejectionReason: rejection_reason,
            phone: phone,
            createdAt: ISO8601DateFormatter().date(from: created_at ?? "") ?? Date()
        )
    }
}
```

---

## Service methods — update signatures

### `addStaffMember(_:password:)` — add password parameter
```swift
static func addStaffMember(_ staff: StaffMember, password: String) async throws {
    try await supabase
        .from("staff_members")
        .insert(StaffMemberInsertPayload(from: staff, password: password))
        .execute()
}
```

### Keep all existing methods unchanged:
- `updateStaffMember(_:)`
- `fetchAllStaffMembers()`
- `fetchStaffMembers(role:)`
- `fetchAvailableDrivers()`
- `deleteStaffMember(id:)`
- `setApprovalStatus(staffId:approved:rejectionReason:)`
- `markProfileComplete(staffId:name:phone:gender:dateOfBirth:address:emergencyContactName:emergencyContactPhone:aadhaarNumber:)`
