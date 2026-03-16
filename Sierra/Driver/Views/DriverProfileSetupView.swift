import SwiftUI

struct DriverProfileSetupView: View {
    @State private var viewModel = DriverProfileViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            stepIndicator

            // Page content
            Group {
                if viewModel.currentStep == 1 {
                    DriverProfilePage1View(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    DriverProfilePage2View(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $viewModel.profileSubmitted) {
            DriverApplicationSubmittedView()
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(spacing: 10) {
            Text("Step \(viewModel.currentStep) of 2")
                .font(.caption)
                .foregroundStyle(.primary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
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
        .background(Color(.systemBackground))
    }
}

#Preview {
    DriverProfileSetupView()
}
