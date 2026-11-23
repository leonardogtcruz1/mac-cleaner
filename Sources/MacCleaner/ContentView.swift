import MacCleanerCore
import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.sidebarSelection) {
                Section {
                    DiskUsageCard(diskSpace: viewModel.diskSpace)
                        .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                        .listRowBackground(Color.clear)
                }

                Section(L10n.t("Visão Geral", "Overview")) {
                    NavigationLink(value: SidebarDestination.overview) {
                        Label {
                            HStack {
                                Text(L10n.t("Resumo", "Summary"))
                                Spacer()
                                if let summary = viewModel.scanSummary {
                                    Text(ByteFormatting.string(fromBytes: summary.totalBytes))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "chart.bar.xaxis")
                        }
                    }
                }

                Section(L10n.t("Categorias", "Categories")) {
                    ForEach(CleanerCategory.allCases) { category in
                        NavigationLink(value: SidebarDestination.category(category)) {
                            Label {
                                HStack {
                                    Text(category.displayName)
                                        .lineLimit(1)
                                    Spacer()
                                    let bytes = viewModel.categoryBytes(category)
                                    if bytes > 0 {
                                        Text(ByteFormatting.string(fromBytes: bytes))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: category.symbolName)
                            }
                        }
                    }
                }

                Section(L10n.t("Segurança", "Safety")) {
                    NavigationLink(value: SidebarDestination.exclusions) {
                        Label {
                            HStack {
                                Text(L10n.t("Protegidos", "Protected"))
                                Spacer()
                                if !viewModel.exclusions.isEmpty {
                                    Text("\(viewModel.exclusions.count)")
                                        .font(.caption.monospacedDigit())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: "lock.shield")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 240, ideal: 265, max: 310)
        } detail: {
            detailContent
                .safeAreaInset(edge: .bottom) {
                    bottomActionBar
                }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if viewModel.isScanning {
                    HStack(spacing: 8) {
                        ProgressView(value: viewModel.scanProgress)
                            .frame(width: 90)
                        Text(viewModel.scanStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(maxWidth: 220, alignment: .leading)
                        Button(L10n.t("Cancelar", "Cancel")) {
                            viewModel.cancelScan()
                        }
                    }
                } else {
                    Button {
                        viewModel.startScan()
                    } label: {
                        Label(L10n.t("Escanear", "Scan"), systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isCleaning)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingDryRunConfirmation) {
            DryRunConfirmationSheet(viewModel: viewModel)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.lastCleanReport != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.lastCleanReport = nil
                    }
                }
            )
        ) {
            if let report = viewModel.lastCleanReport {
                CleanResultSheet(report: report) {
                    viewModel.lastCleanReport = nil
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.sidebarSelection ?? .overview {
        case .overview:
            OverviewView(viewModel: viewModel)
        case .category(let category):
            CategoryDetailView(viewModel: viewModel, category: category)
        case .exclusions:
            ExclusionsView(viewModel: viewModel)
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if viewModel.isCleaning {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.cleanStatusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.selectedCount) \(L10n.t("itens selecionados", "items selected"))")
                            .font(.subheadline.weight(.semibold))
                        Text("\(L10n.t("Espaço a liberar", "Space to reclaim")): \(ByteFormatting.string(fromBytes: viewModel.selectedBytes))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(L10n.t("Selecionar Seguros", "Select Safe")) {
                        viewModel.selectAllSafe()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.scanSummary == nil || viewModel.isScanning)

                    if viewModel.selectedCount > 0 {
                        Button(L10n.t("Limpar Seleção", "Clear Selection")) {
                            viewModel.clearSelection()
                        }
                        .buttonStyle(.borderless)
                    }

                    Picker(L10n.t("Modo", "Mode"), selection: $viewModel.cleanMode) {
                        ForEach(CleanMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 195)

                    Button {
                        viewModel.isShowingDryRunConfirmation = true
                    } label: {
                        Label(L10n.t("Limpar Agora", "Clean Now"), systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(viewModel.cleanMode == .permanentDelete ? .red : .accentColor)
                    .disabled(viewModel.selectedCount == 0 || viewModel.isScanning || viewModel.isCleaning)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }
}
