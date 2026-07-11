import SwiftUI

struct UsageDetailView: View {
    var viewModel: GitPanelViewModel
    var onBack: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Usage")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            PanelDivider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Tokens used: \(viewModel.usage.tokens)")
                    .font(.system(size: 14))
                Text("Plan: \(viewModel.usage.plan.isEmpty ? "Free" : viewModel.usage.plan)")
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
