import SwiftUI

struct CostDetailView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Breakdown")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            PanelDivider()
            
            switch viewModel.usageState {
            case .idle:
                Color.clear.onAppear {
                    Task { await viewModel.refresh() }
                }
            case .loading:
                VStack {
                    Spacer()
                    ProgressView("Loading cost data...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                ErrorRecoveryView(
                    error: error,
                    retryAction: { Task { await viewModel.refresh() } }
                )
            case .loaded(let usage, _):
                loadedContentView(usage: usage)
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
    
    @ViewBuilder
    private func loadedContentView(usage: UsageData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(format: "Total Cost: $%.2f", usage.cost))
                .font(.system(size: 14))
            
            if !usage.modelBreakdown.isEmpty {
                Text("By Model:")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.top, 8)
                
                ForEach(Array(usage.modelBreakdown.keys.sorted()), id: \.self) { model in
                    if let cost = usage.modelBreakdown[model] {
                        HStack {
                            Text(model)
                                .font(.system(size: 12))
                            Spacer()
                            Text(String(format: "$%.4f", cost))
                                .font(.system(size: 12))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
