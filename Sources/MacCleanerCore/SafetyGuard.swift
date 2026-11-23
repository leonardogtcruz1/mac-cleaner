import Foundation

public enum SafetyError: LocalizedError, Equatable, Sendable {
    case protectedSystemPath(String)
    case protectedSensitiveName(String)
    case userExcludedPath(String)
    case symlinkEscapesToProtectedRoot(String)

    public var errorDescription: String? {
        switch self {
        case .protectedSystemPath(let path):
            return "Caminho protegido pelo sistema não pode ser removido: \(path)"
        case .protectedSensitiveName(let name):
            return "Item sensível protegido (\(name)) não pode ser removido."
        case .userExcludedPath(let path):
            return "Item protegido pela sua lista de exclusões: \(path)"
        case .symlinkEscapesToProtectedRoot(let path):
            return "O diretório pai aponta para um caminho protegido do sistema: \(path)"
        }
    }
}

public enum SafetyGuard {
    private static let exactProtectedSystemRoots: [String] = [
        "/",
        "/Library",
        "/Applications",
        "/Users"
    ]

    private static let recursiveProtectedSystemRoots: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin"
    ]

    private static let exactProtectedHomeSubpaths: [String] = [
        "",
        "Desktop",
        "Documents",
        "Downloads",
        "Library",
        "Library/Application Support"
    ]

    private static let recursiveProtectedHomeSubpaths: [String] = [
        "Library/Keychains",
        ".ssh",
        ".gnupg",
        ".aws"
    ]

    public static let protectedComponentNames: Set<String> = [
        ".env",
        ".env.local",
        ".env.production",
        "credentials",
        "credentials.json",
        "settings.json",
        "auth.json",
        "id_rsa",
        "id_ed25519",
        "known_hosts",
        "login.keychain-db"
    ]

    public static func validate(
        url: URL,
        exclusions: Set<String>,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        // Check standardized path itself without resolving the final symlink target.
        let standardizedURL = url.standardizedFileURL
        let path = normalizePath(standardizedURL.path)
        let homePath = normalizePath(homeDirectory.standardizedFileURL.path)

        let exactProtectedPaths = Set(
            exactProtectedSystemRoots.map(normalizePath)
            + exactProtectedHomeSubpaths.map { sub in
                sub.isEmpty ? homePath : normalizePath("\(homePath)/\(sub)")
            }
        )

        if exactProtectedPaths.contains(path) {
            throw SafetyError.protectedSystemPath(path)
        }

        let recursiveProtectedPaths = (
            recursiveProtectedSystemRoots.map(normalizePath)
            + recursiveProtectedHomeSubpaths.map { normalizePath("\(homePath)/\($0)") }
        )

        for protectedRoot in recursiveProtectedPaths {
            if isEqualOrDescendant(path, of: protectedRoot) {
                throw SafetyError.protectedSystemPath(path)
            }
        }

        // Check resolved parent path to make sure a symlinked parent directory doesn't escape into protected roots.
        let parentURL = standardizedURL.deletingLastPathComponent()
        let resolvedParentPath = normalizePath(parentURL.resolvingSymlinksInPath().path)
        let resolvedHomePath = normalizePath(homeDirectory.resolvingSymlinksInPath().path)

        let resolvedRecursiveProtected = (
            recursiveProtectedSystemRoots.map { normalizePath(URL(fileURLWithPath: $0).resolvingSymlinksInPath().path) }
            + recursiveProtectedHomeSubpaths.map { normalizePath("\(resolvedHomePath)/\($0)") }
        )

        for protectedRoot in resolvedRecursiveProtected {
            if isEqualOrDescendant(resolvedParentPath, of: protectedRoot) {
                throw SafetyError.symlinkEscapesToProtectedRoot(path)
            }
        }

        for component in standardizedURL.pathComponents {
            let lowered = component.lowercased()
            if protectedComponentNames.contains(lowered) {
                throw SafetyError.protectedSensitiveName(component)
            }
        }

        let normalizedExclusions = exclusions.map { normalizePath(expandTilde($0, homeDirectory: homeDirectory)) }
        let resolvedCandidate = normalizePath("\(resolvedParentPath)/\(standardizedURL.lastPathComponent)")

        for excluded in normalizedExclusions where !excluded.isEmpty {
            if isEqualOrDescendant(path, of: excluded)
                || isEqualOrDescendant(excluded, of: path)
                || isEqualOrDescendant(resolvedCandidate, of: excluded)
                || isEqualOrDescendant(excluded, of: resolvedCandidate) {
                throw SafetyError.userExcludedPath(path)
            }
        }
    }

    public static func isProtected(
        url: URL,
        exclusions: Set<String>,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> Bool {
        do {
            try validate(url: url, exclusions: exclusions, homeDirectory: homeDirectory)
            return false
        } catch {
            return true
        }
    }

    public static func expandTilde(
        _ path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let home = normalizePath(homeDirectory.standardizedFileURL.path)
        if path == "~" {
            return home
        }
        if path.hasPrefix("~/") {
            let suffix = String(path.dropFirst(2))
            return "\(home)/\(suffix)"
        }
        return path
    }

    public static func normalizePath(_ path: String) -> String {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        if standardized.count > 1 && standardized.hasSuffix("/") {
            return String(standardized.dropLast())
        }
        return standardized
    }

    private static func isEqualOrDescendant(_ path: String, of root: String) -> Bool {
        if path == root { return true }
        if root == "/" { return path.hasPrefix("/") }
        return path.hasPrefix(root + "/")
    }
}
