import SwiftUI

struct BranchListView: View {
    @Bindable var viewModel: GitPanelViewModel
    let onBack: () -> Void

    @State private var hoveredBranchID: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search branches", text: $viewModel.branchSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "Branches")
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    switch viewModel.branchesState {
                    case .idle, .loading:
                        HStack {
                            Spacer()
                            ProgressView()
                                .controlSize(.small)
                            Spacer()
                        }
                        .padding()
                    case .failed(let error):
                        HStack {
                            Spacer()
                            Text(error.localizedDescription)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    case .empty(let reason), .unavailable(let reason):
                        HStack {
                            Spacer()
                            Text(reason)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding()
                    case .loaded(let branches, _):
                        ForEach(branches) { branch in
                        Button {
                            Task { await viewModel.checkout(branch) }
                            onBack()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.branch")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)
                                Text(branch.name)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                Spacer()
                                if branch.ahead > 0 {
                                    Text("\(branch.ahead)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.green)
                                        .monospacedDigit()
                                }
                                if branch.behind > 0 {
                                    Text("\(branch.behind)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.orange)
                                        .monospacedDigit()
                                }
                                if branch.isCurrent {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                             }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hoveredBranchID == branch.id ? Color.accentColor.opacity(0.1) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        .hoverable(radius: 8)
                        .onHover { isHovering in
                            hoveredBranchID = isHovering ? branch.id : nil
                        }
                        .accessibilityLabel("\(branch.name)\(branch.isCurrent ? ", current branch" : "")")
                        .accessibilityHint(branch.isCurrent ? "This is the currently checked out branch" : "Tap to checkout this branch")
                        .contextMenu {
                            Button("Checkout") {
                                Task { await viewModel.checkout(branch) }
                                onBack()
                            }
                            Button("Copy Name") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(branch.name, forType: .string)
                            }
                            if !branch.isCurrent {
                                Divider()
                                Button("Delete", role: .destructive) {
                                    Task { await viewModel.deleteBranch(branch) }
                                }
                            }
                        }
                        } // End of ForEach
                    } // End of switch

                    Divider().padding(.vertical, 8)

                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("New branch name", text: $viewModel.branchNameInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                        Button {
                            guard !viewModel.branchNameInput.isEmpty else { return }
                            let name = viewModel.branchNameInput
                            Task { await viewModel.createBranch(name) }
                            onBack()
                        } label: {
                            Text("Create")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                }
            }
            .frame(maxHeight: 380)
        }
    }
}
