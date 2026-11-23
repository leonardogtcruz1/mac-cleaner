import Foundation

public enum CleanerCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case aiAgents
    case aiModels
    case devCaches
    case xcodeAndMobile
    case systemAndApps
    case staleProjects

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .aiAgents: return L10n.t("Agentes de IA & IDEs", "AI Agents & IDEs")
        case .aiModels: return L10n.t("Modelos de IA Locais", "Local AI Models")
        case .devCaches: return L10n.t("Dev & Pacotes", "Dev & Packages")
        case .xcodeAndMobile: return L10n.t("Xcode & Simuladores", "Xcode & Simulators")
        case .systemAndApps: return L10n.t("Sistema & Apps", "System & Apps")
        case .staleProjects: return L10n.t("Projetos Parados", "Stale Projects")
        }
    }

    public var symbolName: String {
        switch self {
        case .aiAgents: return "sparkles"
        case .aiModels: return "cpu"
        case .devCaches: return "hammer"
        case .xcodeAndMobile: return "iphone"
        case .systemAndApps: return "macbook"
        case .staleProjects: return "folder.badge.clock"
        }
    }

    public var subtitle: String {
        switch self {
        case .aiAgents:
            return L10n.t(
                "Caches, temporários e sessões de Gemini, Claude, Codex, Antigravity, Cursor e VS Code.",
                "Caches, temp files, and sessions from Gemini, Claude, Codex, Antigravity, Cursor, and VS Code."
            )
        case .aiModels:
            return L10n.t(
                "Pesos e caches de modelos locais (HuggingFace, Ollama, LM Studio).",
                "Local model weights and caches (HuggingFace, Ollama, LM Studio)."
            )
        case .devCaches:
            return L10n.t(
                "Caches recriáveis de npm, pip, uv, Homebrew, SwiftPM, Cargo, Playwright e mais.",
                "Recreatable caches from npm, pip, uv, Homebrew, SwiftPM, Cargo, Playwright, and more."
            )
        case .xcodeAndMobile:
            return L10n.t(
                "DerivedData, caches do Xcode e dispositivos do CoreSimulator.",
                "DerivedData, Xcode caches, and CoreSimulator devices."
            )
        case .systemAndApps:
            return L10n.t(
                "Caches de aplicativos em ~/Library/Caches, logs e instaladores antigos.",
                "App caches in ~/Library/Caches, logs, and old installers."
            )
        case .staleProjects:
            return L10n.t(
                "Pastas node_modules, .venv, target e .next em projetos sem edição recente.",
                "node_modules, .venv, target, and .next folders in inactive projects."
            )
        }
    }
}

public enum RiskLevel: String, Comparable, CaseIterable, Sendable, Codable {
    case safe
    case moderate
    case caution

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .safe: return 0
        case .moderate: return 1
        case .caution: return 2
        }
    }

    public var displayName: String {
        switch self {
        case .safe: return L10n.t("Seguro", "Safe")
        case .moderate: return L10n.t("Moderado", "Moderate")
        case .caution: return L10n.t("Revisão Manual", "Manual Review")
        }
    }

    public var symbolName: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .caution: return "hand.raised.fill"
        }
    }
}

public enum TargetSpec: Sendable, Hashable {
    case directory(path: String)
    case directoryChildren(path: String, excludeNames: Set<String> = [])
    case matchingFiles(path: String, extensions: Set<String>, olderThanDays: Int)
    case staleProjectArtifacts(roots: [String], artifactNames: Set<String>, olderThanDays: Int, maxDepth: Int)
}

public struct CleanerRule: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: CleanerCategory
    public let risk: RiskLevel
    public let summary: String
    public let impactNote: String
    public let targets: [TargetSpec]
    public let defaultSelected: Bool

    public init(
        id: String,
        name: String,
        category: CleanerCategory,
        risk: RiskLevel,
        summary: String,
        impactNote: String,
        targets: [TargetSpec],
        defaultSelected: Bool
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.risk = risk
        self.summary = summary
        self.impactNote = impactNote
        self.targets = targets
        self.defaultSelected = defaultSelected
    }
}

public struct ScannedEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let ruleID: String
    public let name: String
    public let url: URL
    public let sizeBytes: Int64
    public let fileCount: Int
    public let lastModified: Date?
    public let isProtected: Bool

    public init(
        id: String? = nil,
        ruleID: String,
        name: String,
        url: URL,
        sizeBytes: Int64,
        fileCount: Int,
        lastModified: Date?,
        isProtected: Bool
    ) {
        let normalized = url.standardizedFileURL.path
        self.id = id ?? normalized
        self.ruleID = ruleID
        self.name = name
        self.url = url.standardizedFileURL
        self.sizeBytes = sizeBytes
        self.fileCount = fileCount
        self.lastModified = lastModified
        self.isProtected = isProtected
    }
}

public struct ScanRuleResult: Identifiable, Sendable {
    public var id: String { rule.id }
    public let rule: CleanerRule
    public let entries: [ScannedEntry]
    public let totalBytes: Int64
    public let totalFiles: Int
    public let skippedPermissionCount: Int

