import SwiftUI
import Charts

struct AgentDashboardView: View {
    @Environment(AppRouter.self) var router: AppRouter
    let providerName: String
    let isPro: Bool
    let color: Color
    @Bindable var viewModel: GitPanelViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(providerName)
                            .font(.system(size: 16, weight: .bold))
                        Text("Usage updated based on logs")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(isPro ? "Pro" : "Free")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                PanelDivider()
                
                // Session Progress
                // Session Progress
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Usage")
                        .font(.system(size: 14, weight: .bold))
                    
                    switch viewModel.usageState {
                    case .idle:
                        Color.clear.onAppear { Task { await viewModel.refresh() } }
                    case .loading:
                        ProgressView("Loading usage...")
                            .frame(maxWidth: .infinity, alignment: .center)
                    case .failed(let error):
                        ErrorRecoveryView(
                            error: error,
                            retryAction: { Task { await viewModel.refresh() } }
                        )
                    case .loaded(let usage, _):
                        let cost = usage.modelBreakdown.filter { $0.key.lowercased().contains(providerName.lowercased()) }.values.reduce(0, +)
                        
                        // Fake progress since we don't have hard limits right now
                        ProgressView(value: min(cost / 10.0, 1.0))
                            .progressViewStyle(LinearProgressViewStyle(tint: color))
                            .frame(height: 6)
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(format: "$%.2f cost", cost))
                                    .font(.system(size: 11, weight: .bold))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Usage tracked from logs")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    case .empty(let reason), .unavailable(let reason):
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                
                PanelDivider()
                
                // Links
                VStack(spacing: 0) {
                    let providerID = AIProviderID(name: providerName)
                    
                    Button(action: { router.push(.usageDetail(providerID)) }) {
                        MenuRow(title: "Plan Usage", hasChevron: true)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { router.push(.costDetail(providerID)) }) {
                        MenuRow(title: "Cost", hasChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 16)
        }
    }
}

struct MenuRow: View {
    let title: String
    var hasChevron: Bool = true
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable(radius: 0)
    }
}

struct MenuActionRow: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .hoverable(radius: 0)
    }
}
