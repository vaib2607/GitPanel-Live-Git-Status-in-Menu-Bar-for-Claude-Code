import SwiftUI
import Charts

struct AgentDashboardView: View {
    @Environment(AppRouter.self) var router: AppRouter
    let providerName: String
    let isPro: Bool
    let color: Color
    @Bindable var engine = AIEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(providerName)
                            .font(.system(size: 16, weight: .bold))
                        Text("Updated \(timeAgo)")
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session")
                        .font(.system(size: 14, weight: .bold))
                    
                    ProgressView(value: 0.34)
                        .progressViewStyle(LinearProgressViewStyle(tint: color))
                        .frame(height: 6)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("34% used")
                                .font(.system(size: 11, weight: .bold))
                            if !isPro {
                                Text("20% in deficit")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Resets 6 Aug at 10:03 PM")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("Projected empty in 8d 1h")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Weekly Progress
                VStack(alignment: .leading, spacing: 8) {
                    Text("Code review")
                        .font(.system(size: 14, weight: .bold))
                    
                    ProgressView(value: 0.34)
                        .progressViewStyle(LinearProgressViewStyle(tint: color))
                        .frame(height: 6)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                    
                    Text("34% used")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 16)
                
                PanelDivider()
                
                // Stats Grid
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(String(format: "$%.2f", CostEngine.shared.todayCost))
                                .font(.system(size: 16, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("30d tokens")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("608M")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("30d cost")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(String(format: "$%.2f", CostEngine.shared.thisMonthCost))
                                .font(.system(size: 16, weight: .bold))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Latest tokens")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(latestTokensText)
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                
                // Chart Placeholder
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$47")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<10) { i in
                            Rectangle()
                                .fill(color)
                                .frame(height: CGFloat.random(in: 10...50))
                        }
                    }
                    .frame(height: 50)
                }
                .padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top model: \(providerName == "Claude" ? "claude-sonnet-5" : "gpt-4o")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Estimated from local logs for the selected account")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
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
                    
                    PanelDivider()
                    
                    Button(action: { /* Add account logic */ }) {
                        MenuActionRow(icon: "plus", title: "Add Account...")
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { router.push(.usageDashboard(providerID)) }) {
                        MenuActionRow(icon: "chart.xyaxis.line", title: "Usage Dashboard")
                    }
                    .buttonStyle(.plain)
                    
                    MenuRow(title: "Status Page", hasChevron: false)
                }
            }
            .padding(.bottom, 16)
        }
    }
    
    private var timeAgo: String {
        if let provider = engine.providers.first(where: { $0.name.contains(providerName) }), provider.isRunning {
            return "Just now"
        }
        return "21 hr ago"
    }
    
    private var latestTokensText: String {
        if let provider = engine.providers.first(where: { $0.name.contains(providerName) }),
           let usage = provider.tokenUsage {
            return "\(usage.total / 1000)K"
        }
        return "0"
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
