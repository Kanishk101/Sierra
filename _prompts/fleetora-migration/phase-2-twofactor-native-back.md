# Phase 2 — TwoFactorView: Native Navigation Back Button

---

## Context

You are working on the **Sierra Fleet Management System** iOS app (SwiftUI, MVVM, iOS 26+).  
This is a targeted, surgical UI/UX fix to a single file: `Sierra/Auth/TwoFactorView.swift`.  
Do not touch any other file. Do not change any colors, fonts, card styles, or gradients.

### What is being fixed

Currently, `TwoFactorView` hides the system navigation bar back button and renders a custom  
"← Back to Sign In" text button pinned to the bottom of the scroll view. This is non-standard  
iOS UX — it sits awkwardly below the card, is easy to miss, and fights against native navigation.

The fix is to:
1. **Show the native navigation bar back button** instead of hiding it.
2. **Remove the custom `cancelButton`** view and its call site in the scroll view.
3. **Remove the floating `SierraAlertBanner` overlay** — this is handled elsewhere and  
   causes z-index layering issues when TwoFactorView is presented as a push destination.
4. Keep `interactiveDismissDisabled(true)` — we still block swipe-to-dismiss from sheets.
5. Keep `toolbarBackground(.hidden, for: .navigationBar)` **commented out or removed** —  
   we want the nav bar to be visible so the back button shows up.

---

## File — `Sierra/Auth/TwoFactorView.swift`

### Current State (your file, relevant sections)

```swift
var body: some View {
    ZStack {
        LinearGradient(
            colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    headerSection.padding(.bottom, 32)

                    if viewModel.isLockedOut {
                        lockedCard
                            .padding(.horizontal, Spacing.xl)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        otpCard
                            .padding(.horizontal, Spacing.xl)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer(minLength: 40)
                    cancelButton.padding(.bottom, 32)   // ← REMOVE THIS LINE
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        if viewModel.isLoading { loadingOverlay }

        // ← REMOVE THIS ENTIRE BLOCK (lines below)
        VStack {
            if let banner = viewModel.banner {
                SierraAlertBanner(alertType: banner)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { viewModel.banner = nil }
            }
            Spacer()
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: viewModel.banner)
        .zIndex(10)
        // ← END REMOVE BLOCK
    }
    .interactiveDismissDisabled(true)
    .navigationBarBackButtonHidden(true)   // ← CHANGE TO: .navigationBarBackButtonHidden(false)
    .onAppear {
        #if DEBUG
        print("🔐 [TwoFactorView] appeared")
        #endif
        viewModel.onAppear()
    }
}
```

```swift
// MARK: - Cancel  ← REMOVE THIS ENTIRE SECTION

private var cancelButton: some View {
    Button { viewModel.cancelAndGoBack() } label: {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "arrow.left").font(SierraFont.caption1)
            Text("Back to Sign In").font(SierraFont.subheadline)
        }
        .foregroundStyle(.white.opacity(0.5))
    }
}
```

### Required Changes — Precise Instructions

**Change 1:** In the scroll view `VStack`, remove the line:
```swift
cancelButton.padding(.bottom, 32)
```
Replace the `Spacer(minLength: 40)` that preceded it with `Spacer(minLength: 48)` to compensate  
for the removed bottom element.

**Change 2:** Remove the entire `VStack { if let banner = viewModel.banner { ... } }` block  
and its `.animation` and `.zIndex` modifiers from the outer `ZStack`.

**Change 3:** Change:
```swift
.navigationBarBackButtonHidden(true)
```
To:
```swift
.navigationBarBackButtonHidden(false)
```

**Change 4:** Remove the `cancelButton` computed property entirely (the whole MARK section).

**Do NOT change:** gradients, card styles, OTP input, fonts, colors, spacing tokens, loading  
overlay, resend section, locked card, expiry row, or any ViewModel interactions.

### Target State (body only, for reference)

```swift
var body: some View {
    ZStack {
        LinearGradient(
            colors: [SierraTheme.Colors.summitNavy, SierraTheme.Colors.sierraBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    headerSection.padding(.bottom, 32)

                    if viewModel.isLockedOut {
                        lockedCard
                            .padding(.horizontal, Spacing.xl)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        otpCard
                            .padding(.horizontal, Spacing.xl)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    Spacer(minLength: 48)
                }
                .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }

        if viewModel.isLoading { loadingOverlay }
    }
    .interactiveDismissDisabled(true)
    .navigationBarBackButtonHidden(false)
    .onAppear {
        #if DEBUG
        print("🔐 [TwoFactorView] appeared")
        #endif
        viewModel.onAppear()
    }
}
```

---

## ViewModel Consideration

With the custom cancel button removed, the `viewModel.cancelAndGoBack()` call is no longer  
called from within TwoFactorView directly. The native back button handles dismissal.

However, check `TwoFactorViewModel.swift` — if `cancelAndGoBack()` is defined there,  
**do not remove it from the ViewModel** as it may still be called by `onCancelled` closures  
passed from `LoginView`, `ForcePasswordChangeView`, etc.

Also check whether `viewModel.banner` is still referenced anywhere in TwoFactorView after  
this change — if the only consumer was the removed banner block, you can safely remove  
the `banner` property usage from this file (but NOT from the ViewModel itself).

---

## Success Criteria

- [ ] `TwoFactorView` no longer has a custom bottom cancel button
- [ ] `TwoFactorView` shows the native iOS nav bar back button
- [ ] The floating `SierraAlertBanner` overlay is removed from `TwoFactorView`
- [ ] Dark gradient background, frosted glass card, OTP input, all Sierra tokens — unchanged
- [ ] App compiles with zero errors and zero new warnings
- [ ] Back navigation to `LoginView` works via the native back button
