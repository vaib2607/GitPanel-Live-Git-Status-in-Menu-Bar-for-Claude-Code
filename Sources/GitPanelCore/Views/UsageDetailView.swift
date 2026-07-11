import SwiftUI

struct UsageDetailView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            
            switch viewModel.usageState {
            case .idle:
                Color.clear.onAppear {
                    Task { await viewModel.refresh() }
                }
            case .loading:
                VStack {
                    Spacer()
                    ProgressView("Loading plan usage...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorRecoveryView(
                    error: error,
                    retryAction: { Task { await viewModel.refresh() } }
                )
            case .loaded(let usage, _):
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tokens used: \(usage.tokens)")
                        .font(.system(size: 14))
                    Text("Plan: \(usage.plan.isEmpty ? "Free" : usage.plan)")
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
            case .empty(let reason), .unavailable(let reason):
                VStack {
                    Spacer()
                    Text(reason)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
