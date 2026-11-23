import Foundation
import Testing
@testable import MacCleanerCore

private final class TempSandbox: @unchecked Sendable {
    let root: URL
    let fakeHome: URL

    init() throws {
        let unique = "MacCleanerTests-\(UUID().uuidString)"
        self.root = FileManager.default.temporaryDirectory
            .appendingPathComponent(unique, isDirectory: true)
            .standardizedFileURL
        self.fakeHome = root.appendingPathComponent("home", isDirectory: true)
        try FileManager.default.createDirectory(at: fakeHome, withIntermediateDirectories: true)
    }

    deinit {
        if FileManager.default.fileExists(atPath: root.path) {
            Self.restorePermissionsRecursively(at: root)
            try? FileManager.default.removeItem(at: root)
        }
    }

    func createSizedFile(
        at url: URL,
        byteCount: Int,
        modificationDate: Date? = nil
    ) throws {
        let data = Data(repeating: 0xAB, count: byteCount)
        try data.write(to: url)
        if let modificationDate {
            try FileManager.default.setAttributes([.modificationDate: modificationDate], ofItemAtPath: url.path)
        }
    }

    private static func restorePermissionsRecursively(at url: URL) {
        let fm = FileManager.default
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey]) {
            for case let child as URL in enumerator {
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                try? fm.setAttributes([.posixPermissions: isDir ? 0o755 : 0o644], ofItemAtPath: child.path)
            }
        }
    }
}

@Suite("MacCleanerCoreTests")
struct MacCleanerCoreTests {
    // MARK: - SafetyGuard Tests

    @Test("SafetyGuard blocks protected roots and sensitive files")
    func safetyGuardBlocksProtectedRootsAndSensitiveFiles() throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let protectedTargets = [
            URL(fileURLWithPath: "/"),
            URL(fileURLWithPath: "/System"),
            URL(fileURLWithPath: "/System/Library/Fonts"),
            URL(fileURLWithPath: "/usr/bin"),
            fakeHome,
            fakeHome.appendingPathComponent("Documents"),
            fakeHome.appendingPathComponent(".ssh"),
            fakeHome.appendingPathComponent(".ssh/id_rsa"),
            fakeHome.appendingPathComponent("Library/Keychains/login.keychain-db"),
            fakeHome.appendingPathComponent("projects/app/.env"),
            fakeHome.appendingPathComponent(".claude/settings.json"),
            fakeHome.appendingPathComponent(".codex/auth.json")
        ]

