# FMS_SS Driver Exact Frontend Code Reference

This folder contains verbatim frontend reference files copied from:

`/Users/kan/Downloads/FMS_SS 3/FMS_SS`

Purpose:
- Give Sierra a 1:1 frontend implementation reference.
- Preserve exact SwiftUI layout/styling code instead of abstract summaries.
- Keep the reference separated from Sierra production code so we can port intentionally.

Included visual source files:
- [AppTheme.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/AppTheme.swift)
- [MainTabBar.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/MainTabBar.swift)
- [ContentView.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ContentView.swift)
- [Tripsview.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/Tripsview.swift)
- [TripOverviewView.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/TripOverviewView.swift)
- [ActiveNavigationView.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ActiveNavigationView.swift)
- [Pretripinspectionview.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/Pretripinspectionview.swift)
- [StateComponents.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/Components/StateComponents.swift)

Supporting UI-state/reference files:
- [ViewState.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/Models/ViewState.swift)
- [TripsViewModel.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ViewModels/TripsViewModel.swift)
- [HomeViewModel.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ViewModels/HomeViewModel.swift)
- [TripOverviewViewModel.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ViewModels/TripOverviewViewModel.swift)
- [ActiveNavigationViewModel.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ViewModels/ActiveNavigationViewModel.swift)
- [PreTripInspectionViewModel.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/ViewModels/PreTripInspectionViewModel.swift)
- [AppRuntimeTestCases.swift](/Users/kan/Documents/Sierra/docs/FMS_SS_Driver_Exact_Code/Utils/AppRuntimeTestCases.swift)

Recommended Sierra porting order:
1. `AppTheme.swift`
2. `MainTabBar.swift`
3. `ContentView.swift`
4. `Tripsview.swift`
5. `TripOverviewView.swift`
6. `ActiveNavigationView.swift`
7. `Pretripinspectionview.swift`
8. shared helpers in `Components/`, `Models/`, and `ViewModels/`
