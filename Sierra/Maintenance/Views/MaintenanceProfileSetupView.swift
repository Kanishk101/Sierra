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
        .background(Color.appSurface.ignoresSafeArea())
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
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(1.0)
                Spacer()
                Text("Step \(viewModel.currentStep) of 2")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.appOrange)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appDivider.opacity(0.7))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.appOrange)
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
        .background(
            Color.appCardBg
                .overlay(Rectangle().fill(Color.appDivider.opacity(0.5)).frame(height: 1), alignment: .bottom)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile setup progress: step \(viewModel.currentStep) of 2")
    }
}

#Preview {
    MaintenanceProfileSetupView()
}
