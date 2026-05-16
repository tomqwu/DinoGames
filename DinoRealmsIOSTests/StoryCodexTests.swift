import XCTest
@testable import DinoRealmsIOS

final class StoryCodexTests: XCTestCase {
    func testLoreSummaryDefinesFirstEarthCulture() {
        XCTAssertEqual(StoryCodex.settingName, "First Earth")
        XCTAssertTrue(StoryCodex.loreSummary.contains("clan rites"))
        XCTAssertTrue(StoryCodex.loreSummary.contains("amber memory"))
        XCTAssertTrue(StoryCodex.loreSummary.contains("stone shrines"))
    }

    func testClassRitesHaveDistinctCulturalRoles() {
        XCTAssertTrue(StoryCodex.riteDescription(for: .guardian).contains("shell oath"))
        XCTAssertTrue(StoryCodex.riteDescription(for: .emberclaw).contains("scout path"))
        XCTAssertTrue(StoryCodex.riteDescription(for: .stonesinger).contains("amber and stone"))
    }

    func testQuestTextConnectsObjectivesToCulture() {
        let fullText = StoryCodex.questText(for: .clearCamp, campDefeats: 2, isDungeon: false, compact: false)
        let compactText = StoryCodex.questText(for: .clearCamp, campDefeats: 2, isDungeon: false, compact: true)

        XCTAssertTrue(fullText.contains("migration path"))
        XCTAssertTrue(fullText.contains("2/3"))
        XCTAssertTrue(compactText.contains("2/3"))
        XCTAssertLessThan(compactText.count, fullText.count)
    }

    func testElderAndBossDialogueCarryMainStoryArc() {
        XCTAssertTrue(StoryCodex.elderSuccess(for: .clearCamp, previousStep: .speakToElder).contains("Sky Gate"))
        XCTAssertTrue(StoryCodex.elderHint(for: .restoreShrine, campDefeats: 3).contains("migration song"))
        XCTAssertTrue(StoryCodex.bossDefeated().contains("Sky Wyrm"))
        XCTAssertTrue(StoryCodex.bossDefeated().contains("Sky Relic"))
    }
}
