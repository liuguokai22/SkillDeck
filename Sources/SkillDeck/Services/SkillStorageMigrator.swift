import Foundation

/// Filesystem locations owned by SkillDeck.
///
/// Skill source files intentionally live outside every Agent's discovery directory. Each Agent
/// receives an independently removable symlink, so disabling one Agent never removes the source
/// files or changes another Agent's assignment.
enum SkillStorage {
    static let rootURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".skilldeck", isDirectory: true)

    static let canonicalSkillsURL = rootURL
        .appendingPathComponent("skills", isDirectory: true)

    /// Before storage v1, SkillDeck kept real skill directories here. Codex and OpenCode could
    /// consequently discover every SkillDeck skill without an independently removable link.
    static let legacyCanonicalSkillsURL = AgentType.sharedSkillsDirectoryURL

    static let migrationBackupURL = rootURL
        .appendingPathComponent("migration-backup-v1", isDirectory: true)

    static let migrationMarkerURL = rootURL
        .appendingPathComponent(".storage-v1-migrated.json")
}

/// Injectable filesystem layout keeps migration tests away from the user's real home directory.
struct SkillStorageMigrationLayout: Sendable {
    let canonicalSkillsURL: URL
    let legacyCanonicalSkillsURL: URL
    let backupURL: URL
    let markerURL: URL
    let agentSkillsURLs: [AgentType: URL]
    let additionalReadableSkillsURLs: [AgentType: [URL]]

    static let live = SkillStorageMigrationLayout(
        canonicalSkillsURL: SkillStorage.canonicalSkillsURL,
        legacyCanonicalSkillsURL: SkillStorage.legacyCanonicalSkillsURL,
        backupURL: SkillStorage.migrationBackupURL,
        markerURL: SkillStorage.migrationMarkerURL,
        agentSkillsURLs: Dictionary(
            uniqueKeysWithValues: AgentType.allCases.map { ($0, $0.skillsDirectoryURL) }
        ),
        additionalReadableSkillsURLs: Dictionary(
            uniqueKeysWithValues: AgentType.allCases.map { agent in
                (agent, agent.additionalReadableSkillsDirectories.map(\.url))
            }
        )
    )
}

struct SkillStorageMigrationReport: Codable, Equatable, Sendable {
    let migratedSkillNames: [String]
    let directLinkCount: Int
    let backupPath: String

    var didMigrate: Bool { !migratedSkillNames.isEmpty }
}

