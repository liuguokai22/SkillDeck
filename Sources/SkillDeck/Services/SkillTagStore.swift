import Foundation

/// A thread-safe storage service for user-assigned skill tags.
///
/// `SkillTagStore` is defined as an `actor` to ensure thread-safe access to its internal state.
/// Actors in Swift isolate their state and guarantee mutually exclusive access, preventing
/// data races when accessed concurrently from multiple tasks (such as the main actor context).
///
/// Tags are persisted to `~/.agents/.skilldeck-tags.json` as a simple JSON file.
/// This keeps tag data independent from SKILL.md files, since tags are user-specific
/// categorizations (like "科研", "求职") rather than inherent skill properties.
actor SkillTagStore {

    // MARK: - Storage Model

    /// Private structure for JSON serialization/deserialization.
    /// Conforms to `Codable` which lets Swift automatically synthesize encoding/decoding logic
    /// based on property types (similar to Java's Jackson @JsonProperty or Go's json tags).
    private struct StorageData: Codable {
        /// All known tag names, even if no skill currently uses them.
        /// Users can pre-create tags and assign them later.
        var knownTags: [String] = []

        /// Mapping of skill IDs to their assigned tag arrays.
        /// Key: skill directory name (e.g. "agent-notifier"), Value: tags (e.g. ["科研", "开发"])
        var skillTags: [String: [String]] = [:]
    }

    // MARK: - State

    private var data = StorageData()

    /// Default file URL for persistent storage: ~/.agents/.skilldeck-tags.json
    static let defaultFileURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agents")
            .appendingPathComponent(".skilldeck-tags.json")
    }()

    /// File URL for persistent storage.
    /// Uses the same `~/.agents/` directory convention as other SkillDeck storage files.
    private let fileURL: URL

    // MARK: - Initialization

    init(fileURL: URL = defaultFileURL) {
        self.fileURL = fileURL
    }

    // MARK: - Persistence

    /// Load tag data from disk. Called during SkillManager.refresh().
    /// If the file doesn't exist yet (first launch), starts with empty state.
    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let fileData = try Data(contentsOf: fileURL)
            data = try JSONDecoder().decode(StorageData.self, from: fileData)
        } catch {
            print("[SkillTagStore] Failed to load tags: \(error)")
        }
    }

    /// Save current tag data to disk.
    /// Uses atomic write to prevent data corruption from partial writes.
    func save() throws {
        // Ensure directory exists (creates ~/.agents/ if needed)
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let fileData = try encoder.encode(data)
        try fileData.write(to: fileURL, options: .atomic)
    }

    // MARK: - Query Methods

    /// Get tags assigned to a specific skill
    func getTags(for skillID: String) -> [String] {
        data.skillTags[skillID] ?? []
    }

    /// Get the complete skill-to-tags mapping (for bulk state sync to SkillManager)
    func getAllSkillTags() -> [String: [String]] {
        data.skillTags
    }

    /// Get all known tags (including ones not currently assigned to any skill)
    func getAllKnownTags() -> [String] {
        data.knownTags
    }

    // MARK: - Mutation Methods

    /// Add a tag to a specific skill.
    /// If the tag doesn't exist in knownTags, it is automatically added.
    func addTag(_ tag: String, to skillID: String) {
        // Add to known tags if new
        if !data.knownTags.contains(tag) {
            data.knownTags.append(tag)
        }

        // Add to skill's tags if not already present
        var tags = data.skillTags[skillID] ?? []
        if !tags.contains(tag) {
            tags.append(tag)
            data.skillTags[skillID] = tags
        }
    }

    /// Remove a tag from a specific skill (does NOT remove from knownTags)
    func removeTag(_ tag: String, from skillID: String) {
        guard var tags = data.skillTags[skillID] else { return }
        tags.removeAll { $0 == tag }
        if tags.isEmpty {
            data.skillTags.removeValue(forKey: skillID)
        } else {
            data.skillTags[skillID] = tags
        }
    }

    /// Set all tags for a specific skill (replaces existing tags)
    func setTags(for skillID: String, tags: [String]) {
        // Add any new tags to knownTags
        for tag in tags where !data.knownTags.contains(tag) {
            data.knownTags.append(tag)
        }
        data.skillTags[skillID] = tags.isEmpty ? nil : tags
    }

    /// Add a new known tag (without assigning it to any skill)
    func addKnownTag(_ tag: String) {
        if !data.knownTags.contains(tag) {
            data.knownTags.append(tag)
        }
    }

    /// Remove a known tag completely: removes from knownTags list AND from all skills
    func removeKnownTag(_ tag: String) {
        data.knownTags.removeAll { $0 == tag }

        // Also remove from all skills that have this tag
        for (skillID, tags) in data.skillTags {
            let filtered = tags.filter { $0 != tag }
            if filtered.isEmpty {
                data.skillTags.removeValue(forKey: skillID)
            } else {
                data.skillTags[skillID] = filtered
            }
        }
    }
}
