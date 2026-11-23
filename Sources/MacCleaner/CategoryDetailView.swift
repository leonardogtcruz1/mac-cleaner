import MacCleanerCore
import SwiftUI

struct CategoryDetailView: View {
    @Bindable var viewModel: AppViewModel
    let category: CleanerCategory

    private static func makeDateFormatter() -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = L10n.locale
        return formatter
    }

    private var ruleResults: [ScanRuleResult] {
        viewModel.results(for: category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()

            if ruleResults.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty
                        ? L10n.t("Nada encontrado em \(category.displayName)", "Nothing found in \(category.displayName)")
                        : L10n.t("Nenhum resultado para \"\(viewModel.searchText)\"", "No results for \"\(viewModel.searchText)\""),
                    systemImage: category.symbolName,
                    description: Text(category.subtitle)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(ruleResults) { ruleResult in
                            ruleCard(ruleResult)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(category.displayName)
        .onAppear {
            viewModel.ensureExpandedDefaults(for: category)
        }
        .onChange(of: category) { _, newCategory in
            viewModel.ensureExpandedDefaults(for: newCategory)
        }
    }

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(category.displayName, systemImage: category.symbolName)
                        .font(.title2.bold())
                    Text(category.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(ByteFormatting.string(fromBytes: viewModel.categoryBytes(category)))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L10n.t("Filtrar por nome ou caminho...", "Filter by name or path..."), text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

                if category == .staleProjects {
                    Picker(L10n.t("Inatividade", "Inactivity"), selection: $viewModel.staleDaysThreshold) {
                        Text("15d").tag(15)
                        Text("30d").tag(30)
                        Text("60d").tag(60)
                        Text("90d").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .onChange(of: viewModel.staleDaysThreshold) { _, _ in
                        viewModel.startScan()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func ruleCard(_ ruleResult: ScanRuleResult) -> some View {
        let isExpanded = Binding(
            get: { viewModel.expandedRuleIDs.contains(ruleResult.id) },
            set: { expanded in
                if expanded {
                    viewModel.expandedRuleIDs.insert(ruleResult.id)
                } else {
                    viewModel.expandedRuleIDs.remove(ruleResult.id)
                }
            }
        )

        return DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ruleResult.rule.summary)
                        .font(.subheadline)
                    Text(ruleResult.rule.impactNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                Divider()

                ForEach(ruleResult.entries) { entry in
                    entryRow(entry)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 10) {
                let state = viewModel.selectionState(for: ruleResult)
                Button {
                    viewModel.toggleRule(ruleResult)
                } label: {
                    Image(systemName: selectionSymbol(for: state))
                        .font(.body)
                        .foregroundStyle(state == .none ? Color.secondary : Color.accentColor)
                }
                .buttonStyle(.plain)

                Text(ruleResult.rule.name)
                    .font(.headline)

                RiskBadge(risk: ruleResult.rule.risk)

                Spacer()

                Text("\(formattedNumber(ruleResult.totalFiles)) \(L10n.t("arquivos", "files"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(ByteFormatting.string(fromBytes: ruleResult.totalBytes))
                    .font(.subheadline.bold().monospacedDigit())
                    .frame(minWidth: 76, alignment: .trailing)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12))
    }

    private func entryRow(_ entry: ScannedEntry) -> some View {
        let isSelected = viewModel.selectedEntryIDs.contains(entry.id) && !entry.isProtected
        let isExplicitlyExcluded = viewModel.exclusions.contains(SafetyGuard.normalizePath(entry.url.path))

        return HStack(spacing: 10) {
            Button {
                viewModel.toggleEntry(entry)
            } label: {
                Image(systemName: entry.isProtected ? "lock.fill" : (isSelected ? "checkmark.square.fill" : "square"))
                    .foregroundStyle(entry.isProtected ? .blue : (isSelected ? Color.accentColor : .secondary))
            }
            .buttonStyle(.plain)
            .disabled(entry.isProtected)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.subheadline.weight(.medium))
                    if entry.isProtected {
                        Text(L10n.t("Protegido", "Protected"))
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.14), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 8) {
                    Text(entry.url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("• \(formattedNumber(entry.fileCount)) \(L10n.t("arq.", "files"))")
                    if let mod = entry.lastModified {
                        Text("• \(Self.makeDateFormatter().localizedString(for: mod, relativeTo: Date()))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ByteFormatting.string(fromBytes: entry.sizeBytes))
                .font(.subheadline.monospacedDigit())

            Button {
                viewModel.revealInFinder(url: entry.url)
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help(L10n.t("Mostrar no Finder", "Reveal in Finder"))

            Button {
                if isExplicitlyExcluded {
                    viewModel.removeExclusion(path: entry.url.path)
                } else {
                    viewModel.addExclusion(path: entry.url.path)
                }
            } label: {
                Image(systemName: isExplicitlyExcluded ? "shield.slash" : "shield")
                    .foregroundStyle(isExplicitlyExcluded ? .blue : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isExplicitlyExcluded
                ? L10n.t("Remover proteção", "Remove protection")
                : L10n.t("Proteger item (nunca limpar)", "Protect item (never clean)"))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
    }

    private func formattedNumber(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = L10n.locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func selectionSymbol(for state: RuleSelectionState) -> String {
        switch state {
        case .none: return "square"
        case .partial: return "minus.square.fill"
        case .all: return "checkmark.square.fill"
        }
    }
}
