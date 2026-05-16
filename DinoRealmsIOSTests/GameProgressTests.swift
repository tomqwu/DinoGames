import XCTest
@testable import DinoRealmsIOS

final class GameProgressTests: XCTestCase {
    func testCollectingAmberAddsXP() {
        var progress = GameProgress()
        progress.collectAmber()
        progress.collectAmber(amount: 3)

        XCTAssertEqual(progress.amber, 4)
        XCTAssertEqual(progress.xp, 40)
    }

    func testAdventureEventsAreUnique() {
        var progress = GameProgress()
        progress.collectRelic(id: "sun")
        progress.collectRelic(id: "sun")
        progress.discoverLandmark(id: "camp")
        progress.discoverLandmark(id: "camp")
        progress.commune(marker: "camp-stone")
        progress.commune(marker: "camp-stone")
        XCTAssertTrue(progress.openChest(id: "shore-chest"))
        XCTAssertFalse(progress.openChest(id: "shore-chest"))
        XCTAssertTrue(progress.defeatEnemy(id: "thorn-1"))
        XCTAssertFalse(progress.defeatEnemy(id: "thorn-1"))

        XCTAssertEqual(progress.relics, 1)
        XCTAssertEqual(progress.landmarks, 1)
        XCTAssertEqual(progress.openedChests, 1)
        XCTAssertEqual(progress.enemiesDefeated, 1)
        XCTAssertEqual(progress.xp, 210)
    }

    func testKeysUnlockGateOnce() {
        var progress = GameProgress()

        XCTAssertFalse(progress.unlockGate())
        progress.collectKey()
        XCTAssertTrue(progress.unlockGate())
        XCTAssertFalse(progress.unlockGate())

        XCTAssertEqual(progress.keys, 0)
        XCTAssertTrue(progress.gateUnlocked)
    }

    func testClassChoiceIsUniqueAndAffectsStats() {
        var progress = GameProgress()

        XCTAssertEqual(progress.playObjective(), .chooseClass)
        XCTAssertTrue(progress.chooseClass(.guardian))
        XCTAssertFalse(progress.chooseClass(.emberclaw))

        XCTAssertEqual(progress.playerClass, .guardian)
        XCTAssertEqual(progress.questStep, .speakToElder)
        XCTAssertEqual(progress.playObjective(), .talkToElder)
        XCTAssertEqual(progress.maxHealth, 7)
        XCTAssertEqual(progress.health, 7)
        XCTAssertEqual(progress.attackDamage, 1)
    }

    func testQuestChainAdvancesThroughCampAndReward() {
        var progress = GameProgress()

        XCTAssertTrue(progress.chooseClass(.emberclaw))
        XCTAssertTrue(progress.talkToElder())
        XCTAssertEqual(progress.questStep, .clearCamp)
        XCTAssertEqual(progress.playObjective(), .clearCamp(defeated: 0, required: GameProgress.requiredCampDefeats))

        XCTAssertTrue(progress.defeatEnemy(id: "bramble-1", isQuestTarget: true))
        XCTAssertEqual(progress.playObjective(), .clearCamp(defeated: 1, required: GameProgress.requiredCampDefeats))
        XCTAssertTrue(progress.defeatEnemy(id: "bramble-2", isQuestTarget: true))
        XCTAssertEqual(progress.questStep, .clearCamp)
        XCTAssertTrue(progress.defeatEnemy(id: "bramble-3", isQuestTarget: true))
        XCTAssertEqual(progress.questStep, .returnToElder)
        XCTAssertEqual(progress.playObjective(), .returnToElder)

        XCTAssertTrue(progress.talkToElder())
        XCTAssertEqual(progress.questStep, .recoverCaveRelic)
        XCTAssertEqual(progress.playObjective(), .enterCave)
        XCTAssertEqual(progress.gear, ["Bramblehide Harness"])
        XCTAssertEqual(progress.gold, 18)
        XCTAssertTrue(progress.canEnterDungeon)
    }

