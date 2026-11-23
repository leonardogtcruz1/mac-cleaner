import AppKit
import Foundation
import MacCleanerCore
import Observation

enum SidebarDestination: Hashable {
    case overview
    case category(CleanerCategory)
    case exclusions
}

enum RuleSelectionState {
    case none
    case partial
    case all
}

@MainActor
@Observable
final class AppViewModel {
    var scanSummary: ScanSummary?
    var isScanning = false
    var scanProgress: Double = 0
    var scanStatusText: String = "Pronto para escanear"
    var selectedEntryIDs: Set<String> = []
    var cleanMode: CleanMode = .moveToTrash
    var staleDaysThreshold: Int = 30
    var searchText: String = ""
    var exclusions: Set<String>
    var isShowingDryRunConfirmation = false
    var isCleaning = false
    var cleanStatusText: String = ""
    var lastCleanReport: CleanReport?
    var sidebarSelection: SidebarDestination? = .overview
    var diskSpace: DiskSpaceInfo
    var expandedRuleIDs: Set<String> = []
    private var initializedExpandedCategories: Set<CleanerCategory> = []

    private let exclusionsStore: ExclusionsStore
    private var scanTask: Task<Void, Never>?
    private var hasStartedInitialScan = false

    init(exclusionsStore: ExclusionsStore = ExclusionsStore()) {
        self.exclusionsStore = exclusionsStore
        self.exclusions = exclusionsStore.load()
        self.diskSpace = DiskSpaceInfo.current()
    }

    var allEntries: [ScannedEntry] {
        scanSummary?.results.flatMap(\.entries) ?? []
    }

