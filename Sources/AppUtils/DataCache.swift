import UIKit
import RealmSwift

/// A generic data cache model that stores string content with expiration support.
/// Uses Realm for persistent storage and supports configurable TTL (time-to-live).
@objcMembers
public class DataCache: Object, Codable {

    // MARK: - Configuration

    /// Global flag to disable caching. Set to `true` to bypass all cache operations.
    /// Useful for debugging or testing scenarios where fresh data is required.
    public static var isDisabled: Bool = false

    // MARK: - Properties

    /// The cached content as a string (typically JSON)
    @objc public dynamic var content = ""

    /// The date when this cache entry was created or last updated
    @objc public dynamic var date = Date()

    /// The expiration interval in seconds (default: 1 day)
    @objc public dynamic var expirationInterval: TimeInterval = TimeInterval.oneDay

    /// The unique key for this cache entry (primary key)
    @objc dynamic private var searchKey = ""

    /// Defines the primary key for Realm storage
    public override class func primaryKey() -> String? { "searchKey" }

    /// Initializes a new cache entry with content and search key
    /// - Parameters:
    ///   - content: The string content to cache
    ///   - searchKey: Unique identifier for this cache entry
    ///   - expirationInterval: Time interval before cache expires (default: 1 day)
    public init(content: String, searchKey: String, expirationInterval: TimeInterval = .oneDay) {
        self.content = content
        self.searchKey = searchKey
        self.expirationInterval = expirationInterval
    }

    public required override init() { }

    // MARK: - Save Methods

    /// Saves or updates a JSON string in the cache
    /// - Parameters:
    ///   - json: The JSON string to cache
    ///   - searchKey: Unique identifier for this cache entry
    ///   - expirationInterval: Optional custom expiration interval (default: 1 day)
    public static func save(json: String, searchKey: String, expirationInterval: TimeInterval? = nil) {
        do {
            let realm = try Realm()
            let interval = expirationInterval ?? .oneDay

            if let oldCache = realm.object(ofType: DataCache.self, forPrimaryKey: searchKey) {
                try realm.write {
                    oldCache.date = Date()
                    oldCache.content = json
                    oldCache.expirationInterval = interval
                }
            } else {
                let cache = DataCache(content: json, searchKey: searchKey, expirationInterval: interval)
                try realm.write {
                    realm.add(cache)
                }
            }
        } catch {
            print("DataCache Error: Failed to save cache for key '\(searchKey)': \(error)")
        }
    }

    /// Saves or updates a Codable object in the cache by converting it to JSON
    /// - Parameters:
    ///   - content: The Codable object to cache
    ///   - searchKey: Unique identifier for this cache entry
    ///   - expirationInterval: Optional custom expiration interval (default: 1 day)
    public static func save(content: Codable, searchKey: String, expirationInterval: TimeInterval? = nil) {
        guard let json = try? content.json() else {
            print("DataCache Error: Failed to convert content to JSON for key '\(searchKey)'")
            return
        }
        save(json: json, searchKey: searchKey, expirationInterval: expirationInterval)
    }

    // MARK: - Retrieve Methods

    /// Retrieves a cache entry for the given key if it exists and hasn't expired
    /// - Parameter searchKey: The unique identifier for the cache entry
    /// - Returns: The cache entry if found and not expired, nil otherwise
    public static func cacheFor(searchKey: String) -> DataCache? {
        guard !isDisabled else { return nil }
        do {
            let realm = try Realm()
            if let cache = realm.object(ofType: DataCache.self, forPrimaryKey: searchKey) {
                let timeSinceCache = Date().timeIntervalSince(cache.date)
                if timeSinceCache < cache.expirationInterval {
                    return cache
                }
            }
        } catch {
            print("DataCache Error: Failed to retrieve cache for key '\(searchKey)': \(error)")
        }
        return nil
    }

    // MARK: - Cache Management Methods

    /// Removes all cached entries from storage
    public static func clearAll() {
        do {
            let realm = try Realm()
            let allCaches = realm.objects(DataCache.self)
            try realm.write {
                realm.delete(allCaches)
            }
            print("DataCache: Successfully cleared all cache entries (\(allCaches.count) items)")
        } catch {
            print("DataCache Error: Failed to clear all caches: \(error)")
        }
    }

    /// Removes a specific cache entry by key
    /// - Parameter key: The search key of the cache entry to remove
    /// - Returns: True if the entry was found and removed, false otherwise
    @discardableResult
    public static func remove(forKey key: String) -> Bool {
        do {
            let realm = try Realm()
            if let cache = realm.object(ofType: DataCache.self, forPrimaryKey: key) {
                try realm.write {
                    realm.delete(cache)
                }
                print("DataCache: Successfully removed cache entry for key '\(key)'")
                return true
            }
        } catch {
            print("DataCache Error: Failed to remove cache for key '\(key)': \(error)")
        }
        return false
    }

    /// Returns the total count of cached entries
    /// - Returns: Number of cache entries in storage
    public static func count() -> Int {
        do {
            let realm = try Realm()
            return realm.objects(DataCache.self).count
        } catch {
            print("DataCache Error: Failed to get cache count: \(error)")
            return 0
        }
    }

    /// Returns all cache keys currently stored
    /// - Returns: Array of all cache keys
    public static func allKeys() -> [String] {
        do {
            let realm = try Realm()
            return realm.objects(DataCache.self).compactMap { $0.searchKey }
        } catch {
            print("DataCache Error: Failed to get all keys: \(error)")
            return []
        }
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// One day in seconds (86400)
    public static let oneDay: TimeInterval = 86400

    /// Convenience accessor for backward compatibility
    static let days: TimeInterval = oneDay
}
