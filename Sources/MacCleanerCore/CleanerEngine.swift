import Foundation

public struct CleanerEngine: Sendable {
    public let homeDirectory: URL

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory.standardizedFileURL
    }

    public func clean(
        entries: [ScannedEntry],
        mode: CleanMode,
        exclusions: Set<String>,
        progress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async -> CleanReport {
        // Sort shallower paths first so parent removals subsume nested selected entries.
        let sortedEntries = entries.sorted { lhs, rhs in
            let lCount = lhs.url.standardizedFileURL.pathComponents.count
            let rCount = rhs.url.standardizedFileURL.pathComponents.count
            if lCount != rCount {
                return lCount < rCount
            }
            return lhs.url.path < rhs.url.path
        }

        let fm = FileManager.default
        var removedPaths: [String] = []
        var reclaimedBytes: Int64 = 0
        var removedCount = 0
        var failures: [CleanFailure] = []

        let total = sortedEntries.count
        for (index, entry) in sortedEntries.enumerated() {
            let entryPath = SafetyGuard.normalizePath(entry.url.standardizedFileURL.path)
            progress?(index + 1, total, entry.name)

            if isNestedInsideAny(entryPath, parents: removedPaths) {
                continue
            }

            do {
                try SafetyGuard.validate(
                    url: entry.url,
                    exclusions: exclusions,
                    homeDirectory: homeDirectory
                )

                guard fm.fileExists(atPath: entryPath) else {
                    continue
                }

                switch mode {
                case .moveToTrash:
                    try fm.trashItem(at: entry.url, resultingItemURL: nil)
                case .permanentDelete:
                    try fm.removeItem(at: entry.url)
                }

                removedPaths.append(entryPath)
                reclaimedBytes += entry.sizeBytes
                removedCount += 1
            } catch {
                failures.append(CleanFailure(entry: entry, reason: error.localizedDescription))
            }
        }

        return CleanReport(
            reclaimedBytes: reclaimedBytes,
            removedCount: removedCount,
            failures: failures,
            mode: mode,
            completedAt: Date()
        )
    }

    private func isNestedInsideAny(_ path: String, parents: [String]) -> Bool {
        for parent in parents {
            if path == parent || path.hasPrefix(parent + "/") {
                return true
            }
        }
        return false
    }
}