    public init(
        rule: CleanerRule,
        entries: [ScannedEntry],
        totalBytes: Int64,
        totalFiles: Int,
        skippedPermissionCount: Int
    ) {
        self.rule = rule
        self.entries = entries
        self.totalBytes = totalBytes
        self.totalFiles = totalFiles
        self.skippedPermissionCount = skippedPermissionCount
    }
}

public struct DiskSpaceInfo: Sendable {
    public let totalBytes: Int64
    public let availableBytes: Int64
    public let usedBytes: Int64

    public init(totalBytes: Int64, availableBytes: Int64) {
        self.totalBytes = max(0, totalBytes)
        self.availableBytes = max(0, min(availableBytes, totalBytes))
        self.usedBytes = max(0, self.totalBytes - self.availableBytes)
    }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public static func current(for url: URL = URL(fileURLWithPath: "/")) -> DiskSpaceInfo {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]
        guard let values = try? url.resourceValues(forKeys: keys) else {
            return DiskSpaceInfo(totalBytes: 0, availableBytes: 0)
        }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage
            ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskSpaceInfo(totalBytes: total, availableBytes: available)
    }
}

public struct ScanSummary: Sendable {
    public let results: [ScanRuleResult]
    public let diskSpace: DiskSpaceInfo
    public let scannedAt: Date
    public let durationSeconds: TimeInterval
    public let totalSkippedPermissions: Int

    public init(
        results: [ScanRuleResult],
        diskSpace: DiskSpaceInfo,
        scannedAt: Date,
        durationSeconds: TimeInterval,
        totalSkippedPermissions: Int
    ) {
        self.results = results
        self.diskSpace = diskSpace
        self.scannedAt = scannedAt
        self.durationSeconds = durationSeconds
        self.totalSkippedPermissions = totalSkippedPermissions
    }

    public var totalBytes: Int64 {
        results.reduce(0) { $0 + $1.totalBytes }
    }

    public var safeBytes: Int64 {
        results
            .filter { $0.rule.risk == .safe }
            .reduce(0) { $0 + $1.totalBytes }
    }

    public func results(for category: CleanerCategory) -> [ScanRuleResult] {
        results.filter { $0.rule.category == category }
    }

    public func bytes(for category: CleanerCategory) -> Int64 {
        results(for: category).reduce(0) { $0 + $1.totalBytes }
    }

    public var topEntries: [ScannedEntry] {
        results
            .flatMap(\.entries)
            .sorted { $0.sizeBytes > $1.sizeBytes }
    }
}

public enum CleanMode: String, CaseIterable, Identifiable, Sendable {
    case moveToTrash
    case permanentDelete

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .moveToTrash: return L10n.t("Mover para Lixeira", "Move to Trash")
        case .permanentDelete: return L10n.t("Apagar Permanentemente", "Delete Permanently")
        }
    }

    public var actionButtonTitle: String {
        switch self {
        case .moveToTrash: return L10n.t("Confirmar e Mover para Lixeira", "Confirm & Move to Trash")
        case .permanentDelete: return L10n.t("Confirmar Exclusão Permanente", "Confirm Permanent Delete")
        }
    }
}

public struct CleanFailure: Identifiable, Sendable {
    public var id: String { entry.id }
    public let entry: ScannedEntry
    public let reason: String

    public init(entry: ScannedEntry, reason: String) {
        self.entry = entry
        self.reason = reason
    }
}

public struct CleanReport: Sendable {
    public let reclaimedBytes: Int64
    public let removedCount: Int
    public let failures: [CleanFailure]
    public let mode: CleanMode
    public let completedAt: Date

    public init(
        reclaimedBytes: Int64,
        removedCount: Int,
        failures: [CleanFailure],
        mode: CleanMode,
        completedAt: Date
    ) {
        self.reclaimedBytes = reclaimedBytes
        self.removedCount = removedCount
        self.failures = failures
        self.mode = mode
        self.completedAt = completedAt
    }
}

public enum ByteFormatting {
    public static func string(fromBytes bytes: Int64) -> String {
        let safeBytes = max(0, bytes)
        if !L10n.isEnglish {
            return ByteCountFormatter.string(fromByteCount: safeBytes, countStyle: .file)
        }
        if safeBytes == 0 {
            return "0 KB"
        }
        if safeBytes < 1_000 {
            return "\(safeBytes) B"
        }
        let units = ["KB", "MB", "GB", "TB"]
        var value = Double(safeBytes) / 1_000.0
        var unitIndex = 0
        while value >= 1_000.0 && unitIndex < units.count - 1 {
            value /= 1_000.0
            unitIndex += 1
        }
        let maxDigits = unitIndex == 0 ? 0 : (value >= 100 ? 0 : 2)
        let formatted = String(format: "%.\(maxDigits)f", locale: Locale(identifier: "en_US_POSIX"), value)
        let clean = formatted.contains(".")
            ? formatted.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            : formatted
        return "\(clean) \(units[unitIndex])"
    }
}