/// One-time, restart-safe migration from `~/.agents/skills` to `~/.skilldeck/skills`.
///
/// The old directory is copied first, every effective Agent assignment is converted to a direct
/// link, and only then is the original entry moved into a recoverable backup. If any conflict is
/// found, migration stops without overwriting the conflicting user item and without writing the
/// completion marker, so the next launch can safely retry after the conflict is resolved.
actor SkillStorageMigrator {
    enum MigrationError: Error, LocalizedError, Equatable {
        case canonicalConflict(String)
        case agentTargetConflict(agent: AgentType, skillName: String, path: String)
        case backupConflict(String)
        case copiedSkillInvalid(String)

        var errorDescription: String? {
            switch self {
            case .canonicalConflict(let skillName):
                "Skill storage migration stopped because both the old and new stores contain different copies of '\(skillName)'."
            case .agentTargetConflict(let agent, let skillName, let path):
                "Skill storage migration did not overwrite \(agent.displayName)'s existing '\(skillName)' item at \(path)."
            case .backupConflict(let skillName):
                "Skill storage migration backup already contains a different '\(skillName)' item."
            case .copiedSkillInvalid(let skillName):
                "Skill storage migration could not verify SKILL.md after copying '\(skillName)'."
            }
        }
    }

    private struct Marker: Codable {
        let version: Int
        let completedAt: String
        let report: SkillStorageMigrationReport
    }

    private let layout: SkillStorageMigrationLayout
    private let fileManager: FileManager

    init(
        layout: SkillStorageMigrationLayout = .live,
        fileManager: FileManager = .default
    ) {
        self.layout = layout
        self.fileManager = fileManager
    }

    func migrateIfNeeded() throws -> SkillStorageMigrationReport {
        try fileManager.createDirectory(
            at: layout.canonicalSkillsURL,
            withIntermediateDirectories: true
        )

        if entryExists(layout.markerURL) {
            return SkillStorageMigrationReport(
                migratedSkillNames: [],
                directLinkCount: 0,
                backupPath: layout.backupURL.path
            )
        }

        let legacySkills = validLegacySkillEntries()
        var migratedNames: [String] = []
        var directLinkCount = 0

        for legacyEntry in legacySkills {
            let skillName = legacyEntry.lastPathComponent
            let legacySource = legacyEntry.resolvingSymlinksInPath()
            let enabledAgents = effectiveAgents(
                for: skillName,
                legacyCanonicalURL: legacySource
            )
            let canonicalDestination = layout.canonicalSkillsURL
                .appendingPathComponent(skillName, isDirectory: true)

            try materializeCanonicalCopy(
                from: legacySource,
                to: canonicalDestination,
                skillName: skillName
            )

            for agent in enabledAgents.sorted(by: { $0.rawValue < $1.rawValue }) {
                if try installDirectLink(
                    for: skillName,
                    canonicalURL: canonicalDestination,
                    agent: agent
                ) {
                    directLinkCount += 1
                }
            }

            try archiveLegacyEntry(legacyEntry, skillName: skillName)
            migratedNames.append(skillName)
        }

        let report = SkillStorageMigrationReport(
            migratedSkillNames: migratedNames.sorted(),
            directLinkCount: directLinkCount,
            backupPath: layout.backupURL.path
        )
        try writeMarker(report: report)
        return report
    }

    private func validLegacySkillEntries() -> [URL] {
        guard entryExists(layout.legacyCanonicalSkillsURL),
              let entries = try? fileManager.contentsOfDirectory(
                at: layout.legacyCanonicalSkillsURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return entries.filter { entry in
            let resolved = entry.resolvingSymlinksInPath()
            return fileManager.fileExists(
                atPath: resolved.appendingPathComponent("SKILL.md").path
            )
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func effectiveAgents(
        for skillName: String,
        legacyCanonicalURL: URL
    ) -> Set<AgentType> {
        var result = Set<AgentType>()
        let expectedPath = legacyCanonicalURL.standardizedFileURL.path

        for agent in AgentType.allCases {
            var readableRoots: [URL] = []
            if let primary = layout.agentSkillsURLs[agent] {
                readableRoots.append(primary)
            }
            readableRoots.append(contentsOf: layout.additionalReadableSkillsURLs[agent] ?? [])

            if readableRoots.contains(where: { root in
                let candidate = root.appendingPathComponent(skillName)
                guard entryExists(candidate) else { return false }
                return candidate.resolvingSymlinksInPath().standardizedFileURL.path == expectedPath
            }) {
                result.insert(agent)
            }
        }
        return result
    }

    private func materializeCanonicalCopy(
        from source: URL,
        to destination: URL,
        skillName: String
    ) throws {
        if entryExists(destination) {
            guard fileManager.contentsEqual(atPath: source.path, andPath: destination.path) else {
                throw MigrationError.canonicalConflict(skillName)
            }
        } else {
            try fileManager.copyItem(at: source, to: destination)
        }

        guard fileManager.fileExists(
            atPath: destination.appendingPathComponent("SKILL.md").path
        ) else {
            throw MigrationError.copiedSkillInvalid(skillName)
        }
    }

    /// Returns true when a link was created or retargeted, false when it was already correct.
    private func installDirectLink(
        for skillName: String,
        canonicalURL: URL,
        agent: AgentType
    ) throws -> Bool {
        guard let agentDirectory = layout.agentSkillsURLs[agent] else { return false }
        try fileManager.createDirectory(at: agentDirectory, withIntermediateDirectories: true)

        let target = agentDirectory.appendingPathComponent(skillName)
        if entryExists(target) {
            if SymlinkManager.isSymlink(at: target) {
                if target.resolvingSymlinksInPath().standardizedFileURL.path
                    == canonicalURL.standardizedFileURL.path {
                    return false
                }
                try fileManager.removeItem(at: target)
            } else {
                throw MigrationError.agentTargetConflict(
                    agent: agent,
                    skillName: skillName,
                    path: target.path
                )
            }
        }

        try fileManager.createSymbolicLink(at: target, withDestinationURL: canonicalURL)
        return true
    }

    private func archiveLegacyEntry(_ legacyEntry: URL, skillName: String) throws {
        try fileManager.createDirectory(at: layout.backupURL, withIntermediateDirectories: true)
        let backupDestination = layout.backupURL.appendingPathComponent(skillName)

        if entryExists(backupDestination) {
            let legacyResolved = legacyEntry.resolvingSymlinksInPath()
            let backupResolved = backupDestination.resolvingSymlinksInPath()
            guard fileManager.contentsEqual(
                atPath: legacyResolved.path,
                andPath: backupResolved.path
            ) else {
                throw MigrationError.backupConflict(skillName)
            }
            try fileManager.removeItem(at: legacyEntry)
        } else {
            try fileManager.moveItem(at: legacyEntry, to: backupDestination)
        }
    }

    private func writeMarker(report: SkillStorageMigrationReport) throws {
        let marker = Marker(
            version: 1,
            completedAt: ISO8601DateFormatter().string(from: Date()),
            report: report
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(marker).write(to: layout.markerURL, options: .atomic)
    }

    /// `FileManager.fileExists` follows links and returns false for a dangling symlink. Reading
    /// attributes detects both ordinary entries and dangling links, which migration must not cover.
    private func entryExists(_ url: URL) -> Bool {
        if fileManager.fileExists(atPath: url.path) {
            return true
        }
        return (try? fileManager.attributesOfItem(atPath: url.path)) != nil
    }
}
