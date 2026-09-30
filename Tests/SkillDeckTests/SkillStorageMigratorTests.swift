import Foundation
import XCTest

@testable import SkillDeck

final class SkillStorageMigratorTests: XCTestCase {
    private var fixtureRoot: URL!
    private var layout: SkillStorageMigrationLayout!

    override func setUpWithError() throws {
        fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillStorageMigratorTests-\(UUID().uuidString)", isDirectory: true)

        let agentRoot = fixtureRoot.appendingPathComponent("agent-directories", isDirectory: true)
        let directDirectories = Dictionary(
            uniqueKeysWithValues: AgentType.allCases.map { agent in
                (agent, agentRoot.appendingPathComponent(agent.rawValue, isDirectory: true))
            }
        )

        let legacyURL = fixtureRoot
            .appendingPathComponent(".agents", isDirectory: true)
            .appendingPathComponent("skills", isDirectory: true)
        let claudeURL = try XCTUnwrap(directDirectories[.claudeCode])

        var readableDirectories = Dictionary(
            uniqueKeysWithValues: AgentType.allCases.map { ($0, [URL]()) }
        )
        readableDirectories[.codex] = [legacyURL]
        readableDirectories[.openCode] = [claudeURL, legacyURL]
        readableDirectories[.copilotCLI] = [claudeURL]
        readableDirectories[.cursor] = [claudeURL]

        layout = SkillStorageMigrationLayout(
            canonicalSkillsURL: fixtureRoot
                .appendingPathComponent(".skilldeck", isDirectory: true)
                .appendingPathComponent("skills", isDirectory: true),
            legacyCanonicalSkillsURL: legacyURL,
            backupURL: fixtureRoot
                .appendingPathComponent(".skilldeck", isDirectory: true)
                .appendingPathComponent("migration-backup-v1", isDirectory: true),
            markerURL: fixtureRoot
                .appendingPathComponent(".skilldeck", isDirectory: true)
                .appendingPathComponent(".storage-v1-migrated.json"),
            agentSkillsURLs: directDirectories,
            additionalReadableSkillsURLs: readableDirectories
        )
    }

    override func tearDownWithError() throws {
        if let fixtureRoot {
            try? FileManager.default.removeItem(at: fixtureRoot)
        }
    }

