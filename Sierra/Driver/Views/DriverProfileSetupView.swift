import SwiftUI

private let navyDark = Color(hex: "0D1B2A")
private let accentOrange = Color(red: 1.0, green: 0.584, blue: 0.0)

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
        .background(Color(hex: "F2F3F7").ignoresSafeArea())
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(navyDark)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(navyDark.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(accentOrange)
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
    DriverProfileSetupView()
}
