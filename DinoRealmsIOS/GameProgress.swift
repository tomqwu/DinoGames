import Foundation

enum PlayerClass: String, CaseIterable, Equatable {
    case guardian = "Guardian"
    case emberclaw = "Emberclaw"
    case stonesinger = "Stonesinger"

    var maxHealthBonus: Int {
        switch self {
        case .guardian:
            return 2
        case .emberclaw, .stonesinger:
            return 0
        }
    }

    var attackDamage: Int {
        switch self {
        case .guardian, .stonesinger:
            return 1
        case .emberclaw:
            return 2
        }
    }

    var attackRangeBonus: Int {
        switch self {
        case .stonesinger:
            return 46
        case .guardian, .emberclaw:
            return 0
        }
    }

    var attackCooldown: TimeInterval {
        switch self {
        case .guardian:
            return 0.36
        case .emberclaw:
            return 0.26
        case .stonesinger:
            return 0.42
        }
    }
}

enum QuestStep: Int, Equatable {
    case chooseClass
    case speakToElder
    case clearCamp
    case returnToElder
    case recoverCaveRelic
    case unlockSkyGate
    case restoreShrine
    case completed
}

enum PlayObjective: Equatable {
    case chooseClass
    case talkToElder
    case clearCamp(defeated: Int, required: Int)
    case returnToElder
    case enterCave
    case findCaveKey
    case unlockBossDoor
    case defeatSkyWyrm
    case collectSkyRelic
    case unlockSkyGate
    case restoreShrine
    case completed
}

struct GameProgress: Equatable {
    static let requiredCampDefeats = 3

    private(set) var amber: Int = 0
    private(set) var relics: Int = 0
    private(set) var landmarks: Int = 0
    private(set) var xp: Int = 0
    private(set) var level: Int = 1
    private(set) var gold: Int = 0
    private(set) var health: Int = 5
    private(set) var maxHealth: Int = 5
    private(set) var keys: Int = 0
    private(set) var dungeonKeys: Int = 0
    private(set) var openedChests: Int = 0
    private(set) var enemiesDefeated: Int = 0
    private(set) var campEnemiesDefeated: Int = 0
    private(set) var bossDefeated: Bool = false
    private(set) var skyRelicClaimed: Bool = false
    private(set) var reachedShrine: Bool = false
    private(set) var gateUnlocked: Bool = false
    private(set) var playerClass: PlayerClass?
    private(set) var questStep: QuestStep = .chooseClass
    private(set) var gear: [String] = []

    private var relicIDs: Set<String> = []
    private var landmarkIDs: Set<String> = []
    private var markerIDs: Set<String> = []
    private var chestIDs: Set<String> = []
    private var enemyIDs: Set<String> = []
    private var questEnemyIDs: Set<String> = []
    private var gearIDs: Set<String> = []

    var isComplete: Bool {
        skyRelicClaimed && (questStep == .completed || (relics >= 3 && landmarks >= 4 && reachedShrine && gateUnlocked))
    }

    var classTitle: String {
        playerClass?.rawValue ?? "Untrained"
    }

    var xpToNextLevel: Int {
        level * 120
    }

    var canEnterDungeon: Bool {
        questStep.rawValue >= QuestStep.recoverCaveRelic.rawValue
    }

    var attackDamage: Int {
        playerClass?.attackDamage ?? 1
    }

    var attackRangeBonus: Int {
        playerClass?.attackRangeBonus ?? 0
    }

    var attackCooldown: TimeInterval {
        playerClass?.attackCooldown ?? 0.32
    }

    func playObjective(isInDungeon: Bool = false, bossDoorUnlocked: Bool = false, skyRelicVisible: Bool = false) -> PlayObjective {
        if isComplete {
            return .completed
        }

        switch questStep {
        case .chooseClass:
            return .chooseClass
        case .speakToElder:
            return .talkToElder
        case .clearCamp:
            return .clearCamp(defeated: campEnemiesDefeated, required: Self.requiredCampDefeats)
        case .returnToElder:
            return .returnToElder
        case .recoverCaveRelic:
            if skyRelicClaimed {
                return .unlockSkyGate
            }
            if bossDefeated || skyRelicVisible {
                return .collectSkyRelic
            }
            guard isInDungeon else {
                return .enterCave
            }
            if bossDoorUnlocked {
                return .defeatSkyWyrm
            }
            if dungeonKeys > 0 {
                return .unlockBossDoor
            }
            return .findCaveKey
        case .unlockSkyGate:
            return .unlockSkyGate
        case .restoreShrine:
            return .restoreShrine
        case .completed:
            return .completed
        }
    }

