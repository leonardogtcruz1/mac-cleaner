import MacCleanerCore
import SwiftUI

struct DryRunConfirmationSheet: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private var groupedEntries: [(risk: RiskLevel, entries: [ScannedEntry])] {
        viewModel.selectedEntriesGroupedByRisk()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.cleanMode == .permanentDelete ? "exclamationmark.triangle.fill" : "trash.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(viewModel.cleanMode == .permanentDelete ? .red : .accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Confirmar Limpeza (Preview)", "Confirm Cleanup (Preview)"))
                        .font(.title2.bold())
                    Text("\(viewModel.selectedCount) \(L10n.t("itens selecionados", "items selected")) • \(ByteFormatting.string(fromBytes: viewModel.selectedBytes))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if viewModel.cleanMode == .permanentDelete {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(L10n.t(
                        "Atenção: o modo \"Apagar Permanentemente\" remove os arquivos imediatamente sem enviá-los para a Lixeira. Essa ação não pode ser desfeita.",
                        "Warning: \"Delete Permanently\" removes files immediately without sending them to Trash. This action cannot be undone."
                    ))
                        .font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                    Text(L10n.t(
                        "Os itens serão movidos para a Lixeira do macOS. Você poderá restaurá-los se precisar.",
                        "Selected items will be moved to macOS Trash. You can restore them anytime if needed."
                    ))
                        .font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            }

            List {
                ForEach(groupedEntries, id: \.risk) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(entry.url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Text(ByteFormatting.string(fromBytes: entry.sizeBytes))
                                    .font(.subheadline.monospacedDigit())
                            }
                        }
                    } header: {
                        HStack {
                            RiskBadge(risk: group.risk)
                            Spacer()
                            let groupTotal = group.entries.reduce(0) { $0 + $1.sizeBytes }
                            Text(ByteFormatting.string(fromBytes: groupTotal))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 260)

            HStack {
                Spacer()
                Button(L10n.t("Cancelar", "Cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(viewModel.cleanMode.actionButtonTitle) {
                    viewModel.executeClean()
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.cleanMode == .permanentDelete ? .red : .accentColor)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 660, height: 520)
    }
}
