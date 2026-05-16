import Foundation

enum StoryCodex {
    static let settingName = "First Earth"
    static let villageName = "Blockshire"
    static let elderName = "Elder Mossbeak"
    static let caveName = "Tailblock Cave"
    static let shrineName = "Sky Gate Shrine"
    static let relicName = "Sky Relic"

    static let loreSummary = "First Earth is an ancient dinosaur age of clan rites, amber memory, migration songs, and stone shrines."

    static func riteDescription(for playerClass: PlayerClass) -> String {
        switch playerClass {
        case .guardian:
            return "Guardians carry the shell oath: stand between the herd and the storm."
        case .emberclaw:
            return "Emberclaws run the scout path, reading heat, ash, and danger before the clan arrives."
        case .stonesinger:
            return "Stonesingers keep the old rhythm, listening for memories sealed in amber and stone."
        }
    }

    static func classChosen(_ playerClass: PlayerClass) -> String {
        "\(playerClass.rawValue) rite chosen. \(elderName) waits with the clan story."
    }

    static func trainerReminder(name: String) -> String {
        "\(name): The rite is not a title. Clear Bramble Camp and prove the path."
    }

    static func elderSuccess(for step: QuestStep, previousStep: QuestStep) -> String {
        switch step {
        case .clearCamp:
            return "Mossbeak: The Sky Gate has gone silent. Clear Bramble Camp so the migration song can pass."
        case .recoverCaveRelic where previousStep == .returnToElder:
            return "Mossbeak: Bramblehide is yours. Enter \(caveName), where the clan keeps its oldest memory."
        case .completed:
            return "Mossbeak: The shrine sings again. \(villageName) will remember your first rite."
        default:
            return "Mossbeak lowers his crest and listens to the old stones."
        }
    }

    static func elderHint(for step: QuestStep, campDefeats: Int) -> String {
        switch step {
        case .chooseClass:
            return "Choose a rite mentor first: Guardian, Emberclaw, or Stonesinger."
        case .clearCamp:
            return "Bramble Camp still blocks the herd path: \(campDefeats)/\(GameProgress.requiredCampDefeats)."
        case .recoverCaveRelic:
            return "Find the \(relicName) inside \(caveName). The cave remembers more than stone."
        case .unlockSkyGate:
            return "Use the clan cache key at the Sky Gate. The shrine waits beyond it."
        case .restoreShrine:
            return "Carry the \(relicName) to \(shrineName) and wake the migration song."
        case .completed:
            return "\(villageName) remembers your deeds in amber and stone."
        case .speakToElder, .returnToElder:
            return "Speak with \(elderName). The clan story has turned toward you."
        }
    }

    static func questText(for step: QuestStep, campDefeats: Int, isDungeon: Bool, compact: Bool) -> String {
        switch step {
        case .chooseClass:
            return compact ? "Choose a clan rite." : "Choose a clan rite in \(villageName): Guardian, Emberclaw, or Stonesinger."
        case .speakToElder:
            return compact ? "Hear Mossbeak's warning." : "Hear \(elderName)'s warning about the silent Sky Gate."
        case .clearCamp:
            return compact ? "Clear camp: \(campDefeats)/\(GameProgress.requiredCampDefeats)." : "Clear Bramble Camp so the old migration path opens: \(campDefeats)/\(GameProgress.requiredCampDefeats)."
        case .returnToElder:
            return compact ? "Return for rite proof." : "Return to \(elderName) and receive proof of your first rite."
        case .recoverCaveRelic:
            if isDungeon {
                return compact ? "Find key. Face Sky Wyrm." : "Find the Cave Key, unlock the Boss Door, and calm the twisted Sky Wyrm."
            }
            return compact ? "Recover the Sky Relic." : "Enter \(caveName), the ancestral memory cave, and recover the \(relicName)."
        case .unlockSkyGate:
            return compact ? "Unlock Sky Gate." : "Unlock the Sky Gate with the clan cache key."
        case .restoreShrine:
            return compact ? "Wake the shrine." : "Reach \(shrineName) and wake the migration song."
        case .completed:
            return compact ? "Shrine restored. Explore." : "\(shrineName) sings again. Keep exploring First Earth."
        }
    }

    static func caveLocked() -> String {
        "Hear \(elderName)'s warning before entering \(caveName)."
    }

    static func enterCave() -> String {
        "\(caveName): find the key and calm the Sky Wyrm."
    }

    static func exitCave(hasRelic: Bool) -> String {
        hasRelic ? "\(relicName) secured. Return it to the Sky Gate." : "Returned to the clan paths of First Earth."
    }

    static func skyRelicRecovered() -> String {
        "\(relicName) recovered. The old migration song hums again."
    }

    static func skyGateOpened() -> String {
        "Sky Gate opened. Carry the clan memory to the shrine."
    }

    static func shrineRestored() -> String {
        "\(shrineName) restored. MVP complete."
    }

    static func bossDefeated() -> String {
        "Sky Wyrm calmed. Claim the \(relicName)."
    }

    static func markerCommuned(title: String) -> String {
        "The \(title) answers with amber memory."
    }
}
