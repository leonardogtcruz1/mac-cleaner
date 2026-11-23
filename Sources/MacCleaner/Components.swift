import MacCleanerCore
import SwiftUI

struct RiskBadge: View {
    let risk: RiskLevel

    private var tintColor: Color {
        switch risk {
        case .safe: return .green
        case .moderate: return .orange
        case .caution: return .red
        }
    }

    var body: some View {
        Label(risk.displayName, systemImage: risk.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tintColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tintColor.opacity(0.14), in: Capsule())
    }
}

struct DiskUsageCard: View {
    let diskSpace: DiskSpaceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Macintosh HD", systemImage: "internaldrive")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int((diskSpace.usedFraction * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: diskSpace.usedFraction)
                .tint(diskSpace.usedFraction > 0.85 ? .orange : .accentColor)

            HStack {
                Text("\(ByteFormatting.string(fromBytes: diskSpace.availableBytes)) \(L10n.t("livres", "free"))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(L10n.t("de", "of")) \(ByteFormatting.string(fromBytes: diskSpace.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
