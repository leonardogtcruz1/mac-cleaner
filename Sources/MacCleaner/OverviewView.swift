import Charts
import MacCleanerCore
import SwiftUI

private struct CategoryChartItem: Identifiable {
    let category: CleanerCategory
    let bytes: Int64

    var id: String { category.id }
    var gigabytes: Double { Double(bytes) / 1_073_741_824.0 }
}

struct OverviewView: View {
    @Bindable var viewModel: AppViewModel

    private var chartData: [CategoryChartItem] {
        guard let summary = viewModel.scanSummary else { return [] }
        return CleanerCategory.allCases.compactMap { category in
            let bytes = summary.bytes(for: category)
            guard bytes > 0 else { return nil }
            return CategoryChartItem(category: category, bytes: bytes)
        }
        .sorted { $0.bytes > $1.bytes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if let summary = viewModel.scanSummary {
                    if summary.totalSkippedPermissions > 0 {
                        fullDiskAccessBanner(skippedCount: summary.totalSkippedPermissions)
                    }

                    kpiGrid(summary: summary)
                    categoryChartSection(summary: summary)
                    topEntriesSection(summary: summary)
                } else if viewModel.isScanning {
                    VStack(spacing: 12) {
                        ProgressView(value: viewModel.scanProgress)
                            .frame(maxWidth: 320)
                        Text(viewModel.scanStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ContentUnavailableView(
                        L10n.t("Pronto para Analisar seu Mac", "Ready to Analyze Your Mac"),
                        systemImage: "sparkles",
                        description: Text(L10n.t(
                            "Clique em Escanear para mapear caches de agentes de IA, pacotes dev e lixo do sistema com segurança.",
                            "Click Scan to safely map AI agent caches, dev packages, and system junk."
                        ))
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                }
            }
            .padding(24)
        }
        .navigationTitle(L10n.t("Resumo", "Summary"))
    }

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Visão Geral do Armazenamento", "Storage Overview"))
                    .font(.title2.bold())
                if let summary = viewModel.scanSummary {
                    Text(
                        String(
                            format: L10n.t(
                                "Último scan há instantes (%.1fs) — somente leitura até você confirmar a limpeza.",
                                "Last scan moments ago (%.1fs) — read-only until you confirm cleanup."
                            ),
                            locale: L10n.locale,
                            summary.durationSeconds
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    Text(L10n.t(
                        "Diagnóstico somente leitura de caches de IA, ferramentas dev e sistema.",
                        "Read-only diagnostic of AI agent caches, dev tools, and macOS clutter."
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func fullDiskAccessBanner(skippedCount: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(
                    "Algumas pastas exigem Acesso Total ao Disco (\(skippedCount) ignoradas)",
                    "Some folders require Full Disk Access (\(skippedCount) skipped)"
                ))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.t(
                    "O scan continuou normalmente, mas conceder Acesso Total ao Disco permite medir pastas protegidas em ~/Library.",
                    "The scan completed safely, but granting Full Disk Access allows measuring protected folders in ~/Library."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(L10n.t("Abrir Ajustes", "Open Settings")) {
                viewModel.openFullDiskAccessSettings()
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func kpiGrid(summary: ScanSummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
            kpiCard(
                title: L10n.t("Espaço Livre", "Free Space"),
                value: ByteFormatting.string(fromBytes: summary.diskSpace.availableBytes),
                subtitle: "\(L10n.t("de", "of")) \(ByteFormatting.string(fromBytes: summary.diskSpace.totalBytes))",
                symbol: "internaldrive",
                tint: .blue
            )
            kpiCard(
                title: L10n.t("Total Encontrado", "Total Found"),
                value: ByteFormatting.string(fromBytes: summary.totalBytes),
                subtitle: "\(summary.results.count) \(L10n.t("regras com itens", "rules with items"))",
                symbol: "externaldrive.badge.timemachine",
                tint: .purple
            )
            kpiCard(
                title: L10n.t("Seguro para Limpar", "Safe to Clean"),
                value: ByteFormatting.string(fromBytes: summary.safeBytes),
                subtitle: L10n.t("Caches recriáveis", "Recreatable caches"),
                symbol: "checkmark.shield.fill",
                tint: .green
            )
            kpiCard(
                title: L10n.t("Selecionado Agora", "Selected Now"),
                value: ByteFormatting.string(fromBytes: viewModel.selectedBytes),
                subtitle: "\(viewModel.selectedCount) \(L10n.t("itens marcados", "items selected"))",
                symbol: "trash.circle.fill",
                tint: .orange
            )
        }
    }

    private func kpiCard(
        title: String,
        value: String,
        subtitle: String,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private func categoryChartSection(summary: ScanSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("Espaço Recuperável por Categoria", "Reclaimable Space by Category"))
                .font(.headline)

            if chartData.isEmpty {
                Text(L10n.t("Nenhum arquivo de cache relevante encontrado.", "No relevant cache files found."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("GB", item.gigabytes),
                        y: .value(L10n.t("Categoria", "Category"), item.category.displayName)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text(ByteFormatting.string(fromBytes: item.bytes))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxisLabel(L10n.t("Tamanho (GB)", "Size (GB)"))
                .frame(height: CGFloat(max(160, chartData.count * 44)))
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    private func topEntriesSection(summary: ScanSummary) -> some View {
        let topItems = Array(summary.topEntries.prefix(8))

        return VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("Maiores Itens Encontrados", "Largest Items Found"))
                .font(.headline)

            if topItems.isEmpty {
                Text(L10n.t("Nenhum item encontrado.", "No items found."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(topItems) { entry in
                        HStack(spacing: 12) {
                            let isSelected = viewModel.selectedEntryIDs.contains(entry.id) && !entry.isProtected
                            Button {
                                viewModel.toggleEntry(entry)
                            } label: {
                                Image(systemName: entry.isProtected ? "lock.fill" : (isSelected ? "checkmark.square.fill" : "square"))
                                    .foregroundStyle(entry.isProtected ? .secondary : (isSelected ? Color.accentColor : .secondary))
                            }
                            .buttonStyle(.plain)
                            .disabled(entry.isProtected)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.medium))
                                    if let rule = viewModel.rule(for: entry.ruleID) {
                                        RiskBadge(risk: rule.risk)
                                    }
                                    if entry.isProtected {
                                        Text(L10n.t("Protegido", "Protected"))
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.blue.opacity(0.14), in: Capsule())
                                            .foregroundStyle(.blue)
                                    }
                                }
                                Text(entry.url.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Text(ByteFormatting.string(fromBytes: entry.sizeBytes))
                                .font(.subheadline.weight(.semibold).monospacedDigit())

                            Button {
                                viewModel.revealInFinder(url: entry.url)
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.t("Mostrar no Finder", "Reveal in Finder"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