    func testSkyRelicGateAndShrineCompleteQuest() {
        var progress = GameProgress()

        XCTAssertTrue(progress.chooseClass(.stonesinger))
        XCTAssertTrue(progress.talkToElder())
        for index in 0..<GameProgress.requiredCampDefeats {
            XCTAssertTrue(progress.defeatEnemy(id: "camp-\(index)", isQuestTarget: true))
        }
        XCTAssertTrue(progress.talkToElder())

        progress.collectKey()
        progress.collectSkyRelic()
        XCTAssertEqual(progress.questStep, .unlockSkyGate)
        XCTAssertEqual(progress.playObjective(), .unlockSkyGate)
        XCTAssertTrue(progress.unlockGate())
        XCTAssertEqual(progress.questStep, .restoreShrine)
        XCTAssertEqual(progress.playObjective(), .restoreShrine)
        progress.discoverLandmark(id: "shrine", isShrine: true)

        XCTAssertEqual(progress.questStep, .completed)
        XCTAssertEqual(progress.playObjective(), .completed)
        XCTAssertTrue(progress.isComplete)
    }

    func testDungeonObjectivesReflectCaveState() {
        var progress = GameProgress()
        XCTAssertTrue(progress.chooseClass(.guardian))
        XCTAssertTrue(progress.talkToElder())
        for index in 0..<GameProgress.requiredCampDefeats {
            XCTAssertTrue(progress.defeatEnemy(id: "camp-\(index)", isQuestTarget: true))
        }
        XCTAssertTrue(progress.talkToElder())

        XCTAssertEqual(progress.playObjective(isInDungeon: true), .findCaveKey)
        progress.collectDungeonKey()
        XCTAssertEqual(progress.playObjective(isInDungeon: true), .unlockBossDoor)
        XCTAssertEqual(progress.playObjective(isInDungeon: true, bossDoorUnlocked: true), .defeatSkyWyrm)
        progress.defeatBoss()
        XCTAssertEqual(progress.playObjective(isInDungeon: true, bossDoorUnlocked: true, skyRelicVisible: true), .collectSkyRelic)
        progress.collectSkyRelic()
        XCTAssertEqual(progress.playObjective(isInDungeon: true, bossDoorUnlocked: true), .unlockSkyGate)
    }

    func testLevelingUsesTotalXPThresholds() {
        var progress = GameProgress()

        progress.collectRelic(id: "one")
        XCTAssertEqual(progress.level, 1)
        progress.collectRelic(id: "two")

        XCTAssertEqual(progress.level, 2)
        XCTAssertEqual(progress.maxHealth, 6)
        XCTAssertEqual(progress.health, 6)
    }

    func testDungeonKeyIsSeparateAndConsumed() {
        var progress = GameProgress()

        XCTAssertFalse(progress.useDungeonKey())
        progress.collectDungeonKey()
        XCTAssertEqual(progress.dungeonKeys, 1)
        XCTAssertTrue(progress.useDungeonKey())
        XCTAssertFalse(progress.useDungeonKey())

        XCTAssertEqual(progress.keys, 0)
        XCTAssertEqual(progress.dungeonKeys, 0)
    }

    func testBossAndSkyRelicAreUnique() {
        var progress = GameProgress()
        progress.defeatBoss()
        progress.defeatBoss()
        progress.collectSkyRelic()
        progress.collectSkyRelic()

        XCTAssertTrue(progress.bossDefeated)
        XCTAssertTrue(progress.skyRelicClaimed)
        XCTAssertEqual(progress.xp, 270)
    }

    func testHealthAndHeartContainerClampCorrectly() {
        var progress = GameProgress()
        progress.takeDamage(2)
        progress.heal()
        progress.increaseMaxHealth()
        progress.heal(10)

        XCTAssertEqual(progress.maxHealth, 6)
        XCTAssertEqual(progress.health, 6)
    }

    func testCompletionRequiresRelicsGateAndShrine() {
        var progress = GameProgress()
        for index in 0..<3 { progress.collectRelic(id: "relic-\(index)") }
        for index in 0..<3 { progress.discoverLandmark(id: "landmark-\(index)") }
        XCTAssertFalse(progress.isComplete)

        progress.collectKey()
        XCTAssertTrue(progress.unlockGate())
        progress.discoverLandmark(id: "shrine", isShrine: true)
        XCTAssertFalse(progress.isComplete)

        progress.collectSkyRelic()
        XCTAssertTrue(progress.isComplete)
    }
}
