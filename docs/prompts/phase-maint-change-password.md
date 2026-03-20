# Phase: Maintenance Staff Change Password

## Context
Sierra FMS — iOS 17+, SwiftUI, MVVM, @Observable, no @Published.
GitHub: Kanishk101/Sierra  |  Branch: main  |  Jira: FMS1-70

## Problem
`MaintenanceDashboardView.swift` Profile tab has only a Sign Out button.
There is no way for a maintenance staff member to change their password after
onboarding, despite `ChangePasswordView.swift` already existing in `Sierra/Auth/`.

## Scope
Add a "Change Password" button to the Profile tab in `MaintenanceDashboardView.swift`.

### Change
In the `profileTab` computed view, between the approval status card and the Sign Out
button, add:

```swift
NavigationLink {
    ChangePasswordView()
} label: {
    HStack(spacing: 8) {
        Image(systemName: "lock.rotation")
        Text("Change Password")
    }
    .font(.subheadline)
    .foregroundStyle(.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: 48)
    .padding(.horizontal, 16)
    .background(Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14))
}
.padding(.horizontal, 24)
```

The profile tab is already inside a `NavigationStack` so this link works without
any additional navigation wiring.

## Constraints
- Only modify `MaintenanceDashboardView.swift`.
- Do NOT change `ChangePasswordView.swift`.
- Do NOT alter any other tab or the tasks list.
- No new files.