    var selectedEntries: [ScannedEntry] {
        var uniqueByID: [String: ScannedEntry] = [:]
        for entry in allEntries where selectedEntryIDs.contains(entry.id) && !entry.isProtected {
            uniqueByID[entry.id] = entry
        }
        return uniqueByID.values.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    var selectedBytes: Int64 {
        selectedEntries.reduce(0) { $0 + $1.sizeBytes }
    }

    var selectedCount: Int {
        selectedEntries.count
    }

    func categoryBytes(_ category: CleanerCategory) -> Int64 {
        scanSummary?.bytes(for: category) ?? 0
    }

    func results(for category: CleanerCategory) -> [ScanRuleResult] {
        guard let summary = scanSummary else { return [] }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let categoryResults = summary.results(for: category)

        guard !query.isEmpty else {
            return categoryResults
        }

        return categoryResults.compactMap { ruleResult in
            if ruleResult.rule.name.lowercased().contains(query) || ruleResult.rule.summary.lowercased().contains(query) {
                return ruleResult
            }
            let matchingEntries = ruleResult.entries.filter {
                $0.name.lowercased().contains(query) || $0.url.path.lowercased().contains(query)
            }
            guard !matchingEntries.isEmpty else { return nil }
            return ScanRuleResult(
                rule: ruleResult.rule,
                entries: matchingEntries,
                totalBytes: matchingEntries.reduce(0) { $0 + $1.sizeBytes },
                totalFiles: matchingEntries.reduce(0) { $0 + $1.fileCount },
                skippedPermissionCount: ruleResult.skippedPermissionCount
            )
        }
    }

    func rule(for ruleID: String) -> CleanerRule? {
        scanSummary?.results.first(where: { $0.rule.id == ruleID })?.rule
    }

    func selectedEntriesGroupedByRisk() -> [(risk: RiskLevel, entries: [ScannedEntry])] {
        let rulesByID = Dictionary(
            uniqueKeysWithValues: (scanSummary?.results ?? []).map { ($0.rule.id, $0.rule) }
        )

        var grouped: [RiskLevel: [ScannedEntry]] = [:]
        for entry in selectedEntries {
            let risk = rulesByID[entry.ruleID]?.risk ?? .moderate
            grouped[risk, default: []].append(entry)
        }

        return RiskLevel.allCases.compactMap { risk in
            guard let items = grouped[risk], !items.isEmpty else { return nil }
            return (risk, items.sorted { $0.sizeBytes > $1.sizeBytes })
        }
    }

    func selectionState(for ruleResult: ScanRuleResult) -> RuleSelectionState {
        let selectable = ruleResult.entries.filter { !$0.isProtected }
        guard !selectable.isEmpty else { return .none }
        let selectedCount = selectable.filter { selectedEntryIDs.contains($0.id) }.count
        if selectedCount == 0 { return .none }
        if selectedCount == selectable.count { return .all }
        return .partial
    }

    func startScanIfNeeded() {
        guard !hasStartedInitialScan else { return }
        hasStartedInitialScan = true
        startScan()
    }

    func startScan() {
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        scanStatusText = "Iniciando varredura..."
        diskSpace = DiskSpaceInfo.current()

        let currentStaleDays = staleDaysThreshold
        let currentExclusions = exclusions

        scanTask = Task { [weak self] in
            guard let owner = self else { return }
            let rules = RuleCatalog.defaultRules(staleDays: currentStaleDays)
            let scanner = ScannerEngine()
            let summary = await scanner.scan(rules: rules, exclusions: currentExclusions) { completed, total, ruleName in
                Task { @MainActor in
                    guard owner.isScanning else { return }
                    owner.scanProgress = total > 0 ? Double(completed) / Double(total) : 0
                    owner.scanStatusText = "Escaneando: \(ruleName)"
                }
            }

            guard !Task.isCancelled else { return }
            owner.finishScan(with: summary)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanStatusText = "Varredura cancelada"
    }

    private func finishScan(with summary: ScanSummary) {
        scanSummary = summary
        diskSpace = summary.diskSpace
        isScanning = false
        scanProgress = 1
        scanStatusText = String(format: "Concluído em %.1fs", summary.durationSeconds)

        var autoSelected = Set<String>()
        for result in summary.results where result.rule.defaultSelected {
            for entry in result.entries where !entry.isProtected {
                autoSelected.insert(entry.id)
            }
        }
        selectedEntryIDs = autoSelected

        if case .category(let activeCategory) = sidebarSelection {
            ensureExpandedDefaults(for: activeCategory)
        }
    }

    func ensureExpandedDefaults(for category: CleanerCategory) {
        guard !initializedExpandedCategories.contains(category) else { return }
        let ids = results(for: category).map(\.id)
        guard !ids.isEmpty else { return }
        initializedExpandedCategories.insert(category)
        expandedRuleIDs.formUnion(ids)
    }

    func toggleEntry(_ entry: ScannedEntry) {
        guard !entry.isProtected else { return }
        if selectedEntryIDs.contains(entry.id) {
            selectedEntryIDs.remove(entry.id)
        } else {
            selectedEntryIDs.insert(entry.id)
        }
    }

    func toggleRule(_ ruleResult: ScanRuleResult) {
        let selectable = ruleResult.entries.filter { !$0.isProtected }
        guard !selectable.isEmpty else { return }
        let state = selectionState(for: ruleResult)
        switch state {
        case .all:
            for entry in selectable {
                selectedEntryIDs.remove(entry.id)
            }
        case .none, .partial:
            for entry in selectable {
                selectedEntryIDs.insert(entry.id)
            }
        }
    }

    func selectAllSafe() {
        guard let summary = scanSummary else { return }
        var updated = selectedEntryIDs
        for result in summary.results where result.rule.risk == .safe {
            for entry in result.entries where !entry.isProtected {
                updated.insert(entry.id)
            }
        }
        selectedEntryIDs = updated
    }

    func clearSelection() {
        selectedEntryIDs.removeAll()
    }

    func addExclusion(path: String) {
        let normalized = SafetyGuard.normalizePath(path)
        exclusions = exclusionsStore.add(normalized)
        refreshProtectedFlagsLocally()
    }

    func removeExclusion(path: String) {
        let normalized = SafetyGuard.normalizePath(path)
        exclusions = exclusionsStore.remove(normalized)
        refreshProtectedFlagsLocally()
    }

    private func refreshProtectedFlagsLocally() {
        guard let current = scanSummary else { return }
        let updatedResults = current.results.map { result in
            let updatedEntries = result.entries.map { entry in
                let protected = SafetyGuard.isProtected(url: entry.url, exclusions: exclusions)
                if protected {
                    selectedEntryIDs.remove(entry.id)
                }
                return ScannedEntry(
                    id: entry.id,
                    ruleID: entry.ruleID,
                    name: entry.name,
                    url: entry.url,
                    sizeBytes: entry.sizeBytes,
                    fileCount: entry.fileCount,
                    lastModified: entry.lastModified,
                    isProtected: protected
                )
            }
            return ScanRuleResult(
                rule: result.rule,
                entries: updatedEntries,
                totalBytes: result.totalBytes,
                totalFiles: result.totalFiles,
                skippedPermissionCount: result.skippedPermissionCount
            )
        }
        scanSummary = ScanSummary(
            results: updatedResults,
            diskSpace: current.diskSpace,
            scannedAt: current.scannedAt,
            durationSeconds: current.durationSeconds,
            totalSkippedPermissions: current.totalSkippedPermissions
        )
    }

    func executeClean() {
        let targets = selectedEntries
        guard !targets.isEmpty, !isCleaning else { return }

        isShowingDryRunConfirmation = false
        isCleaning = true
        cleanStatusText = "Preparando limpeza..."

        let mode = cleanMode
        let currentExclusions = exclusions

        Task { [weak self] in
            guard let owner = self else { return }
            let cleaner = CleanerEngine()
            let report = await cleaner.clean(entries: targets, mode: mode, exclusions: currentExclusions) { current, total, name in
                Task { @MainActor in
                    owner.cleanStatusText = "Removendo (\(current)/\(total)): \(name)"
                }
            }

            owner.isCleaning = false
            owner.cleanStatusText = ""
            owner.lastCleanReport = report
            owner.selectedEntryIDs.removeAll()
            owner.diskSpace = DiskSpaceInfo.current()
            owner.startScan()
        }
    }

    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
