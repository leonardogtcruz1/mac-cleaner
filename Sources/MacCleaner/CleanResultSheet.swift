import MacCleanerCore
import SwiftUI

struct CleanResultSheet: View {
    let report: CleanReport
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(report.failures.isEmpty ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(report.failures.isEmpty
                        ? L10n.t("Limpeza Concluída", "Cleanup Complete")
                        : L10n.t("Limpeza Concluída com Avisos", "Cleanup Completed with Warnings"))
                        .font(.title2.bold())
                    Text("\(L10n.t("Modo", "Mode")): \(report.mode.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Espaço Liberado", "Space Reclaimed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ByteFormatting.string(fromBytes: report.reclaimedBytes))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(.green)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Itens Removidos", "Items Removed"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(report.removedCount)")
                        .font(.title2.bold().monospacedDigit())
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }

            if !report.failures.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(L10n.t("Itens não removidos", "Items not removed")) (\(report.failures.count)):")
                        .font(.headline)

                    List(report.failures) { failure in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(failure.entry.name)
                                .font(.subheadline.weight(.medium))
                            Text(failure.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listStyle(.inset)
                    .frame(maxHeight: 200)
                }
            }

            HStack {
                Spacer()
                Button(L10n.t("Concluir", "Done")) {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}
