# Phase 4 — LoginView: Stabilise 2FA Routing via NavigationStack

---

## Context

You are working on the **Sierra Fleet Management System** iOS app (SwiftUI, MVVM, iOS 26+).  
This is an architectural routing fix to `Sierra/Auth/LoginView.swift`.

Do not change any UI styling — keep the dark navy gradient, frosted glass card, Sierra design  
tokens, SierraFont typography, and all visual layout exactly as-is. This is a routing-only change.

### What is being fixed

Currently, the 2FA screen (`TwoFactorView`) is presented as a z-index overlay on top of  
`LoginView` using `@State private var showTwoFactor = false` and a conditional `if` block  
with `.zIndex(100)` inside the root `ZStack`. This approach has known issues:

- It creates unpredictable interaction with the keyboard and `ScrollView` in `loginContentLayer`
- The transition animation (`.move(edge: .bottom).combined(with: .opacity)`) can glitch when  
  the keyboard is open during sign-in
- The overlay approach means `TwoFactorView` shares the `ZStack` context with the login  
  gradient, causing layering complexity
- When `TwoFactorView` dismisses itself (via `showTwoFactor = false`), the login form  
  underneath can flash briefly

**The fix:** Wrap `loginContentLayer` in a `NavigationStack` and present `TwoFactorView`  
via `navigationDestination` — exactly how standard iOS navigation works. This delegates  
the transition to the system's push animation, which is reliable, keyboard-aware, and  
respects the navigation bar that `TwoFactorView` now shows (after Phase 2).

---

## File — `Sierra/Auth/LoginView.swift`

### Current State (routing-related sections only)

```swift
struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showForgotPassword = false

    // 2FA overlay
    @State private var twoFactorContext: TwoFactorContext?
    @State private var twoFactorVM: TwoFactorViewModel?
    @State private var showTwoFactor = false

    // Dashboard
    @State private var resolvedDestination: AuthDestination?
    @State private var showDestination = false

    // Returning user — used to conditionally show Face ID button
    @State private var lastProfile: SecureSessionStore.StoredProfile?

    var body: some View {
        ZStack {
            // ── Login content layer ──
            loginContentLayer

            // ── 2FA overlay layer — covers everything when active ──
            if showTwoFactor, let vm = twoFactorVM {
                TwoFactorView(viewModel: vm)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showTwoFactor)
        .onAppear { ... }
        .fullScreenCover(isPresented: $showDestination) { ... }
        .sheet(isPresented: $showForgotPassword) { ... }
        .onChange(of: viewModel.authState) { _, newState in
            switch newState {
            case .requiresTwoFactor(let ctx):
                twoFactorContext = ctx
                twoFactorVM = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,
                    onVerified: { [self] in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showTwoFactor = false
                            twoFactorVM = nil
                            AuthManager.shared.completeAuthentication()
                            resolvedDestination = ctx.authDestination
                            showDestination = true
                        }
                    },
                    onCancelled: {
                        showTwoFactor = false
                        twoFactorContext = nil
                        twoFactorVM = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                showTwoFactor = true

            case .authenticated(let destination):
                resolvedDestination = destination
                showDestination = true

            case .error:
                break

            case .idle, .loading:
                break
            }
        }
    }
```

### Required Changes

**Step 1 — Replace the state variables for the 2FA overlay:**

Remove:
```swift
@State private var showTwoFactor = false
```

Add in its place (alongside the existing `twoFactorVM`):
```swift
@State private var navPath: [String] = []
```

The `navPath` drives the `NavigationStack`. We push a sentinel string `"2fa"` to trigger  
navigation to `TwoFactorView`.

**Step 2 — Wrap `loginContentLayer` in a `NavigationStack`:**

Replace the root `ZStack` body with:

```swift
var body: some View {
    NavigationStack(path: $navPath) {
        loginContentLayer
            .navigationDestination(for: String.self) { destination in
                if destination == "2fa", let vm = twoFactorVM {
                    TwoFactorView(viewModel: vm)
                }
            }
    }
    .onAppear { ... }              // keep all existing modifiers here
    .fullScreenCover(...) { ... }
    .sheet(...) { ... }
    .onChange(of: viewModel.authState) { ... }
}
```

**Step 3 — Update the `.requiresTwoFactor` arm of `onChange`:**

Replace:
```swift
UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
showTwoFactor = true
```

With:
```swift
UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
navPath.append("2fa")
```

**Step 4 — Update the `onCancelled` closure:**

Replace:
```swift
showTwoFactor = false
twoFactorContext = nil
twoFactorVM = nil
viewModel.twoFactorCancelled()
```

With:
```swift
navPath.removeAll()
twoFactorContext = nil
twoFactorVM = nil
viewModel.twoFactorCancelled()
```

**Step 5 — Update the `onVerified` closure:**