    @discardableResult
    mutating func chooseClass(_ playerClass: PlayerClass) -> Bool {
        guard self.playerClass == nil else { return false }
        self.playerClass = playerClass
        maxHealth += playerClass.maxHealthBonus
        health = maxHealth
        questStep = .speakToElder
        gainXP(20)
        return true
    }

    @discardableResult
    mutating func talkToElder() -> Bool {
        switch questStep {
        case .chooseClass:
            return false
        case .speakToElder:
            questStep = .clearCamp
            return true
        case .returnToElder:
            grantGear(id: "Bramblehide Harness", goldReward: 18, xpReward: 90)
            questStep = .recoverCaveRelic
            return true
        case .restoreShrine where reachedShrine && skyRelicClaimed:
            questStep = .completed
            grantGear(id: "Sky Gate Sigil", goldReward: 40, xpReward: 120)
            return true
        default:
            return false
        }
    }

    mutating func collectAmber(amount: Int = 1) {
        guard amount > 0 else { return }
        amber += amount
        gainXP(amount * 10)
    }

    mutating func collectGold(amount: Int) {
        guard amount > 0 else { return }
        gold += amount
    }

    mutating func collectRelic(id: String) {
        guard relicIDs.insert(id).inserted else { return }
        relics = relicIDs.count
        gainXP(75)
    }

    mutating func collectKey() {
        keys += 1
        gainXP(40)
    }

    mutating func collectDungeonKey() {
        dungeonKeys += 1
        gainXP(40)
    }

    mutating func openChest(id: String) -> Bool {
        guard chestIDs.insert(id).inserted else { return false }
        openedChests = chestIDs.count
        gainXP(20)
        return true
    }

    mutating func unlockGate() -> Bool {
        guard keys > 0, !gateUnlocked else { return false }
        keys -= 1
        gateUnlocked = true
        if questStep == .unlockSkyGate {
            questStep = .restoreShrine
        }
        gainXP(100)
        return true
    }

    mutating func useDungeonKey() -> Bool {
        guard dungeonKeys > 0 else { return false }
        dungeonKeys -= 1
        gainXP(25)
        return true
    }

    mutating func defeatEnemy(id: String, isQuestTarget: Bool = false) -> Bool {
        guard enemyIDs.insert(id).inserted else { return false }
        enemiesDefeated = enemyIDs.count
        gainXP(30)

        if isQuestTarget, questEnemyIDs.insert(id).inserted {
            campEnemiesDefeated = questEnemyIDs.count
            if questStep == .clearCamp && campEnemiesDefeated >= Self.requiredCampDefeats {
                questStep = .returnToElder
            }
        }
        return true
    }

    mutating func defeatBoss() {
        guard !bossDefeated else { return }
        bossDefeated = true
        gold += 30
        gainXP(150)
    }

    mutating func collectSkyRelic() {
        guard !skyRelicClaimed else { return }
        skyRelicClaimed = true
        if questStep == .recoverCaveRelic {
            questStep = .unlockSkyGate
        }
        gainXP(120)
    }

    mutating func discoverLandmark(id: String, isShrine: Bool = false) {
        if landmarkIDs.insert(id).inserted {
            landmarks = landmarkIDs.count
            gainXP(isShrine ? 150 : 35)
        }

        if isShrine {
            reachedShrine = true
            if gateUnlocked && skyRelicClaimed && questStep == .restoreShrine {
                questStep = .completed
            }
        }
    }

    mutating func commune(marker id: String) {
        guard markerIDs.insert(id).inserted else { return }
        gainXP(50)
    }

    mutating func takeDamage(_ amount: Int = 1) {
        guard amount > 0 else { return }
        health = max(0, health - amount)
    }

    mutating func heal(_ amount: Int = 1) {
        guard amount > 0 else { return }
        health = min(maxHealth, health + amount)
    }

    mutating func increaseMaxHealth() {
        maxHealth += 1
        health = maxHealth
        gainXP(60)
    }

    @discardableResult
    mutating func grantGear(id: String, goldReward: Int = 0, xpReward: Int = 0) -> Bool {
        guard gearIDs.insert(id).inserted else { return false }
        gear.append(id)
        collectGold(amount: goldReward)
        gainXP(xpReward)
        return true
    }

    private mutating func gainXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount

        while xp >= xpToNextLevel {
            level += 1
            maxHealth += 1
            health = maxHealth
        }
    }
}
