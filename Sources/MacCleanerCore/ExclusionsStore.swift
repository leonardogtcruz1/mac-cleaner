import Foundation

public final class ExclusionsStore: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "com.local.MacCleaner.exclusions"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func load() -> Set<String> {
        let array = userDefaults.stringArray(forKey: key) ?? []
        return Set(array.map(SafetyGuard.normalizePath))
    }

    public func save(_ exclusions: Set<String>) {
        let sorted = exclusions.map(SafetyGuard.normalizePath).sorted()
        userDefaults.set(sorted, forKey: key)
    }

    @discardableResult
    public func add(_ path: String) -> Set<String> {
        var current = load()
        current.insert(SafetyGuard.normalizePath(path))
        save(current)
        return current
    }

    @discardableResult
    public func remove(_ path: String) -> Set<String> {
        var current = load()
        current.remove(SafetyGuard.normalizePath(path))
        save(current)
        return current
    }
}
