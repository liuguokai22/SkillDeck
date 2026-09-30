import Foundation

/// WellKnownSkillService handles discovery and downloading of skills from Well-Known endpoints (F10 extension).
///
/// Implements the Agent Skills Well-Known Discovery specification (v2 and v1):
/// - Primary endpoint: `/.well-known/agent-skills/index.json`
/// - Secondary endpoint: `/.well-known/skills/index.json`
/// - Schema v2 (`https://schemas.agentskills.io/discovery/0.2.0/schema.json`):
///   Supports archive (.zip) and single skill-md (.md) artifacts with digest verification.
/// - Schema v1 (legacy):
///   Supports multi-file downloading via individual file URLs.
///
/// Uses `actor` for thread safety, consistent with GitService and SkillRegistryService.
actor WellKnownSkillService {

    private let sessionProvider: NetworkSessionProvider

    /// An injected transport lets tests exercise cancellation and downloads without
    /// accessing the network or installing anything in the user's skill directories.
    private let requestLoader: (@Sendable (URLRequest) async throws -> (Data, URLResponse))?

    init(
        sessionProvider: NetworkSessionProvider = .shared,
        requestLoader: (@Sendable (URLRequest) async throws -> (Data, URLResponse))? = nil
    ) {
        self.sessionProvider = sessionProvider
        self.requestLoader = requestLoader
    }

    // MARK: - Constants

    static let wellKnownPaths = [
        ".well-known/agent-skills",
        ".well-known/skills"
    ]
    static let indexFilename = "index.json"

    // MARK: - Error Types

    enum WellKnownError: Error, LocalizedError {
        case invalidURL(String)
        case discoveryFailed(String)
        case noSkillsFound(String)
        case downloadFailed(String)
        case skillNotFound(String)
        case parseFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                "Invalid URL or domain: \(url)"
            case .discoveryFailed(let message):
                "Failed to discover skills from well-known endpoint: \(message)"
            case .noSkillsFound(let url):
                "No skills found at \(url). Make sure the server has a /.well-known/agent-skills/index.json or /.well-known/skills/index.json file."
            case .downloadFailed(let message):
                "Failed to download skill: \(message)"
            case .skillNotFound(let name):
                "Skill '\(name)' not found in well-known index."
            case .parseFailed(let message):
                "Failed to parse skill metadata: \(message)"
            }
        }
    }

    // MARK: - Discovery Index Models

    struct WellKnownIndexV2: Codable {
        let schema: String?
        let skills: [SkillEntryV2]

        enum CodingKeys: String, CodingKey {
            case schema = "$schema"
            case skills
        }

        struct SkillEntryV2: Codable {
            let name: String
            let description: String?
            let type: String? // "archive" or "skill-md"
            let url: String
            let digest: String?
        }
    }

    struct WellKnownIndexV1: Codable {
        let skills: [SkillEntryV1]

        struct SkillEntryV1: Codable {
            let name: String
            let description: String?
            let files: [String]?
        }
    }

    // MARK: - Unified Internal Skill Representation

    struct UnifiedWellKnownSkill: Sendable {
        let name: String
        let description: String
        let type: String // "archive", "skill-md", or "legacy"
        let artifactURL: URL
        let digest: String
        let legacyFiles: [String]?
    }

    struct DiscoveredWellKnownResult: Sendable {
        let source: String
        let sourceUrl: String
        let skills: [DiscoveredSkillEntry]
        let indexURL: URL
        let tempDir: URL
    }

    struct DiscoveredSkillEntry: Sendable {
        let skill: GitService.DiscoveredSkill
        let digest: String
        let localDir: URL
        let unifiedSkill: UnifiedWellKnownSkill
    }

    // MARK: - Source Classification

    /// Determines whether the given input string represents a Well-Known domain/endpoint rather than a GitHub repository.
    ///
    /// Rules:
    /// - Explicit GitHub URLs (`https://github.com/...`) and `.git` URLs are NOT Well-Known.
    /// - URLs with non-github host (`https://uizze.sh`) ARE Well-Known.
    /// - Shorthands containing a dot in the first component (`uizze.sh`, `uizze.sh/ios-design`) ARE Well-Known,
    ///   because GitHub usernames cannot contain dots.
    /// - Shorthands like `owner/repo` where owner has no dot ARE GitHub repositories.
    nonisolated static func isWellKnownSource(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("https://github.com/") ||
            lower.hasPrefix("http://github.com/") ||
            lower.hasPrefix("git@github.com:") ||
            lower.hasSuffix(".git") {
            return false
        }

        if lower.hasPrefix("https://") || lower.hasPrefix("http://") {
            guard let url = URL(string: trimmed), let host = url.host?.lowercased() else {
                return false
            }
            return host != "github.com"
        }

        let parts = trimmed.split(separator: "/")
        if let firstPart = parts.first {
            return firstPart.contains(".")
        }

        return false
    }

    /// Normalize user input into base URL, optional skill selector, and display source.
    ///
    /// e.g. "uizze.sh/ios-design" -> baseURL: "https://uizze.sh", skillSelector: "ios-design", displaySource: "uizze.sh"
    /// e.g. "https://uizze.sh" -> baseURL: "https://uizze.sh", skillSelector: nil, displaySource: "uizze.sh"
    nonisolated static func normalizeInput(_ input: String) -> (baseURL: URL, skillSelector: String?, displaySource: String, sourceUrl: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        var working = trimmed
        if !working.lowercased().hasPrefix("http://") && !working.lowercased().hasPrefix("https://") {
            working = "https://" + working
        }

        guard let parsed = URL(string: working) else {
            let fallback = URL(string: "https://\(trimmed)") ?? URL(fileURLWithPath: "/")
            return (fallback, nil, trimmed, working)
        }

        let host = parsed.host ?? trimmed
        var pathComponents = parsed.pathComponents.filter { $0 != "/" }

        var skillSelector: String?
        // Check if the path ends with /.well-known/.../index.json
        if working.contains(".well-known") {
            let base = working.components(separatedBy: "/.well-known")[0]
            let baseURL = URL(string: base) ?? parsed
            return (baseURL, nil, host, base)
        }

        // If there's 1 path component (e.g. uizze.sh/ios-design), treat it as skillSelector
        if pathComponents.count == 1 {
            skillSelector = pathComponents[0]
            pathComponents.removeAll()
        }

        var components = URLComponents()
        components.scheme = parsed.scheme ?? "https"
        components.host = parsed.host
        components.port = parsed.port
        if !pathComponents.isEmpty {
            components.path = "/" + pathComponents.joined(separator: "/")
        }

        let baseURL = components.url ?? parsed
        let sourceUrl = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        return (baseURL, skillSelector, host, sourceUrl)
    }

    // MARK: - Discovery

    /// Discover all skills from a Well-Known endpoint.
    func discoverSkills(from input: String) async throws -> DiscoveredWellKnownResult {
        let (baseURL, _, displaySource, sourceUrl) = Self.normalizeInput(input)

        let (unifiedSkills, indexURL) = try await fetchWellKnownIndex(baseURL: baseURL)
        guard !unifiedSkills.isEmpty else {
            throw WellKnownError.noSkillsFound(displaySource)
        }

        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SkillDeck-WellKnown-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // A cancelled scan must not leave a partially downloaded directory behind.
        var completed = false
        defer {
            if !completed { try? fm.removeItem(at: tempDir) }
        }
        var discoveredEntries: [DiscoveredSkillEntry] = []

        for skill in unifiedSkills {
            let skillDir = tempDir.appendingPathComponent(skill.name)
            try? fm.createDirectory(at: skillDir, withIntermediateDirectories: true)

            var extractedDir = skillDir
            var skillMetadata = SkillMetadata(name: skill.name, description: skill.description)
            var markdownBody = ""

            // Attempt to pre-download and extract for rich SKILL.md metadata during discovery.
            // If download fails during scan (e.g. temporary network/proxy glitch), we still
            // keep the skill using metadata from index.json so the user can select and install it.
            do {
                let actualDir = try await downloadAndExtractSkill(skill, to: skillDir, indexURL: indexURL)
                extractedDir = actualDir
                let skillMDURL = actualDir.appendingPathComponent("SKILL.md")
                if fm.fileExists(atPath: skillMDURL.path),
                   let parsed = try? SkillMDParser.parse(fileURL: skillMDURL) {
                    skillMetadata = parsed.metadata
                    markdownBody = parsed.markdownBody
                }
            } catch {
                try Self.propagateCancellation(error)
            }

            let discovered = GitService.DiscoveredSkill(
                id: skill.name,
                folderPath: skill.name,
                skillMDPath: "\(skill.name)/SKILL.md",
                metadata: skillMetadata,
                markdownBody: markdownBody
            )

            discoveredEntries.append(
                DiscoveredSkillEntry(
                    skill: discovered,
                    digest: skill.digest,
                    localDir: extractedDir,
                    unifiedSkill: skill
                )
            )
        }

        guard !discoveredEntries.isEmpty else {
            throw WellKnownError.noSkillsFound(displaySource)
        }

        try Task.checkCancellation()
        completed = true
        return DiscoveredWellKnownResult(
            source: displaySource,
            sourceUrl: sourceUrl,
            skills: discoveredEntries,
            indexURL: indexURL,
            tempDir: tempDir
        )
    }

    /// Ensure the skill is fully downloaded and extracted at targetDir before installation.
    func ensureSkillDownloaded(skill: UnifiedWellKnownSkill, targetDir: URL, indexURL: URL) async throws -> URL {
        let fm = FileManager.default
        let directSkillMD = targetDir.appendingPathComponent("SKILL.md")
        if fm.fileExists(atPath: directSkillMD.path) {
            return targetDir
        }
        if let located = locateSkillDirectory(in: targetDir) {
            return located
        }
        return try await downloadAndExtractSkill(skill, to: targetDir, indexURL: indexURL)
    }

    /// Fetch raw SKILL.md content for detail preview.
    func fetchSkillMDContent(source: String, skillId: String) async throws -> String {
        let (baseURL, _, _, _) = Self.normalizeInput(source)
        let (unifiedSkills, indexURL) = try await fetchWellKnownIndex(baseURL: baseURL)

        guard let target = unifiedSkills.first(where: { $0.name == skillId }) else {
            throw WellKnownError.skillNotFound(skillId)
        }

        if target.type == "skill-md" {
            let (data, http) = try await performDataRequest(for: target.artifactURL, accept: "text/markdown, text/plain, */*")
            guard http.statusCode == 200 else {
                throw WellKnownError.downloadFailed("HTTP \(http.statusCode)")
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw WellKnownError.parseFailed("Invalid UTF-8 encoding")
            }
            return text
        }

        // For archives or legacy, download to temporary dir and read SKILL.md
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SkillDeck-Preview-\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let actualDir = try await downloadAndExtractSkill(target, to: tempDir, indexURL: indexURL)
        let skillMDURL = actualDir.appendingPathComponent("SKILL.md")
        guard fm.fileExists(atPath: skillMDURL.path) else {
            throw WellKnownError.skillNotFound(skillId)
        }
        return try String(contentsOf: skillMDURL, encoding: .utf8)
    }

    /// Check if remote digest differs from current local digest.
    func checkUpdate(sourceUrl: String, skillName: String, currentDigest: String) async throws -> (hasUpdate: Bool, latestDigest: String) {
        let (baseURL, _, _, _) = Self.normalizeInput(sourceUrl)
        let (unifiedSkills, _) = try await fetchWellKnownIndex(baseURL: baseURL)
        guard let target = unifiedSkills.first(where: { $0.name == skillName }) else {
            throw WellKnownError.skillNotFound(skillName)
        }
        let hasUpdate = !target.digest.isEmpty && target.digest != currentDigest
        return (hasUpdate, target.digest)
    }

    // MARK: - Private Helpers

    /// Candidate discovery URLs to try in priority order.
    private func candidateIndexURLs(baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        let baseString = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString

        for path in Self.wellKnownPaths {
            if let url = URL(string: "\(baseString)/\(path)/\(Self.indexFilename)") {
                candidates.append(url)
            }
        }

        // If baseURL has subpath, also try domain root
        if let host = baseURL.host, (baseURL.pathComponents.filter { $0 != "/" }).count > 0 {
            let scheme = baseURL.scheme ?? "https"
            let rootString = "\(scheme)://\(host)"
            for path in Self.wellKnownPaths {
                if let url = URL(string: "\(rootString)/\(path)/\(Self.indexFilename)") {
                    if !candidates.contains(url) {
                        candidates.append(url)
                    }
                }
            }
        }

        return candidates
    }

    /// Use the configured transport for every attempt. A cancelled Swift task cannot
    /// be repaired by retrying or switching sessions; propagate cancellation instead.
    private func performDataRequest(
        for url: URL,
        accept: String = "application/json",
        maxRetries: Int = 2
    ) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.assumesHTTP3Capable = false
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue("SkillDeck", forHTTPHeaderField: "User-Agent")

        let session = await sessionProvider.dataSession()
        for attempt in 1...maxRetries {
            do {
                try Task.checkCancellation()
                let (data, response): (Data, URLResponse)
                if let requestLoader {
                    (data, response) = try await requestLoader(request)
                } else {
                    (data, response) = try await session.data(for: request)
                }
                guard let http = response as? HTTPURLResponse else {
                    throw WellKnownError.downloadFailed("Invalid HTTP response from \(url.absoluteString)")
                }
                return (data, http)
            } catch {
                try Self.propagateCancellation(error)
                guard attempt < maxRetries else { throw error }
                try await Task.sleep(for: .milliseconds(300 * attempt))
            }
        }
        throw WellKnownError.downloadFailed("Failed to connect to \(url.absoluteString)")
    }

    /// URLSession reports cancellation as URLError.cancelled, while Swift concurrency
    /// uses CancellationError. Normalize both so callers do not show a connection error.
    private static func propagateCancellation(_ error: Error) throws {
        try Task.checkCancellation()
        if error is CancellationError || (error as? URLError)?.code == .cancelled {
            throw CancellationError()
        }
    }

    /// Fetch and decode the Well-Known index from candidate endpoints.
    private func fetchWellKnownIndex(baseURL: URL) async throws -> ([UnifiedWellKnownSkill], URL) {
        let urls = candidateIndexURLs(baseURL: baseURL)
        var lastStatus: Int?
        var lastErrorMessage: String?

        for candidateURL in urls {
            let data: Data
            let http: HTTPURLResponse
            do {
                (data, http) = try await performDataRequest(for: candidateURL, accept: "application/json")
            } catch {
                try Self.propagateCancellation(error)
                lastErrorMessage = error.localizedDescription
                continue
            }

            lastStatus = http.statusCode
            guard http.statusCode == 200 else {
                continue
            }

            // Try decoding Discovery Schema v2
            if let v2Index = try? JSONDecoder().decode(WellKnownIndexV2.self, from: data), !v2Index.skills.isEmpty {
                var skills: [UnifiedWellKnownSkill] = []
                for entry in v2Index.skills {
                    guard let resolved = URL(string: entry.url, relativeTo: candidateURL)?.absoluteURL else {
                        continue
                    }
                    skills.append(
                        UnifiedWellKnownSkill(
                            name: entry.name,
                            description: entry.description ?? "",
                            type: entry.type ?? (entry.url.hasSuffix(".zip") ? "archive" : "skill-md"),
                            artifactURL: resolved,
                            digest: entry.digest ?? "",
                            legacyFiles: nil
                        )
                    )
                }
                if !skills.isEmpty {
                    return (skills, candidateURL)
                }
            }

            // Try decoding Discovery Schema v1
            if let v1Index = try? JSONDecoder().decode(WellKnownIndexV1.self, from: data), !v1Index.skills.isEmpty {
                var skills: [UnifiedWellKnownSkill] = []
                for entry in v1Index.skills {
                    skills.append(
                        UnifiedWellKnownSkill(
                            name: entry.name,
                            description: entry.description ?? "",
                            type: "legacy",
                            artifactURL: candidateURL,
                            digest: "",
                            legacyFiles: entry.files
                        )
                    )
                }
                if !skills.isEmpty {
                    return (skills, candidateURL)
                }
            }
        }

        if let msg = lastErrorMessage {
            throw WellKnownError.discoveryFailed("Failed to reach \(baseURL.absoluteString): \(msg)")
        }
        if let status = lastStatus, status != 404 {
            throw WellKnownError.discoveryFailed("Server at \(baseURL.absoluteString) returned HTTP \(status)")
        }
        throw WellKnownError.noSkillsFound(baseURL.absoluteString)
    }

    /// Download and extract a skill into the specified target directory.
    private func downloadAndExtractSkill(_ skill: UnifiedWellKnownSkill, to targetDir: URL, indexURL: URL) async throws -> URL {
        let fm = FileManager.default

        if skill.type == "archive" {
            let (data, http) = try await performDataRequest(for: skill.artifactURL, accept: "*/*")
            guard http.statusCode == 200 else {
                throw WellKnownError.downloadFailed("HTTP \(http.statusCode) for \(skill.artifactURL.absoluteString)")
            }

            let tempZip = fm.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
            try data.write(to: tempZip)
            defer { try? fm.removeItem(at: tempZip) }

            try extractZipArchive(at: tempZip, to: targetDir)

            if let located = locateSkillDirectory(in: targetDir) {
                return located
            }
            return targetDir
        } else if skill.type == "skill-md" {
            let (data, http) = try await performDataRequest(for: skill.artifactURL, accept: "text/markdown, text/plain, */*")
            guard http.statusCode == 200 else {
                throw WellKnownError.downloadFailed("HTTP \(http.statusCode) for \(skill.artifactURL.absoluteString)")
            }
            let fileURL = targetDir.appendingPathComponent("SKILL.md")
            try data.write(to: fileURL)
            return targetDir
        } else {
            // Legacy v1: fetch each file
            guard let files = skill.legacyFiles else {
                throw WellKnownError.parseFailed("No files listed in legacy index entry")
            }
            let baseSkillURL = indexURL.deletingLastPathComponent().appendingPathComponent(skill.name)
            for file in files {
                let fileRemoteURL = baseSkillURL.appendingPathComponent(file)
                let (data, http) = try await performDataRequest(for: fileRemoteURL, accept: "*/*")
                guard http.statusCode == 200 else {
                    throw WellKnownError.downloadFailed("HTTP \(http.statusCode) for \(fileRemoteURL.absoluteString)")
                }
                let localFileURL = targetDir.appendingPathComponent(file)
                try fm.createDirectory(at: localFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try data.write(to: localFileURL)
            }
            return targetDir
        }
    }

    /// Locate the directory containing SKILL.md.
    private func locateSkillDirectory(in rootURL: URL) -> URL? {
        let fm = FileManager.default
        let directSkillMD = rootURL.appendingPathComponent("SKILL.md")
        if fm.fileExists(atPath: directSkillMD.path) {
            return rootURL
        }

        if let contents = try? fm.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            for item in contents {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let subSkillMD = item.appendingPathComponent("SKILL.md")
                    if fm.fileExists(atPath: subSkillMD.path) {
                        return item
                    }
                }
            }
        }
        return nil
    }

    /// Extract a zip archive using macOS `ditto`.
    private func extractZipArchive(at archiveURL: URL, to destinationURL: URL) throws {
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzipProcess.arguments = ["-xk", archiveURL.path, destinationURL.path]

        try unzipProcess.run()
        unzipProcess.waitUntilExit()

        guard unzipProcess.terminationStatus == 0 else {
            throw WellKnownError.downloadFailed("Failed to extract zip archive.")
        }
    }
}
