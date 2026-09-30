import XCTest
@testable import SkillDeck

final class WellKnownSkillServiceTests: XCTestCase {

    // MARK: - isWellKnownSource Tests

    func testIsWellKnownSource_domainNames() {
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("uizze.sh"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("uizze.com"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("smithery.ai"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("open.feishu.cn"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("uizze.sh/ios-design"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("https://uizze.sh"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("https://uizze.com/pack"))
        XCTAssertTrue(WellKnownSkillService.isWellKnownSource("https://uizze.sh/.well-known/agent-skills/index.json"))
    }

    func testIsWellKnownSource_githubRepos() {
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("vercel-labs/skills"))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("crossoverJie/skills"))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("https://github.com/vercel-labs/skills"))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("https://github.com/vercel-labs/skills.git"))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("git@github.com:crossoverJie/skills.git"))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("https://gitlab.com/owner/repo.git"))
    }

    func testIsWellKnownSource_emptyOrInvalid() {
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource(""))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("   "))
        XCTAssertFalse(WellKnownSkillService.isWellKnownSource("plainword"))
    }

    // MARK: - normalizeInput Tests

    func testNormalizeInput_domainOnly() {
        let (baseURL, skillSelector, displaySource, sourceUrl) = WellKnownSkillService.normalizeInput("uizze.sh")
        XCTAssertEqual(baseURL.absoluteString, "https://uizze.sh")
        XCTAssertNil(skillSelector)
        XCTAssertEqual(displaySource, "uizze.sh")
        XCTAssertEqual(sourceUrl, "https://uizze.sh")
    }

    func testNormalizeInput_domainWithSkill() {
        let (baseURL, skillSelector, displaySource, sourceUrl) = WellKnownSkillService.normalizeInput("uizze.sh/ios-design")
        XCTAssertEqual(baseURL.absoluteString, "https://uizze.sh")
        XCTAssertEqual(skillSelector, "ios-design")
        XCTAssertEqual(displaySource, "uizze.sh")
        XCTAssertEqual(sourceUrl, "https://uizze.sh")
    }

    func testNormalizeInput_httpsURL() {
        let (baseURL, skillSelector, displaySource, sourceUrl) = WellKnownSkillService.normalizeInput("https://uizze.com")
        XCTAssertEqual(baseURL.absoluteString, "https://uizze.com")
        XCTAssertNil(skillSelector)
        XCTAssertEqual(displaySource, "uizze.com")
        XCTAssertEqual(sourceUrl, "https://uizze.com")
    }

    func testNormalizeInput_wellKnownDirectURL() {
        let (baseURL, skillSelector, displaySource, sourceUrl) = WellKnownSkillService.normalizeInput("https://uizze.sh/.well-known/agent-skills/index.json")
        XCTAssertEqual(baseURL.absoluteString, "https://uizze.sh")
        XCTAssertNil(skillSelector)
        XCTAssertEqual(displaySource, "uizze.sh")
        XCTAssertEqual(sourceUrl, "https://uizze.sh")
    }

    // MARK: - Transport regressions

    /// Actor isolation makes request counts safe across asynchronous test callbacks.
    private actor RequestLog {
        var urls: [URL] = []
        func record(_ url: URL) { urls.append(url) }
    }

    func testCancelledRequestStopsWithoutRetryOrEndpointFallback() async throws {
        let log = RequestLog()
        let service = WellKnownSkillService(requestLoader: { request in
            await log.record(request.url!)
            throw URLError(.cancelled)
        })
        do {
            _ = try await service.discoverSkills(from: "uizze.sh")
            XCTFail("Cancellation must propagate")
        } catch is CancellationError {
            let urls = await log.urls
            XCTAssertEqual(urls.count, 1)
        }
    }

    func testDiscoveryDownloadsSkillMDIntoTemporaryDirectory() async throws {
        let service = WellKnownSkillService(requestLoader: { request in
            let url = request.url!
            let body = url.path.hasSuffix("index.json")
                ? #"{"skills":[{"name":"ios-design","type":"skill-md","url":"ios-design/SKILL.md"}]}"#
                : "---\nname: ios-design\ndescription: iOS design fixture\n---\n# Test skill\n"
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let result = try await service.discoverSkills(from: "uizze.sh")
        defer { try? FileManager.default.removeItem(at: result.tempDir) }
        let entry = try XCTUnwrap(result.skills.first)
        XCTAssertEqual(entry.skill.id, "ios-design")
        XCTAssertTrue(entry.skill.markdownBody.contains("# Test skill"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.localDir.appendingPathComponent("SKILL.md").path))
    }

    func testCancellationDuringDownloadIsNotSwallowedByMetadataFallback() async throws {
        let service = WellKnownSkillService(requestLoader: { request in
            let url = request.url!
            if !url.path.hasSuffix("index.json") { throw CancellationError() }
            let body = #"{"skills":[{"name":"ios-design","type":"skill-md","url":"ios-design/SKILL.md"}]}"#
            return (Data(body.utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await service.discoverSkills(from: "uizze.sh")
            XCTFail("A cancelled scan must not return apparently installable skills")
        } catch is CancellationError { }
    }

    func testMissingIndexDoesNotSwitchToDifferentDomain() async throws {
        let log = RequestLog()
        let service = WellKnownSkillService(requestLoader: { request in
            let url = request.url!
            await log.record(url)
            return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        })
        do {
            _ = try await service.discoverSkills(from: "uizze.sh")
            XCTFail("Missing indexes must be reported")
        } catch WellKnownSkillService.WellKnownError.noSkillsFound { }
        let urls = await log.urls
        XCTAssertEqual(urls.map(\.host), ["uizze.sh", "uizze.sh"])
        XCTAssertEqual(urls.map(\.path), ["/.well-known/agent-skills/index.json", "/.well-known/skills/index.json"])
    }

    /// Opt in explicitly: failures must fail the test, not silently pass as 'offline'.
    /// Download only into service-owned temporary storage; never install/delete user skills.
    func testLiveUizzeArchiveDownload() async throws {
        guard ProcessInfo.processInfo.environment["SKILLDECK_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Set SKILLDECK_LIVE_TESTS=1 to verify the live source")
        }
        let service = WellKnownSkillService()
        let result = try await service.discoverSkills(from: "uizze.sh")
        defer { try? FileManager.default.removeItem(at: result.tempDir) }
        let entry = try XCTUnwrap(result.skills.first { $0.skill.id == "ios-design" })
        let directory = try await service.ensureSkillDownloaded(
            skill: entry.unifiedSkill, targetDir: entry.localDir, indexURL: result.indexURL
        )
        let parsed = try SkillMDParser.parse(fileURL: directory.appendingPathComponent("SKILL.md"))
        XCTAssertEqual(parsed.metadata.name, "ios-design")
        XCTAssertFalse(parsed.markdownBody.isEmpty)
    }
}
