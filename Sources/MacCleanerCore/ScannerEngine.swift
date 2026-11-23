import Foundation

public struct ScannerEngine: Sendable {
    public let homeDirectory: URL
    public let now: Date

    private struct Measurement {
        var sizeBytes: Int64
        var fileCount: Int
        var lastModified: Date?
        var skippedPermissions: Int
    }

    private struct TargetScanResult {
        var entries: [ScannedEntry]
        var skippedPermissions: Int
    }

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date()
    ) {
        self.homeDirectory = homeDirectory.standardizedFileURL
        self.now = now
    }

    public func scan(
        rules: [CleanerRule],
        exclusions: Set<String> = [],
        progress: (@Sendable (Int, Int, String) -> Void)? = nil
    ) async -> ScanSummary {
        let start = Date()
        let totalRules = rules.count
        let normalizedExclusions = exclusions

        var ruleResults: [ScanRuleResult] = []
        ruleResults.reserveCapacity(totalRules)
        var completed = 0

        await withTaskGroup(of: ScanRuleResult.self) { group in
            for rule in rules {
                group.addTask {
                    try? Task.checkCancellation()
                    return self.scanRule(rule, exclusions: normalizedExclusions)
                }
            }

            for await result in group {
                completed += 1
                if result.totalBytes > 0 || result.skippedPermissionCount > 0 {
                    ruleResults.append(result)
                }
                progress?(completed, totalRules, result.rule.name)
            }
        }

        let sortedResults = ruleResults
            .filter { !$0.entries.isEmpty || $0.skippedPermissionCount > 0 }
            .sorted { lhs, rhs in
                if lhs.totalBytes != rhs.totalBytes {
                    return lhs.totalBytes > rhs.totalBytes
                }
                return lhs.rule.name < rhs.rule.name
            }

        let totalSkipped = sortedResults.reduce(0) { $0 + $1.skippedPermissionCount }
        let duration = Date().timeIntervalSince(start)

        return ScanSummary(
            results: sortedResults,
            diskSpace: DiskSpaceInfo.current(),
            scannedAt: Date(),
            durationSeconds: duration,
            totalSkippedPermissions: totalSkipped
        )
    }

    private func scanRule(_ rule: CleanerRule, exclusions: Set<String>) -> ScanRuleResult {
        var entries: [ScannedEntry] = []
        var seenPaths = Set<String>()
        var skippedPermissions = 0

        for target in rule.targets {
            if Task.isCancelled { break }
            let targetResult = scanTarget(target, ruleID: rule.id, exclusions: exclusions)
            skippedPermissions += targetResult.skippedPermissions
            for entry in targetResult.entries {
                if seenPaths.insert(entry.id).inserted {
                    entries.append(entry)
                }
            }
        }

        entries.sort { $0.sizeBytes > $1.sizeBytes }
        let totalBytes = entries.reduce(0) { $0 + $1.sizeBytes }
        let totalFiles = entries.reduce(0) { $0 + $1.fileCount }

        return ScanRuleResult(
            rule: rule,
            entries: entries,
            totalBytes: totalBytes,
            totalFiles: totalFiles,
            skippedPermissionCount: skippedPermissions
        )
    }

    private func scanTarget(_ target: TargetSpec, ruleID: String, exclusions: Set<String>) -> TargetScanResult {
        switch target {
        case .directory(let rawPath):
            let url = resolveURL(rawPath)
            guard pathExists(at: url) else {
                return TargetScanResult(entries: [], skippedPermissions: 0)
            }
            let measurement = measureItem(at: url)
            guard measurement.sizeBytes > 0 else {
                return TargetScanResult(entries: [], skippedPermissions: measurement.skippedPermissions)
            }
            let entry = ScannedEntry(
                ruleID: ruleID,
                name: displayLabel(for: url),
                url: url,
                sizeBytes: measurement.sizeBytes,
                fileCount: measurement.fileCount,
                lastModified: measurement.lastModified,
                isProtected: SafetyGuard.isProtected(url: url, exclusions: exclusions, homeDirectory: homeDirectory)
            )
            return TargetScanResult(entries: [entry], skippedPermissions: measurement.skippedPermissions)

        case .directoryChildren(let rawPath, let excludeNames):
            return scanDirectoryChildren(at: resolveURL(rawPath), excludeNames: excludeNames, ruleID: ruleID, exclusions: exclusions)

        case .matchingFiles(let rawPath, let extensions, let olderThanDays):
            return scanMatchingFiles(at: resolveURL(rawPath), extensions: extensions, olderThanDays: olderThanDays, ruleID: ruleID, exclusions: exclusions)

        case .staleProjectArtifacts(let roots, let artifactNames, let olderThanDays, let maxDepth):
            return scanStaleProjectArtifacts(
                roots: roots,
                artifactNames: artifactNames,
                olderThanDays: olderThanDays,
                maxDepth: maxDepth,
                ruleID: ruleID,
                exclusions: exclusions
            )
        }
    }

    private func scanDirectoryChildren(
        at dirURL: URL,
        excludeNames: Set<String>,
        ruleID: String,
        exclusions: Set<String>
    ) -> TargetScanResult {
        guard isReadableDirectory(dirURL) else {
            let permissionDenied = isPermissionDeniedDirectory(dirURL) ? 1 : 0
            return TargetScanResult(entries: [], skippedPermissions: permissionDenied)
        }

        let fm = FileManager.default
        let children: [URL]
        do {
            children = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: []
            )
        } catch {
            return TargetScanResult(entries: [], skippedPermissions: isPermissionError(error) ? 1 : 0)
        }

        var entries: [ScannedEntry] = []
        var skipped = 0

        for child in children {
            if Task.isCancelled { break }
            let name = child.lastPathComponent
            if name == ".DS_Store" || excludeNames.contains(name) {
                continue
            }

            let measurement = measureItem(at: child)
            skipped += measurement.skippedPermissions
            guard measurement.sizeBytes > 0 else { continue }

            entries.append(
                ScannedEntry(
                    ruleID: ruleID,
                    name: name,
                    url: child,
                    sizeBytes: measurement.sizeBytes,
                    fileCount: measurement.fileCount,
                    lastModified: measurement.lastModified,
                    isProtected: SafetyGuard.isProtected(url: child, exclusions: exclusions, homeDirectory: homeDirectory)
                )
            )
        }

        return TargetScanResult(entries: entries, skippedPermissions: skipped)
    }

    private func scanMatchingFiles(
        at dirURL: URL,
        extensions: Set<String>,
        olderThanDays: Int,
        ruleID: String,
        exclusions: Set<String>
    ) -> TargetScanResult {
        guard isReadableDirectory(dirURL) else {
            let permissionDenied = isPermissionDeniedDirectory(dirURL) ? 1 : 0
            return TargetScanResult(entries: [], skippedPermissions: permissionDenied)
        }

        let lowercasedExts = Set(extensions.map { $0.lowercased() })
        let cutoff = now.addingTimeInterval(-Double(max(0, olderThanDays)) * 86_400)
        let fm = FileManager.default

        let children: [URL]
        do {
            children = try fm.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return TargetScanResult(entries: [], skippedPermissions: isPermissionError(error) ? 1 : 0)
        }

        var entries: [ScannedEntry] = []
        var skipped = 0

        for child in children {
            if Task.isCancelled { break }
            let ext = child.pathExtension.lowercased()
            guard lowercasedExts.contains(ext) else { continue }

            let values = try? child.resourceValues(forKeys: [.contentModificationDateKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }

            let modDate = values?.contentModificationDate
            if let modDate, modDate > cutoff {
                continue
            }

            let measurement = measureItem(at: child)
            skipped += measurement.skippedPermissions
            guard measurement.sizeBytes > 0 else { continue }

            entries.append(
                ScannedEntry(
                    ruleID: ruleID,
                    name: child.lastPathComponent,
                    url: child,
                    sizeBytes: measurement.sizeBytes,
                    fileCount: measurement.fileCount,
                    lastModified: modDate ?? measurement.lastModified,
                    isProtected: SafetyGuard.isProtected(url: child, exclusions: exclusions, homeDirectory: homeDirectory)
                )
            )
        }

        return TargetScanResult(entries: entries, skippedPermissions: skipped)
    }

    private func scanStaleProjectArtifacts(
        roots: [String],
        artifactNames: Set<String>,
        olderThanDays: Int,
        maxDepth: Int,
        ruleID: String,
        exclusions: Set<String>
    ) -> TargetScanResult {
        let cutoff = now.addingTimeInterval(-Double(max(0, olderThanDays)) * 86_400)
        let skippedSubdirs: Set<String> = [
            ".git", ".Trash", "Library", "DerivedData", "Pods", ".build", "__pycache__"
        ]
        let skippedExtensions: Set<String> = [
            "app", "xcodeproj", "xcworkspace", "playground", "framework", "bundle"
        ]

        var visitedDirs = Set<String>()
        var seenArtifactPaths = Set<String>()
        var entries: [ScannedEntry] = []
        var skippedPermissions = 0

        let fm = FileManager.default

        for rawRoot in roots {
            if Task.isCancelled { break }
            let rootURL = resolveURL(rawRoot)
            guard pathExists(at: rootURL) else { continue }

            var queue: [(url: URL, depth: Int)] = [(rootURL, 0)]
            var queueIndex = 0

            while queueIndex < queue.count {
                if Task.isCancelled { break }
                let (currentURL, depth) = queue[queueIndex]
                queueIndex += 1

                let canonical = SafetyGuard.normalizePath(currentURL.resolvingSymlinksInPath().path)
                guard visitedDirs.insert(canonical).inserted else { continue }

                let children: [URL]
                do {
                    children = try fm.contentsOfDirectory(
                        at: currentURL,
                        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                        options: []
                    )
                } catch {
                    if isPermissionError(error) {
                        skippedPermissions += 1
                    }
                    continue
                }

                var artifactChildren: [URL] = []
                var subdirChildren: [URL] = []
                var latestNonArtifactModDate: Date?

                for child in children {
                    let name = child.lastPathComponent
                    if name == ".DS_Store" { continue }

                    let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
                    let isSymlink = values?.isSymbolicLink ?? false
                    let isDir = values?.isDirectory ?? false

                    if artifactNames.contains(name) && isDir && !isSymlink {
                        artifactChildren.append(child)
                        continue
                    }

                    if let modDate = values?.contentModificationDate {
                        if let existing = latestNonArtifactModDate {
                            if modDate > existing { latestNonArtifactModDate = modDate }
                        } else {
                            latestNonArtifactModDate = modDate
                        }
                    }

                    if isDir && !isSymlink && depth < maxDepth {
                        let ext = child.pathExtension.lowercased()
                        if !skippedSubdirs.contains(name) && !skippedExtensions.contains(ext) {
                            subdirChildren.append(child)
                        }
                    }
                }

                if !artifactChildren.isEmpty {
                    let parentModDate = latestNonArtifactModDate
                        ?? (try? currentURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                    let isStale = parentModDate.map { $0 <= cutoff } ?? false

                    if isStale {
                        for artifactURL in artifactChildren {
                            let normalizedArtifact = SafetyGuard.normalizePath(artifactURL.standardizedFileURL.path)
                            guard seenArtifactPaths.insert(normalizedArtifact).inserted else { continue }

                            let measurement = measureItem(at: artifactURL)
                            skippedPermissions += measurement.skippedPermissions
                            guard measurement.sizeBytes > 0 else { continue }

                            let label = "\(currentURL.lastPathComponent)/\(artifactURL.lastPathComponent)"
                            entries.append(
                                ScannedEntry(
                                    ruleID: ruleID,
                                    name: label,
                                    url: artifactURL,
                                    sizeBytes: measurement.sizeBytes,
                                    fileCount: measurement.fileCount,
                                    lastModified: parentModDate ?? measurement.lastModified,
                                    isProtected: SafetyGuard.isProtected(
                                        url: artifactURL,
                                        exclusions: exclusions,
                                        homeDirectory: homeDirectory
                                    )
                                )
                            )
                        }
                    }
                }

                for subdir in subdirChildren {
                    queue.append((subdir, depth + 1))
                }
            }
        }

        return TargetScanResult(entries: entries, skippedPermissions: skippedPermissions)
    }

    private func measureItem(at url: URL) -> Measurement {
        let keys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .contentModificationDateKey,
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]

        guard let rootValues = try? url.resourceValues(forKeys: keys) else {
            return Measurement(sizeBytes: 0, fileCount: 0, lastModified: nil, skippedPermissions: 0)
        }

        if rootValues.isSymbolicLink == true {
            return Measurement(sizeBytes: 0, fileCount: 1, lastModified: rootValues.contentModificationDate, skippedPermissions: 0)
        }

        if rootValues.isDirectory != true {
            let size = Int64(rootValues.totalFileAllocatedSize ?? rootValues.fileAllocatedSize ?? 0)
            return Measurement(
                sizeBytes: size,
                fileCount: 1,
                lastModified: rootValues.contentModificationDate,
                skippedPermissions: 0
            )
        }

        var totalBytes: Int64 = 0
        var fileCount = 0
        var latestMod = rootValues.contentModificationDate
        var skippedPermissions = 0

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, error in
                if self.isPermissionError(error) {
                    skippedPermissions += 1
                }
                return true
            }
        ) else {
            let denied = isPermissionDeniedDirectory(url) ? 1 : 0
            return Measurement(sizeBytes: 0, fileCount: 0, lastModified: latestMod, skippedPermissions: denied)
        }

        for case let itemURL as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? itemURL.resourceValues(forKeys: keys) else {
                continue
            }
            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator.skipDescendants()
                }
                continue
            }
            if let mod = values.contentModificationDate {
                if let current = latestMod {
                    if mod > current { latestMod = mod }
                } else {
                    latestMod = mod
                }
            }
            if values.isRegularFile == true {
                let allocated = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                totalBytes += allocated
                fileCount += 1
            }
        }

        return Measurement(
            sizeBytes: totalBytes,
            fileCount: fileCount,
            lastModified: latestMod,
            skippedPermissions: skippedPermissions
        )
    }

    private func resolveURL(_ rawPath: String) -> URL {
        let expanded = SafetyGuard.expandTilde(rawPath, homeDirectory: homeDirectory)
        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    private func displayLabel(for url: URL) -> String {
        let path = SafetyGuard.normalizePath(url.path)
        let home = SafetyGuard.normalizePath(homeDirectory.path)
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~/" + String(path.dropFirst(home.count + 1))
        }
        return path
    }

    private func pathExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if exists { return true }
        // Also return true if it's a symlink
        return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }

    private func isReadableDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return FileManager.default.isReadableFile(atPath: url.path)
    }

    private func isPermissionDeniedDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        return !FileManager.default.isReadableFile(atPath: url.path)
    }

    private func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain && (nsError.code == Int(EACCES) || nsError.code == Int(EPERM)) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionError(underlying)
        }
        return false
    }
}
