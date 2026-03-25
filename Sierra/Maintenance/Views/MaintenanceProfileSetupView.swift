import SwiftUI

struct MaintenanceProfileSetupView: View {
    @State private var viewModel = MaintenanceProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator

            Group {
                if viewModel.currentStep == 1 {
                    MaintenanceProfilePage1View(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    MaintenanceProfilePage2View(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.1), value: viewModel.currentStep)
        }
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $viewModel.profileSubmitted) {
            MaintenanceApplicationSubmittedView()
        }
    }

    private var stepIndicator: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Maintenance Setup")
                    .font(SierraFont.caption1.weight(.bold))
                    .foregroundStyle(SierraTheme.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                Text("Step \(viewModel.currentStep) of 2")
                    .font(SierraFont.caption1.weight(.semibold))
                    .foregroundStyle(SierraTheme.Colors.ember)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SierraTheme.Colors.cloud.opacity(0.4))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(SierraTheme.Colors.ember)
                        .frame(
                            width: geo.size.width * (CGFloat(viewModel.currentStep) / 2.0),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(SierraTheme.Colors.appBackground)
        .sierraShadow(SierraShadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile setup progress: step \(viewModel.currentStep) of 2")
    }
}

#Preview {
    MaintenanceProfileSetupView()
}