        for target in protectedTargets {
            #expect(throws: (any Error).self) {
                try SafetyGuard.validate(url: target, exclusions: [], homeDirectory: fakeHome)
            }
        }
    }

    @Test("SafetyGuard respects user exclusions and allows valid caches")
    func safetyGuardRespectsUserExclusionsAndAllowsValidCaches() throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let excludedDir = fakeHome.appendingPathComponent("Library/Caches/keep-me")
        let nestedInsideExcluded = excludedDir.appendingPathComponent("subdir/file.bin")
        let parentOfExcluded = fakeHome.appendingPathComponent("Library/Caches")
        let exclusions: Set<String> = [excludedDir.path]

        #expect(throws: (any Error).self) {
            try SafetyGuard.validate(url: excludedDir, exclusions: exclusions, homeDirectory: fakeHome)
        }
        #expect(throws: (any Error).self) {
            try SafetyGuard.validate(url: nestedInsideExcluded, exclusions: exclusions, homeDirectory: fakeHome)
        }
        #expect(throws: (any Error).self) {
            try SafetyGuard.validate(url: parentOfExcluded, exclusions: exclusions, homeDirectory: fakeHome)
        }

        let validCache = fakeHome.appendingPathComponent("Library/Caches/com.example.cache")
        try SafetyGuard.validate(url: validCache, exclusions: exclusions, homeDirectory: fakeHome)
    }

    @Test("SafetyGuard checks symlink parent escape without resolving leaf symlink")
    func safetyGuardChecksSymlinkParentEscapeWithoutResolvingLeafSymlink() throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let safeCacheDir = fakeHome.appendingPathComponent("Library/Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: safeCacheDir, withIntermediateDirectories: true)

        let benignSymlink = safeCacheDir.appendingPathComponent("link-to-system")
        try FileManager.default.createSymbolicLink(at: benignSymlink, withDestinationURL: URL(fileURLWithPath: "/System"))
        try SafetyGuard.validate(url: benignSymlink, exclusions: [], homeDirectory: fakeHome)

        let escapeParentLink = fakeHome.appendingPathComponent("escape-parent")
        try FileManager.default.createSymbolicLink(at: escapeParentLink, withDestinationURL: URL(fileURLWithPath: "/System"))
        let insideEscaped = escapeParentLink.appendingPathComponent("Library")
        #expect(throws: (any Error).self) {
            try SafetyGuard.validate(url: insideEscaped, exclusions: [], homeDirectory: fakeHome)
        }
    }

    // MARK: - ScannerEngine Tests

    @Test("Scanner computes directory children excluding specified names")
    func scannerComputesDirectoryChildrenExcludingSpecifiedNames() async throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let cachesDir = fakeHome.appendingPathComponent("Library/Caches", isDirectory: true)
        let appA = cachesDir.appendingPathComponent("AppA", isDirectory: true)
        let appB = cachesDir.appendingPathComponent("ExcludedApp", isDirectory: true)
        try FileManager.default.createDirectory(at: appA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: appB, withIntermediateDirectories: true)

        try sandbox.createSizedFile(at: appA.appendingPathComponent("data1.bin"), byteCount: 64 * 1024)
        try sandbox.createSizedFile(at: appA.appendingPathComponent("data2.bin"), byteCount: 32 * 1024)
        try sandbox.createSizedFile(at: appB.appendingPathComponent("ignored.bin"), byteCount: 128 * 1024)

        let rule = CleanerRule(
            id: "test-children",
            name: "Test Children",
            category: .systemAndApps,
            risk: .safe,
            summary: "Test",
            impactNote: "Test",
            targets: [.directoryChildren(path: "~/Library/Caches", excludeNames: ["ExcludedApp"])],
            defaultSelected: true
        )

        let scanner = ScannerEngine(homeDirectory: fakeHome)
        let summary = await scanner.scan(rules: [rule])

        #expect(summary.results.count == 1)
        let entries = summary.results[0].entries
        #expect(entries.count == 1)
        #expect(entries[0].name == "AppA")
        #expect(entries[0].fileCount == 2)
        #expect(entries[0].sizeBytes > 0)
    }

    @Test("Scanner matchingFiles respects olderThanDays")
    func scannerMatchingFilesRespectsOlderThanDays() async throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let downloads = fakeHome.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)

        let oldInstaller = downloads.appendingPathComponent("old-app.dmg")
        let freshInstaller = downloads.appendingPathComponent("new-app.dmg")
        let oldPdf = downloads.appendingPathComponent("manual.pdf")

        let now = Date()
        let oldDate = now.addingTimeInterval(-30 * 86_400)
        let freshDate = now.addingTimeInterval(-2 * 86_400)

        try sandbox.createSizedFile(at: oldInstaller, byteCount: 32 * 1024, modificationDate: oldDate)
        try sandbox.createSizedFile(at: freshInstaller, byteCount: 32 * 1024, modificationDate: freshDate)
        try sandbox.createSizedFile(at: oldPdf, byteCount: 32 * 1024, modificationDate: oldDate)

        let rule = CleanerRule(
            id: "test-dmg",
            name: "Old DMGs",
            category: .systemAndApps,
            risk: .moderate,
            summary: "Test",
            impactNote: "Test",
            targets: [.matchingFiles(path: "~/Downloads", extensions: ["dmg", "pkg"], olderThanDays: 14)],
            defaultSelected: false
        )

        let scanner = ScannerEngine(homeDirectory: fakeHome, now: now)
        let summary = await scanner.scan(rules: [rule])

        #expect(summary.results.count == 1)
        #expect(summary.results[0].entries.map(\.name) == ["old-app.dmg"])
    }

    @Test("Scanner handles unreadable directory gracefully")
    func scannerHandlesUnreadableDirectoryGracefully() async throws {
        if getuid() == 0 {
            return
        }

        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let targetDir = fakeHome.appendingPathComponent("Library/RestrictedCache", isDirectory: true)
        let lockedSubdir = targetDir.appendingPathComponent("locked", isDirectory: true)
        let openSubdir = targetDir.appendingPathComponent("open", isDirectory: true)
        try FileManager.default.createDirectory(at: lockedSubdir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: openSubdir, withIntermediateDirectories: true)
        try sandbox.createSizedFile(at: lockedSubdir.appendingPathComponent("secret.bin"), byteCount: 16 * 1024)
        try sandbox.createSizedFile(at: openSubdir.appendingPathComponent("ok.bin"), byteCount: 16 * 1024)

        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedSubdir.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: lockedSubdir.path)
        }

        let rule = CleanerRule(
            id: "test-perm",
            name: "Permission Test",
            category: .systemAndApps,
            risk: .safe,
            summary: "Test",
            impactNote: "Test",
            targets: [.directory(path: "~/Library/RestrictedCache")],
            defaultSelected: true
        )

        let scanner = ScannerEngine(homeDirectory: fakeHome)
        let summary = await scanner.scan(rules: [rule])

        #expect(summary.results.count == 1)
        #expect(summary.totalSkippedPermissions > 0)
        #expect(summary.results[0].totalBytes > 0)
    }

    @Test("Scanner stale project detector skips active projects and avoids double-counting nested artifacts")
    func scannerStaleProjectDetectorSkipsActiveAndDoesNotDoubleCountNested() async throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let now = Date()
        let oldDate = now.addingTimeInterval(-60 * 86_400)
        let recentDate = now.addingTimeInterval(-2 * 86_400)

        let projectsRoot = fakeHome.appendingPathComponent("Projects", isDirectory: true)
        let staleProject = projectsRoot.appendingPathComponent("legacy-web", isDirectory: true)
        let staleNodeModules = staleProject.appendingPathComponent("node_modules", isDirectory: true)
        let nestedNodeModules = staleNodeModules.appendingPathComponent("pkg-a/node_modules", isDirectory: true)

        let activeProject = projectsRoot.appendingPathComponent("active-app", isDirectory: true)
        let activeNodeModules = activeProject.appendingPathComponent("node_modules", isDirectory: true)

        try FileManager.default.createDirectory(at: nestedNodeModules, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: activeNodeModules, withIntermediateDirectories: true)

        try sandbox.createSizedFile(at: staleProject.appendingPathComponent("package.json"), byteCount: 1024, modificationDate: oldDate)
        try sandbox.createSizedFile(at: staleNodeModules.appendingPathComponent("index.js"), byteCount: 32 * 1024, modificationDate: oldDate)
        try sandbox.createSizedFile(at: nestedNodeModules.appendingPathComponent("sub.js"), byteCount: 16 * 1024, modificationDate: oldDate)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: staleProject.path)

        try sandbox.createSizedFile(at: activeProject.appendingPathComponent("package.json"), byteCount: 1024, modificationDate: recentDate)
        try sandbox.createSizedFile(at: activeNodeModules.appendingPathComponent("index.js"), byteCount: 64 * 1024, modificationDate: oldDate)

        let rule = CleanerRule(
            id: "test-stale",
            name: "Stale Projects",
            category: .staleProjects,
            risk: .moderate,
            summary: "Test",
            impactNote: "Test",
            targets: [
                .staleProjectArtifacts(
                    roots: ["~/Projects"],
                    artifactNames: ["node_modules", ".venv"],
                    olderThanDays: 30,
                    maxDepth: 4
                )
            ],
            defaultSelected: false
        )

        let scanner = ScannerEngine(homeDirectory: fakeHome, now: now)
        let summary = await scanner.scan(rules: [rule])

        #expect(summary.results.count == 1)
        let entries = summary.results[0].entries
        #expect(entries.count == 1)
        #expect(entries[0].name == "legacy-web/node_modules")
        #expect(entries[0].fileCount == 2)
    }

    // MARK: - CleanerEngine & ExclusionsStore Tests

    @Test("Cleaner deduplicates nested paths, respects exclusions, and deletes safely")
    func cleanerDeduplicatesNestedPathsRespectsExclusionsAndDeletesSafely() async throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let cacheParent = fakeHome.appendingPathComponent("Library/Caches/tool-cache", isDirectory: true)
        let cacheChild = cacheParent.appendingPathComponent("nested", isDirectory: true)
        let protectedFolder = fakeHome.appendingPathComponent("Library/Caches/keep-cache", isDirectory: true)

        try FileManager.default.createDirectory(at: cacheChild, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: protectedFolder, withIntermediateDirectories: true)

        try sandbox.createSizedFile(at: cacheParent.appendingPathComponent("top.bin"), byteCount: 16 * 1024)
        try sandbox.createSizedFile(at: cacheChild.appendingPathComponent("child.bin"), byteCount: 8 * 1024)
        try sandbox.createSizedFile(at: protectedFolder.appendingPathComponent("keep.bin"), byteCount: 32 * 1024)

        let parentEntry = ScannedEntry(
            ruleID: "r1",
            name: "tool-cache",
            url: cacheParent,
            sizeBytes: 24_576,
            fileCount: 2,
            lastModified: Date(),
            isProtected: false
        )
        let childEntry = ScannedEntry(
            ruleID: "r1",
            name: "nested",
            url: cacheChild,
            sizeBytes: 8_192,
            fileCount: 1,
            lastModified: Date(),
            isProtected: false
        )
        let protectedEntry = ScannedEntry(
            ruleID: "r1",
            name: "keep-cache",
            url: protectedFolder,
            sizeBytes: 32_768,
            fileCount: 1,
            lastModified: Date(),
            isProtected: true
        )

        let cleaner = CleanerEngine(homeDirectory: fakeHome)
        let report = await cleaner.clean(
            entries: [childEntry, parentEntry, protectedEntry],
            mode: .permanentDelete,
            exclusions: [protectedFolder.path]
        )

        #expect(!FileManager.default.fileExists(atPath: cacheParent.path))
        #expect(FileManager.default.fileExists(atPath: protectedFolder.path))
        #expect(report.removedCount == 1)
        #expect(report.reclaimedBytes == 24_576)
        #expect(report.failures.count == 1)
        #expect(report.failures[0].entry.name == "keep-cache")
    }

    @Test("ExclusionsStore persists and removes paths")
    func exclusionsStorePersistsAndRemovesPaths() throws {
        let sandbox = try TempSandbox()
        let fakeHome = sandbox.fakeHome

        let suiteName = "MacCleanerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ExclusionsStore(userDefaults: defaults, key: "exclusions")
        #expect(store.load().isEmpty)

        let path = fakeHome.appendingPathComponent("Library/Caches/custom/").path
        store.add(path)
        #expect(store.load() == [SafetyGuard.normalizePath(path)])

        store.remove(path)
        #expect(store.load().isEmpty)
    }
}