    func testMigrationMovesCanonicalFilesBacksUpLegacyAndCreatesDirectLinks() async throws {
        let legacySkill = try makeLegacySkill(named: "design-review", body: "version one")
        try makeSymlink(for: "design-review", from: .claudeCode, to: legacySkill)
        try makeSymlink(for: "design-review", from: .geminiCLI, to: legacySkill)

        let report = try await SkillStorageMigrator(layout: layout).migrateIfNeeded()

        let canonical = canonicalSkill(named: "design-review")
        let backup = layout.backupURL.appendingPathComponent("design-review", isDirectory: true)
        XCTAssertEqual(report.migratedSkillNames, ["design-review"])
        // Codex and OpenCode previously read the legacy shared directory. Claude, Gemini,
        // Copilot, and Cursor were available through their direct or inherited Claude paths.
        XCTAssertEqual(report.directLinkCount, 6)
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.appendingPathComponent("SKILL.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.appendingPathComponent("SKILL.md").path))
        XCTAssertFalse(entryExists(legacySkill))

        for agent in [
            AgentType.claudeCode,
            .codex,
            .geminiCLI,
            .copilotCLI,
            .openCode,
            .cursor,
        ] {
            let link = try XCTUnwrap(layout.agentSkillsURLs[agent])
                .appendingPathComponent("design-review")
            XCTAssertTrue(SymlinkManager.isSymlink(at: link), "Expected a direct link for \(agent)")
            XCTAssertEqual(
                link.resolvingSymlinksInPath().standardizedFileURL.path,
                canonical.standardizedFileURL.path
            )
        }
    }

    func testMigrationPreservesAgentEnabledOnlyThroughLegacySharedDirectory() async throws {
        _ = try makeLegacySkill(named: "shared-only", body: "shared")

        _ = try await SkillStorageMigrator(layout: layout).migrateIfNeeded()

        let canonical = canonicalSkill(named: "shared-only")
        for agent in [AgentType.codex, .openCode] {
            let link = try XCTUnwrap(layout.agentSkillsURLs[agent])
                .appendingPathComponent("shared-only")
            XCTAssertTrue(SymlinkManager.isSymlink(at: link))
            XCTAssertEqual(
                link.resolvingSymlinksInPath().standardizedFileURL.path,
                canonical.standardizedFileURL.path
            )
        }

        for agent in AgentType.allCases where agent != .codex && agent != .openCode {
            let target = try XCTUnwrap(layout.agentSkillsURLs[agent])
                .appendingPathComponent("shared-only")
            XCTAssertFalse(entryExists(target), "Did not expect a link for \(agent)")
        }
    }

    func testSecondMigrationIsIdempotent() async throws {
        _ = try makeLegacySkill(named: "repeatable", body: "same")
        let migrator = SkillStorageMigrator(layout: layout)

        let first = try await migrator.migrateIfNeeded()
        let second = try await migrator.migrateIfNeeded()

        XCTAssertEqual(first.migratedSkillNames, ["repeatable"])
        XCTAssertEqual(second.migratedSkillNames, [])
        XCTAssertEqual(second.directLinkCount, 0)
        XCTAssertTrue(entryExists(layout.markerURL))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: canonicalSkill(named: "repeatable").appendingPathComponent("SKILL.md").path
        ))
    }

    func testCanonicalConflictDoesNotOverwriteOrWriteCompletionMarker() async throws {
        let legacy = try makeLegacySkill(named: "conflict", body: "legacy copy")
        let canonical = canonicalSkill(named: "conflict")
        try makeSkill(at: canonical, body: "new copy")

        do {
            _ = try await SkillStorageMigrator(layout: layout).migrateIfNeeded()
            XCTFail("Expected canonical conflict")
        } catch let error as SkillStorageMigrator.MigrationError {
            XCTAssertEqual(error, .canonicalConflict("conflict"))
        }

        XCTAssertEqual(try skillBody(at: legacy), "legacy copy")
        XCTAssertEqual(try skillBody(at: canonical), "new copy")
        XCTAssertFalse(entryExists(layout.markerURL))
    }

    func testAgentOrdinaryDirectoryConflictIsNotOverwritten() async throws {
        let legacy = try makeLegacySkill(named: "agent-conflict", body: "legacy copy")
        let codexTarget = try XCTUnwrap(layout.agentSkillsURLs[.codex])
            .appendingPathComponent("agent-conflict", isDirectory: true)
        try makeSkill(at: codexTarget, body: "agent-owned copy")

        // Codex is effectively enabled through the legacy shared store. Its same-named ordinary
        // directory is a conflict and must never be replaced by the new direct link.
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))

        do {
            _ = try await SkillStorageMigrator(layout: layout).migrateIfNeeded()
            XCTFail("Expected Agent target conflict")
        } catch let error as SkillStorageMigrator.MigrationError {
            guard case .agentTargetConflict(let agent, let skillName, let path) = error else {
                return XCTFail("Unexpected migration error: \(error)")
            }
            XCTAssertEqual(agent, .codex)
            XCTAssertEqual(skillName, "agent-conflict")
            XCTAssertEqual(path, codexTarget.path)
        }

        XCTAssertFalse(SymlinkManager.isSymlink(at: codexTarget))
        XCTAssertEqual(try skillBody(at: codexTarget), "agent-owned copy")
        XCTAssertTrue(entryExists(legacy))
        XCTAssertFalse(entryExists(layout.markerURL))
    }

    private func makeLegacySkill(named name: String, body: String) throws -> URL {
        let url = layout.legacyCanonicalSkillsURL.appendingPathComponent(name, isDirectory: true)
        try makeSkill(at: url, body: body)
        return url
    }

    private func canonicalSkill(named name: String) -> URL {
        layout.canonicalSkillsURL.appendingPathComponent(name, isDirectory: true)
    }

    private func makeSkill(at url: URL, body: String) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try body.write(
            to: url.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func skillBody(at skillURL: URL) throws -> String {
        try String(contentsOf: skillURL.appendingPathComponent("SKILL.md"), encoding: .utf8)
    }

    private func makeSymlink(for skillName: String, from agent: AgentType, to destination: URL) throws {
        let directory = try XCTUnwrap(layout.agentSkillsURLs[agent])
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: directory.appendingPathComponent(skillName),
            withDestinationURL: destination
        )
    }

    private func entryExists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
            || (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil
    }
}
