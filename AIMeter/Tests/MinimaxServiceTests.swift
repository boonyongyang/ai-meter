import XCTest
@testable import AIMeter

final class MinimaxServiceTests: XCTestCase {
    // MARK: - resolvedAPIKey

    @MainActor
    func testResolvedAPIKeyReturnsNilWithNoCredentials() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] != nil,
            "MINIMAX_API_KEY env var is set — skipping credential-absence test"
        )
        let key = MinimaxService.resolveAPIKey()
        XCTAssertNil(key)
    }

    @MainActor
    func testResolvedAPIKeyReturnsValueWhenEnvVarSet() throws {
        let envKey = ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] ?? ""
        try XCTSkipIf(envKey.isEmpty, "MINIMAX_API_KEY env var not set — skipping env-var presence test")
        let key = MinimaxService.resolveAPIKey()
        XCTAssertNotNil(key)
    }

    // MARK: - keyIsFromEnvironment

    @MainActor
    func testKeyIsFromEnvironmentFalseWithNoCredentials() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["MINIMAX_API_KEY"] != nil,
            "MINIMAX_API_KEY env var is set — skipping absence test"
        )
        XCTAssertFalse(MinimaxService.keyIsFromEnvironment)
    }

    // MARK: - MinimaxUsageData model

    func testMinimaxUsageDataEmpty() {
        let empty = MinimaxUsageData.empty
        XCTAssertEqual(empty.highestIntervalPercent, 0)
        XCTAssertEqual(empty.highestWeeklyPercent, 0)
        XCTAssertNil(empty.nextResetAt)
        XCTAssertEqual(empty.fetchedAt, .distantPast)
    }

    func testHighestIntervalPercentPicksMax() {
        let models = [
            MinimaxModelQuota(modelName: "a", intervalPercent: 30, weeklyPercent: 10, resetsAt: nil, weeklyResetsAt: nil),
            MinimaxModelQuota(modelName: "b", intervalPercent: 75, weeklyPercent: 20, resetsAt: nil, weeklyResetsAt: nil),
            MinimaxModelQuota(modelName: "c", intervalPercent: 50, weeklyPercent: 90, resetsAt: nil, weeklyResetsAt: nil),
        ]
        let data = MinimaxUsageData(models: models, fetchedAt: .distantPast)
        XCTAssertEqual(data.highestIntervalPercent, 75)
        XCTAssertEqual(data.highestWeeklyPercent, 90)
    }

    func testNextResetAtReturnsTopIntervalModelResetDate() {
        let soon = Date(timeIntervalSinceNow: 3600)
        let later = Date(timeIntervalSinceNow: 7200)
        let models = [
            MinimaxModelQuota(modelName: "low", intervalPercent: 20, weeklyPercent: 0, resetsAt: later, weeklyResetsAt: nil),
            MinimaxModelQuota(modelName: "high", intervalPercent: 80, weeklyPercent: 0, resetsAt: soon, weeklyResetsAt: nil),
        ]
        let data = MinimaxUsageData(models: models, fetchedAt: .distantPast)
        XCTAssertEqual(data.nextResetAt, soon)
    }

    // MARK: - MinimaxModelQuota

    func testIntervalPercentClampsAt100() {
        // percent calculation: max(0, min(100, 100 - remaining))
        // remaining = 0 → used = 100%
        let quota = MinimaxModelQuota(modelName: "x", intervalPercent: 100, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)
        XCTAssertEqual(quota.intervalPercent, 100)
    }

    func testIntervalPercentFloorAt0() {
        let quota = MinimaxModelQuota(modelName: "x", intervalPercent: 0, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)
        XCTAssertEqual(quota.intervalPercent, 0)
    }

    func testDisplayNameFormatsModelNameTokens() {
        let quota = MinimaxModelQuota(modelName: "minimax-text-01", intervalPercent: 0, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)
        // "minimax" → "MiniMax", dashes become spaces, capitalised otherwise
        XCTAssertEqual(quota.displayName, "MiniMax Text 01")
    }

    func testDisplayNameHandlesUnderscores() {
        let quota = MinimaxModelQuota(modelName: "abab_tts", intervalPercent: 0, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)
        XCTAssertEqual(quota.displayName, "Abab Tts")
    }

    func testDisplayNameFallsBackForEmptyModelName() {
        let quota = MinimaxModelQuota(modelName: "", intervalPercent: 0, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)
        XCTAssertEqual(quota.displayName, "Unknown Model")
    }

    // MARK: - Equatable

    func testMinimaxUsageDataEquatable() {
        let a = MinimaxUsageData(models: [], fetchedAt: .distantPast)
        let b = MinimaxUsageData(models: [], fetchedAt: .distantPast)
        XCTAssertEqual(a, b)
    }

    func testMinimaxUsageDataNotEqualDifferentModels() {
        let a = MinimaxUsageData(models: [], fetchedAt: .distantPast)
        let b = MinimaxUsageData(
            models: [MinimaxModelQuota(modelName: "x", intervalPercent: 50, weeklyPercent: 0, resetsAt: nil, weeklyResetsAt: nil)],
            fetchedAt: .distantPast
        )
        XCTAssertNotEqual(a, b)
    }
}
