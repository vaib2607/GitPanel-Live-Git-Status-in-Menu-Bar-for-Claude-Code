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
            
            VStack(alignment: .leading, spacing: 12) {
                Text(String(format: "Total Cost: $%.2f", viewModel.usage.cost))
                    .font(.system(size: 14))
                
                if !viewModel.usage.modelBreakdown.isEmpty {
                    Text("By Model:")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.top, 8)
                    
                    ForEach(Array(viewModel.usage.modelBreakdown.keys.sorted()), id: \.self) { model in
                        if let cost = viewModel.usage.modelBreakdown[model] {
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
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