Replace:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    showTwoFactor = false
    twoFactorVM = nil
    AuthManager.shared.completeAuthentication()
    resolvedDestination = ctx.authDestination
    showDestination = true
}
```

With:
```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    navPath.removeAll()
    twoFactorVM = nil
    AuthManager.shared.completeAuthentication()
    resolvedDestination = ctx.authDestination
    showDestination = true
}
```

**Step 6 — Remove the ZStack 2FA overlay block entirely:**

Remove from the original outer ZStack:
```swift
// ── 2FA overlay layer — covers everything when active ──
if showTwoFactor, let vm = twoFactorVM {
    TwoFactorView(viewModel: vm)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(100)
}
```

And remove the animation modifier that depended on `showTwoFactor`:
```swift
.animation(.easeInOut(duration: 0.35), value: showTwoFactor)
```

---

## Complete Target State (routing-related sections)

```swift
struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var cardAppeared = false
    @State private var showForgotPassword = false

    // 2FA navigation
    @State private var twoFactorContext: TwoFactorContext?
    @State private var twoFactorVM: TwoFactorViewModel?
    @State private var navPath: [String] = []

    // Dashboard
    @State private var resolvedDestination: AuthDestination?
    @State private var showDestination = false

    // Returning user
    @State private var lastProfile: SecureSessionStore.StoredProfile?

    var body: some View {
        NavigationStack(path: $navPath) {
            loginContentLayer
                .navigationDestination(for: String.self) { destination in
                    if destination == "2fa", let vm = twoFactorVM {
                        TwoFactorView(viewModel: vm)
                    }
                }
        }
        .onAppear {
            lastProfile = SecureSessionStore.shared.loadLastProfile()
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                cardAppeared = true
            }
        }
        .fullScreenCover(isPresented: $showDestination) {
            if let dest = resolvedDestination {
                destinationView(for: dest)
                    .environment(AppDataStore.shared)
                    .environment(AuthManager.shared)
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: viewModel.authState) { _, newState in
            #if DEBUG
            print("👁 [LoginView.onChange] authState fired: \(newState)")
            #endif
            switch newState {
            case .requiresTwoFactor(let ctx):
                twoFactorContext = ctx
                twoFactorVM = TwoFactorViewModel(
                    context: ctx,
                    service: viewModel.otpService,
                    onVerified: { [self] in
                        #if DEBUG
                        print("🔐 [LoginView.onVerified] 2FA verified — completing auth")
                        #endif
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navPath.removeAll()
                            twoFactorVM = nil
                            AuthManager.shared.completeAuthentication()
                            resolvedDestination = ctx.authDestination
                            showDestination = true
                        }
                    },
                    onCancelled: {
                        navPath.removeAll()
                        twoFactorContext = nil
                        twoFactorVM = nil
                        viewModel.twoFactorCancelled()
                    }
                )
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                navPath.append("2fa")

            case .authenticated(let destination):
                resolvedDestination = destination
                showDestination = true

            case .error:
                break

            case .idle, .loading:
                break
            }
        }
    }

    // loginContentLayer, loginCard, headerSection, errorBanner,
    // inlineError, loadingOverlay, destinationView — ALL UNCHANGED
}
```

---

## Navigation Bar Styling

With `NavigationStack` now wrapping the login screen, the nav bar will appear on `LoginView`  
itself (even though there's nothing to go back to). To hide it on the root login screen only,  
add this modifier to `loginContentLayer`'s inner most container **or** the `NavigationStack`:

```swift
.toolbar(.hidden, for: .navigationBar)
```

Place it on `loginContentLayer` view so it only hides on the root, and `TwoFactorView`  
(the pushed destination) can show its own nav bar with the back button.

**Specifically:** inside `loginContentLayer`, on the outermost `ZStack`, add:
```swift
.toolbar(.hidden, for: .navigationBar)
```

---

## Do NOT Change

- `loginContentLayer` visual structure (gradient, card, fields, buttons, header)
- `loginCard`, `headerSection`, `errorBanner`, `inlineError`, `loadingOverlay`
- `destinationView(for:)` routing switch
- `LoginViewModel` and `LoginViewModel.authState`
- Any other file outside `LoginView.swift`

---

## Success Criteria

- [ ] `LoginView` is wrapped in a `NavigationStack`
- [ ] 2FA screen is pushed via `navigationDestination`, not z-index overlay
- [ ] Nav bar is hidden on the root `LoginView` but visible on the pushed `TwoFactorView`
- [ ] Back navigation from `TwoFactorView` calls `navPath.removeAll()` via `onCancelled`
- [ ] Dark gradient login UI — visually identical to before
- [ ] `TwoFactorView` shows native back button (from Phase 2)
- [ ] App compiles with zero errors
- [ ] Full auth flow works: login → 2FA push → verify → dashboard `fullScreenCover`
