import SwiftUI
import Charts

public struct SpendingDashboardView: View {
    @Bindable var engine = AIEngine.shared
    var onBack: () -> Void
    
    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            PanelDivider()
            
            ScrollView {
                VStack(spacing: 16) {
                    summaryCards
                    
                    Text("Cost by Provider (Active Session)")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    chartView
                }
                .padding(16)
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .hoverable(radius: 6)
            }
            .buttonStyle(.plain)
            
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            
            Text("Spending Dashboard")
                .font(.system(size: 13, weight: .medium))
            
            Spacer()
        }
        .frame(height: 28)
    }
    
    private var totalSessionCost: Double {
        engine.providers.reduce(0.0) { total, provider in
            guard let usage = provider.tokenUsage else { return total }
            return total + CostEngine.shared.estimateCost(providerName: provider.name, usage: usage)
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            metricCard(title: "Current Session", value: String(format: "$%.4f", totalSessionCost))
            metricCard(title: "Today", value: String(format: "$%.4f", CostEngine.shared.todayCost))
            metricCard(title: "This Month", value: String(format: "$%.4f", CostEngine.shared.thisMonthCost))
        }
    }
    
    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.system(size: 18, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    struct ChartData: Identifiable {
        let id = UUID()
        let name: String
        let cost: Double
    }
    
    private var chartData: [ChartData] {
        engine.providers.compactMap { provider in
            guard let usage = provider.tokenUsage else { return nil }
            let cost = CostEngine.shared.estimateCost(providerName: provider.name, usage: usage)
            guard cost > 0 else { return nil }
            return ChartData(name: provider.name, cost: cost)
        }
    }
    
    private var chartView: some View {
        VStack {
            if chartData.isEmpty {
                Text("No cost data recorded yet for active sessions.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
            } else {
                Chart(chartData) { data in
                    BarMark(
                        x: .value("Provider", data.name),
                        y: .value("Cost", data.cost)
                    )
                    .foregroundStyle(by: .value("Provider", data.name))
                    .cornerRadius(4)
                }
                .chartLegend(.hidden)
                .frame(height: 150)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
