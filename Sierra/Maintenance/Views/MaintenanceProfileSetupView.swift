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
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        }
        .background(SierraTheme.Colors.appBackground.ignoresSafeArea())
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $viewModel.profileSubmitted) {
            MaintenanceApplicationSubmittedView()
        }
    }

    private var stepIndicator: some View {
        VStack(spacing: 10) {
            Text("Step \(viewModel.currentStep) of 2")
                .font(SierraFont.caption1)
                .foregroundStyle(SierraTheme.Colors.primaryText)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SierraTheme.Colors.sierraBlue.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(SierraTheme.Colors.ember)
                        .frame(
                            width: geo.size.width * (CGFloat(viewModel.currentStep) / 2.0),
                            height: 6
                        )
                        .animation(.spring(duration: 0.4, bounce: 0.15), value: viewModel.currentStep)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(.white)
    }
}

#Preview {
    MaintenanceProfileSetupView()
}
