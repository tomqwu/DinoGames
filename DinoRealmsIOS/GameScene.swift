import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum GameArea {
        case overworld
        case dungeon
    }

    private enum ItemKind {
        case amber
        case relic
        case heart
        case skyRelic
    }

    private enum ChestReward {
        case key
        case dungeonKey
        case amber(Int)
        case gear(String, gold: Int)
        case heartContainer
    }

    private enum EnemyKind {
        case thornling
        case boss
    }

    private struct Item {
        let id: String
        let kind: ItemKind
        let area: GameArea
        let node: SKNode
    }

    private struct Landmark {
        let id: String
        let title: String
        let isShrine: Bool
        let node: SKNode
        var discovered = false
    }

    private struct QuestMarker {
        let id: String
        let title: String
        let node: SKNode
        var used = false
    }

    private struct Chest {
        let id: String
        let title: String
        let reward: ChestReward
        let area: GameArea
        let node: SKNode
        var opened = false
    }

    private struct Enemy {
        let id: String
        let kind: EnemyKind
        let area: GameArea
        let node: SKNode
        let home: CGPoint
        let phase: CGFloat
        let level: Int
        let isQuestTarget: Bool
        let maxHealth: Int
        var health: Int
    }

    private struct BrushPatch {
        let id: String
        let node: SKNode
        let containsHeart: Bool
        var cut = false
    }

    private enum NPCRole {
        case elder
        case trainer(PlayerClass)
    }

    private struct NPC {
        let id: String
        let name: String
        let role: NPCRole
        let node: SKNode
    }

    private enum ActionKind {
        case none
        case talk
        case train
        case open
        case enter
        case exit
        case unlock
        case locked
        case commune
        case attack
    }

    private struct ActionAffordance {
        let kind: ActionKind
        let buttonTitle: String
        let promptText: String?
        let highlightNode: SKNode?
    }

    private struct SceneObjective {
        let title: String
        let target: CGPoint
    }

    private let worldNode = SKNode()
    private let overworldNode = SKNode()
    private let dungeonNode = SKNode()
    private let hudNode = SKNode()
    private let cameraRig = SKCameraNode()
    private let dinoNode = SKNode()
    private let joystickBase = SKShapeNode(circleOfRadius: 56)
    private let joystickKnob = SKShapeNode(circleOfRadius: 24)
    private let actionButton = SKShapeNode(circleOfRadius: 50)
    private let actionLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hudLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let questLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let promptLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let objectiveNode = SKNode()
    private let objectiveArrow = SKShapeNode()
    private let objectiveLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let objectiveDistanceLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let interactionHighlight = SKShapeNode(rectOf: CGSize(width: 104, height: 104), cornerRadius: 0)

    private var progress = GameProgress()
    private var items: [Item] = []
    private var landmarks: [Landmark] = []
    private var questMarkers: [QuestMarker] = []
    private var chests: [Chest] = []
    private var enemies: [Enemy] = []
    private var brushPatches: [BrushPatch] = []
    private var npcs: [NPC] = []
    private var lockedGate: SKNode?
    private var caveEntrance: SKNode?
    private var dungeonExit: SKNode?
    private var bossDoor: SKNode?
    private var bossDoorUnlocked = false
    private var currentArea: GameArea = .overworld
    private var joystickTouch: UITouch?
    private var actionTouch: UITouch?
    private var joystickVector = CGVector.zero
    private var keyboardVector = CGVector.zero
    private var pressedKeys: Set<String> = []
    private var facingVector = CGVector(dx: 1, dy: 0)
    private var lastUpdateTime: TimeInterval = 0
    private var lastAttackTime: TimeInterval = -1
    private var lastPlayerDamageTime: TimeInterval = -1
    private var eventMessage: String?
    private var eventMessageUntil = Date.distantPast

    private let overworldSpawn = CGPoint(x: -390, y: -330)
    private let caveEntrancePosition = CGPoint(x: -255, y: 238)
    private let dungeonSpawn = CGPoint(x: -430, y: 0)
    private let dungeonExitPosition = CGPoint(x: -470, y: 0)
    private let bossDoorPosition = CGPoint(x: 190, y: 0)
    private let dungeonBounds = CGRect(x: -520, y: -260, width: 1040, height: 520)
    private let playerMoveSpeed: CGFloat = 260
    private let cameraFollowAmount: CGFloat = 0.18
    private let pickupRadius: CGFloat = 52
    private let npcInteractionRadius: CGFloat = 104
    private let chestInteractionRadius: CGFloat = 94
    private let caveInteractionRadius: CGFloat = 104
    private let gateInteractionRadius: CGFloat = 108
    private let markerInteractionRadius: CGFloat = 102

    override init(size: CGSize = CGSize(width: 1024, height: 768)) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }
        view.isMultipleTouchEnabled = true
        backgroundColor = UIColor(red: 0.12, green: 0.31, blue: 0.42, alpha: 1)
        addChild(worldNode)
        worldNode.addChild(overworldNode)
        worldNode.addChild(dungeonNode)
        dungeonNode.isHidden = true
        addChild(cameraRig)
        camera = cameraRig
        cameraRig.addChild(hudNode)

        buildIsland()
        buildDungeon()
        buildDinosaur()
        buildHUD()
        resize(to: size)
        updateHUD()
        showMessage("Choose a rite in the Class Yard.", duration: 2.2)
    }

    func resize(to newSize: CGSize) {
        guard newSize.width > 0, newSize.height > 0 else { return }
        size = newSize

        joystickBase.position = CGPoint(x: -newSize.width / 2 + 112, y: -newSize.height / 2 + 112)
        joystickKnob.position = joystickBase.position
        actionButton.position = CGPoint(x: newSize.width / 2 - 108, y: -newSize.height / 2 + 108)

        let compact = newSize.width < 700
        let topOffset: CGFloat = compact ? 94 : 58
        hudLabel.position = CGPoint(x: -newSize.width / 2 + 24, y: newSize.height / 2 - topOffset)
        questLabel.position = CGPoint(x: -newSize.width / 2 + 24, y: newSize.height / 2 - topOffset - 34)
        promptLabel.position = CGPoint(x: 0, y: -newSize.height / 2 + (compact ? 170 : 182))

        hudLabel.fontSize = compact ? 13 : 19
        questLabel.fontSize = compact ? 11 : 14
        promptLabel.fontSize = compact ? 15 : 18
        objectiveLabel.fontSize = compact ? 11 : 13
        objectiveDistanceLabel.fontSize = compact ? 9 : 10
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime == 0 ? 0 : min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        let inputVector = activeMovementVector
        let movement = CGPoint(x: inputVector.dx, y: inputVector.dy) * playerMoveSpeed * CGFloat(deltaTime)
        if movement.length > 0.001 {
            dinoNode.position += movement
            dinoNode.zRotation = atan2(movement.y, movement.x)
            facingVector = inputVector.normalized
            keepDinoInCurrentArea()
        }

        updateEnemies(deltaTime: deltaTime, currentTime: currentTime)
        checkEnemyContact(currentTime: currentTime)
        cameraRig.position = cameraRig.position.lerp(to: dinoNode.position, amount: cameraFollowAmount)
        checkWorldProgress()
        updateHUD()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let view = self.view else { continue }
            let viewLocation = touch.location(in: view)
            let sceneLocation = touch.location(in: self)

            if viewLocation.x < view.bounds.midX, joystickTouch == nil {
                joystickTouch = touch
                moveJoystick(to: sceneLocation)
            } else if actionTouch == nil {
                actionTouch = touch
                actionButton.alpha = 0.94
                performAction()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let joystickTouch, touches.contains(joystickTouch) else { return }
        moveJoystick(to: joystickTouch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouches(touches)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            switch directionName(for: press) {
            case "up", "down", "left", "right":
                pressedKeys.insert(directionName(for: press) ?? "")
                handled = true
            case "action":
                performAction()
                handled = true
            default:
                break
            }
        }

        if handled {
            updateKeyboardVector()
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let direction = directionName(for: press), direction != "action" {
                pressedKeys.remove(direction)
                handled = true
            }
        }

        if handled {
            updateKeyboardVector()
        } else {
            super.pressesEnded(presses, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let direction = directionName(for: press), direction != "action" {
                pressedKeys.remove(direction)
            }
        }
        updateKeyboardVector()
    }

    private var activeMovementVector: CGVector {
        if joystickTouch != nil {
            return joystickVector
        }
        return keyboardVector
    }

    private var rootNodeForCurrentArea: SKNode {
        currentArea == .overworld ? overworldNode : dungeonNode
    }

    private var usesCompactHUD: Bool {
        size.width < 700
    }

    private func directionName(for press: UIPress) -> String? {
        guard let keyCode = press.key?.keyCode else { return nil }

        switch keyCode {
        case .keyboardW, .keyboardUpArrow:
            return "up"
        case .keyboardS, .keyboardDownArrow:
            return "down"
        case .keyboardA, .keyboardLeftArrow:
            return "left"
        case .keyboardD, .keyboardRightArrow:
            return "right"
        case .keyboardSpacebar, .keyboardReturnOrEnter:
            return "action"
        default:
            return nil
        }
    }

    private func updateKeyboardVector() {
        var vector = CGPoint.zero
        if pressedKeys.contains("up") { vector.y += 1 }
        if pressedKeys.contains("down") { vector.y -= 1 }
        if pressedKeys.contains("left") { vector.x -= 1 }
        if pressedKeys.contains("right") { vector.x += 1 }
        if vector.length > 1 {
            vector = vector.normalized
        }

        keyboardVector = CGVector(dx: vector.x, dy: vector.y)
        if joystickTouch == nil {
            joystickKnob.position = joystickBase.position + vector * 48
        }
    }

    private func finishTouches(_ touches: Set<UITouch>) {
        if let joystickTouch, touches.contains(joystickTouch) {
            self.joystickTouch = nil
            joystickVector = .zero
            updateKeyboardVector()
        }

        if let actionTouch, touches.contains(actionTouch) {
            self.actionTouch = nil
            actionButton.alpha = 0.72
        }
    }

    private func moveJoystick(to sceneLocation: CGPoint) {
        let localPoint = CGPoint(
            x: sceneLocation.x - cameraRig.position.x,
            y: sceneLocation.y - cameraRig.position.y
        )
        let delta = localPoint - joystickBase.position
        let limited = delta.clamped(to: 48)
        joystickKnob.position = joystickBase.position + limited
        joystickVector = CGVector(dx: limited.x / 48, dy: limited.y / 48)
    }

    private func buildIsland() {
        let tileSize: CGFloat = 62
        for x in -9...9 {
            for y in -9...9 {
                let point = CGPoint(x: CGFloat(x) * 58, y: CGFloat(y) * 58)
                let radius = hypot(CGFloat(x), CGFloat(y))
                let edgeNoise = sin(CGFloat(x) * 1.7) * 0.55 + cos(CGFloat(y) * 1.3) * 0.35
                guard radius < 8.6 + edgeNoise else { continue }

                let isVillage = x < -3 && y < -3
                let isPath = isVillage || abs(x) < 2 || abs(y + 1) < 2 || (x > 4 && y > 3)
                let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize), cornerRadius: 0)
                tile.position = point
                if isPath {
                    tile.fillColor = UIColor(
                        red: (isVillage ? 0.48 : 0.43) + CGFloat.random(in: -0.025...0.025),
                        green: (isVillage ? 0.38 : 0.42) + CGFloat.random(in: -0.025...0.025),
                        blue: (isVillage ? 0.24 : 0.28) + CGFloat.random(in: -0.02...0.02),
                        alpha: 1
                    )
                } else {
                    tile.fillColor = UIColor(
                        red: 0.22 + CGFloat.random(in: -0.025...0.025),
                        green: 0.50 + CGFloat.random(in: -0.035...0.035),
                        blue: 0.25 + CGFloat.random(in: -0.025...0.025),
                        alpha: 1
                    )
                }
                tile.strokeColor = UIColor.black.withAlphaComponent(0.18)
                tile.lineWidth = 1.4
                tile.zPosition = -20

                let topEdge = SKShapeNode(rectOf: CGSize(width: tileSize - 8, height: 5), cornerRadius: 0)
                topEdge.position = CGPoint(x: 0, y: tileSize / 2 - 7)
                topEdge.fillColor = UIColor.white.withAlphaComponent(0.08)
                topEdge.strokeColor = .clear
                tile.addChild(topEdge)

                overworldNode.addChild(tile)
            }
        }

        spawnVillage()
        spawnTrees()
        spawnBrush()
        spawnItems()
        spawnChests()
        spawnEnemies()
        spawnLandmarks()
        spawnCaveEntrance()
        spawnGate()
        spawnMarkers()
    }

    private func buildDungeon() {
        dungeonNode.isHidden = true

        let rooms: [(CGRect, UIColor)] = [
            (CGRect(x: -500, y: -190, width: 260, height: 380), UIColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 1)),
            (CGRect(x: -210, y: -220, width: 330, height: 440), UIColor(red: 0.25, green: 0.26, blue: 0.29, alpha: 1)),
            (CGRect(x: 230, y: -220, width: 290, height: 440), UIColor(red: 0.30, green: 0.24, blue: 0.25, alpha: 1))
        ]

        for (room, color) in rooms {
            var x = room.minX
            while x <= room.maxX {
                var y = room.minY
                while y <= room.maxY {
                    let tile = makeDungeonTile(color: color)
                    tile.position = CGPoint(x: x, y: y)
                    dungeonNode.addChild(tile)
                    y += 58
                }
                x += 58
            }

            let outline = SKShapeNode(rect: room, cornerRadius: 0)
            outline.strokeColor = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
            outline.lineWidth = 6
            outline.fillColor = .clear
            outline.zPosition = -5
            dungeonNode.addChild(outline)
        }

        let corridor = SKShapeNode(rectOf: CGSize(width: 150, height: 116), cornerRadius: 0)
        corridor.position = CGPoint(x: 175, y: 0)
        corridor.fillColor = UIColor(red: 0.26, green: 0.25, blue: 0.27, alpha: 1)
        corridor.strokeColor = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)
        corridor.lineWidth = 4
        corridor.zPosition = -10
        dungeonNode.addChild(corridor)

        spawnDungeonExit()
        spawnDungeonChests()
        spawnDungeonEnemies()
        spawnBossDoor()
    }

    private func buildDinosaur() {
        dinoNode.position = overworldSpawn
        dinoNode.zPosition = 30

        let shadow = SKShapeNode(rectOf: CGSize(width: 86, height: 48), cornerRadius: 0)
        shadow.position = CGPoint(x: -4, y: -5)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.20)
        shadow.strokeColor = .clear
        shadow.zPosition = -1

        let tail = SKShapeNode(rectOf: CGSize(width: 42, height: 24), cornerRadius: 0)
        tail.position = CGPoint(x: -52, y: 0)
        tail.fillColor = UIColor(red: 0.12, green: 0.42, blue: 0.20, alpha: 1)
        tail.strokeColor = UIColor(red: 0.06, green: 0.24, blue: 0.11, alpha: 1)
        tail.lineWidth = 2

        let body = SKShapeNode(rectOf: CGSize(width: 70, height: 44), cornerRadius: 0)
        body.name = "dinoBody"
        body.fillColor = UIColor(red: 0.19, green: 0.62, blue: 0.29, alpha: 1)
        body.strokeColor = UIColor(red: 0.08, green: 0.28, blue: 0.12, alpha: 1)
        body.lineWidth = 3

        let head = SKShapeNode(rectOf: CGSize(width: 36, height: 34), cornerRadius: 0)
        head.name = "dinoHead"
        head.position = CGPoint(x: 46, y: 0)
        head.fillColor = UIColor(red: 0.16, green: 0.52, blue: 0.25, alpha: 1)
        head.strokeColor = UIColor(red: 0.08, green: 0.28, blue: 0.12, alpha: 1)
        head.lineWidth = 2

        let eye = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 0)
        eye.position = CGPoint(x: 56, y: 7)
        eye.fillColor = .white
        eye.strokeColor = .clear

        let pack = SKShapeNode(rectOf: CGSize(width: 22, height: 16), cornerRadius: 0)
        pack.position = CGPoint(x: -4, y: 20)
        pack.fillColor = UIColor(red: 0.38, green: 0.24, blue: 0.13, alpha: 1)
        pack.strokeColor = UIColor(red: 0.18, green: 0.10, blue: 0.04, alpha: 1)
        pack.lineWidth = 1.5

        dinoNode.addChild(shadow)
        dinoNode.addChild(tail)
        dinoNode.addChild(body)
        dinoNode.addChild(head)
        dinoNode.addChild(eye)
        dinoNode.addChild(pack)
        worldNode.addChild(dinoNode)
        cameraRig.position = dinoNode.position
    }

    private func buildHUD() {
        joystickBase.fillColor = UIColor.black.withAlphaComponent(0.22)
        joystickBase.strokeColor = UIColor.white.withAlphaComponent(0.42)
        joystickBase.lineWidth = 3
        joystickBase.zPosition = 1000

        joystickKnob.fillColor = UIColor.white.withAlphaComponent(0.64)
        joystickKnob.strokeColor = UIColor.white.withAlphaComponent(0.9)
        joystickKnob.lineWidth = 2
        joystickKnob.zPosition = 1001

        actionButton.fillColor = UIColor(red: 0.95, green: 0.56, blue: 0.18, alpha: 0.72)
        actionButton.strokeColor = UIColor.white.withAlphaComponent(0.75)
        actionButton.lineWidth = 3
        actionButton.zPosition = 1000

        actionLabel.text = "A"
        actionLabel.fontSize = 16
        actionLabel.fontColor = .white
        actionLabel.verticalAlignmentMode = .center
        actionLabel.horizontalAlignmentMode = .center
        actionButton.addChild(actionLabel)

        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 0, y: 22))
        arrowPath.addLine(to: CGPoint(x: 17, y: -14))
        arrowPath.addLine(to: CGPoint(x: 0, y: -7))
        arrowPath.addLine(to: CGPoint(x: -17, y: -14))
        arrowPath.closeSubpath()
        objectiveArrow.path = arrowPath
        objectiveArrow.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 0.94)
        objectiveArrow.strokeColor = UIColor.black.withAlphaComponent(0.4)
        objectiveArrow.lineWidth = 2
        objectiveArrow.zPosition = 1002
        objectiveNode.addChild(objectiveArrow)

        objectiveLabel.fontColor = .white
        objectiveLabel.position = CGPoint(x: 0, y: -31)
        objectiveLabel.horizontalAlignmentMode = .center
        objectiveLabel.verticalAlignmentMode = .center
        objectiveLabel.zPosition = 1002
        objectiveNode.addChild(objectiveLabel)

        objectiveDistanceLabel.fontColor = UIColor.white.withAlphaComponent(0.82)
        objectiveDistanceLabel.position = CGPoint(x: 0, y: -48)
        objectiveDistanceLabel.horizontalAlignmentMode = .center
        objectiveDistanceLabel.verticalAlignmentMode = .center
        objectiveDistanceLabel.zPosition = 1002
        objectiveNode.addChild(objectiveDistanceLabel)
        objectiveNode.zPosition = 1002
        objectiveNode.isHidden = true

        interactionHighlight.fillColor = .clear
        interactionHighlight.strokeColor = UIColor(red: 1.0, green: 0.84, blue: 0.24, alpha: 0.95)
        interactionHighlight.lineWidth = 3
        interactionHighlight.zPosition = 70
        interactionHighlight.isHidden = true
        interactionHighlight.run(.repeatForever(.sequence([
            .group([.scale(to: 1.08, duration: 0.45), .fadeAlpha(to: 0.45, duration: 0.45)]),
            .group([.scale(to: 1.0, duration: 0.45), .fadeAlpha(to: 1.0, duration: 0.45)])
        ])))

        for label in [hudLabel, questLabel, promptLabel] {
            label.horizontalAlignmentMode = label == promptLabel ? .center : .left
            label.verticalAlignmentMode = .center
            label.fontColor = .white
            label.zPosition = 1002
        }
        hudLabel.fontSize = 19
        questLabel.fontSize = 14
        promptLabel.fontSize = 18

        hudNode.addChild(joystickBase)
        hudNode.addChild(joystickKnob)
        hudNode.addChild(actionButton)
        hudNode.addChild(hudLabel)
        hudNode.addChild(questLabel)
        hudNode.addChild(promptLabel)
        hudNode.addChild(objectiveNode)
        worldNode.addChild(interactionHighlight)
    }

    private func spawnVillage() {
        let buildings: [(String, CGPoint, UIColor)] = [
            ("Blockshire Hall", CGPoint(x: -455, y: -255), UIColor(red: 0.52, green: 0.34, blue: 0.20, alpha: 1)),
            ("Class Yard", CGPoint(x: -270, y: -320), UIColor(red: 0.44, green: 0.31, blue: 0.22, alpha: 1)),
            ("Gear Stall", CGPoint(x: -470, y: -420), UIColor(red: 0.36, green: 0.33, blue: 0.27, alpha: 1))
        ]

        for building in buildings {
            let node = makeBlockBuilding(title: building.0, color: building.2)
            node.position = building.1
            overworldNode.addChild(node)
        }

        let elder = makeNPC(name: "Elder Mossbeak", color: UIColor(red: 0.30, green: 0.58, blue: 0.36, alpha: 1), badge: "!")
        elder.position = CGPoint(x: -368, y: -250)
        overworldNode.addChild(elder)
        npcs.append(NPC(id: "elder", name: "Elder Mossbeak", role: .elder, node: elder))

        let trainers: [(PlayerClass, CGPoint)] = [
            (.guardian, CGPoint(x: -488, y: -354)),
            (.emberclaw, CGPoint(x: -372, y: -408)),
            (.stonesinger, CGPoint(x: -258, y: -354))
        ]

        for trainer in trainers {
            let node = makeNPC(name: trainer.0.rawValue, color: classColor(for: trainer.0), badge: trainerBadge(for: trainer.0))
            node.position = trainer.1
            overworldNode.addChild(node)
            npcs.append(NPC(id: "trainer-\(trainer.0.rawValue)", name: "\(trainer.0.rawValue) Trainer", role: .trainer(trainer.0), node: node))
        }
    }

    private func spawnTrees() {
        let positions = [
            CGPoint(x: -470, y: -130), CGPoint(x: -390, y: 190), CGPoint(x: -130, y: -430),
            CGPoint(x: 180, y: -430), CGPoint(x: 370, y: -250), CGPoint(x: 410, y: 230),
            CGPoint(x: 90, y: 430), CGPoint(x: -430, y: 360), CGPoint(x: 10, y: 150)
        ]

        for position in positions {
            let trunk = SKShapeNode(rectOf: CGSize(width: 24, height: 42), cornerRadius: 0)
            trunk.position = position
            trunk.fillColor = UIColor(red: 0.37, green: 0.22, blue: 0.11, alpha: 1)
            trunk.strokeColor = UIColor(red: 0.18, green: 0.10, blue: 0.04, alpha: 1)
            trunk.lineWidth = 2
            trunk.zPosition = -4

            let leaves = SKShapeNode(rectOf: CGSize(width: 68, height: 58), cornerRadius: 0)
            leaves.position = CGPoint(x: position.x, y: position.y + 30)
            leaves.fillColor = UIColor(red: 0.08, green: 0.34, blue: 0.18, alpha: 1)
            leaves.strokeColor = UIColor(red: 0.03, green: 0.20, blue: 0.09, alpha: 1)
            leaves.lineWidth = 2
            leaves.zPosition = -3

            let top = SKShapeNode(rectOf: CGSize(width: 54, height: 10), cornerRadius: 0)
            top.position = CGPoint(x: 0, y: 18)
            top.fillColor = UIColor.white.withAlphaComponent(0.08)
            top.strokeColor = .clear
            leaves.addChild(top)

            overworldNode.addChild(trunk)
            overworldNode.addChild(leaves)
        }
    }

    private func spawnBrush() {
        let specs: [(CGPoint, Bool)] = [
            (CGPoint(x: -330, y: -250), false), (CGPoint(x: -210, y: -190), true),
            (CGPoint(x: 70, y: -120), false), (CGPoint(x: 190, y: 140), true),
            (CGPoint(x: 300, y: -20), false), (CGPoint(x: -60, y: 350), false),
            (CGPoint(x: 420, y: 320), true), (CGPoint(x: -430, y: 40), false)
        ]

        for (index, spec) in specs.enumerated() {
            let node = makeBrush()
            node.position = spec.0
            overworldNode.addChild(node)
            brushPatches.append(BrushPatch(id: "brush-\(index)", node: node, containsHeart: spec.1))
        }
    }

    private func spawnItems() {
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5
            let radius = CGFloat(220 + (index % 3) * 75)
            let node = makeCircle(radius: 14, color: UIColor(red: 1, green: 0.72, blue: 0.16, alpha: 1))
            node.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            overworldNode.addChild(node)
            items.append(Item(id: "amber-\(index)", kind: .amber, area: .overworld, node: node))
        }

        let relicPositions = [CGPoint(x: -280, y: 260), CGPoint(x: 360, y: -80), CGPoint(x: 430, y: 360)]
        for (index, position) in relicPositions.enumerated() {
            let node = makeDiamond(color: UIColor(red: 0.64, green: 0.25, blue: 1, alpha: 1))
            node.position = position
            overworldNode.addChild(node)
            items.append(Item(id: "relic-\(index)", kind: .relic, area: .overworld, node: node))
        }
    }

    private func spawnChests() {
        let specs: [(String, String, ChestReward, CGPoint)] = [
            ("village-cache", "Village Cache", .key, CGPoint(x: -330, y: -290)),
            ("grove-coffer", "Grove Coffer", .heartContainer, CGPoint(x: 260, y: -210)),
            ("ruin-gear", "Ruin Gear", .gear("Chunkstone Charm", gold: 12), CGPoint(x: -120, y: 330))
        ]

        for spec in specs {
            let node = makeChest(title: spec.1)
            node.position = spec.3
            overworldNode.addChild(node)
            chests.append(Chest(id: spec.0, title: spec.1, reward: spec.2, area: .overworld, node: node))
        }
    }

    private func spawnEnemies() {
        let specs: [(String, CGPoint, Int, Int, Bool)] = [
            ("bramble-1", CGPoint(x: 60, y: 30), 2, 1, true),
            ("bramble-2", CGPoint(x: 170, y: 110), 2, 1, true),
            ("bramble-3", CGPoint(x: 260, y: 35), 2, 1, true),
            ("bramble-4", CGPoint(x: 280, y: -320), 2, 2, false),
            ("bramble-5", CGPoint(x: 80, y: 260), 3, 2, false)
        ]

        for (index, spec) in specs.enumerated() {
            let node = makeEnemy(level: spec.3)
            addHealthPips(to: node, maxHealth: spec.2, yOffset: 34)
            node.position = spec.1
            overworldNode.addChild(node)
            enemies.append(Enemy(id: spec.0, kind: .thornling, area: .overworld, node: node, home: spec.1, phase: CGFloat(index) * 0.9, level: spec.3, isQuestTarget: spec.4, maxHealth: spec.2, health: spec.2))
        }
    }

    private func spawnLandmarks() {
        let specs: [(String, String, Bool, CGPoint)] = [
            ("blockshire", "Blockshire", false, CGPoint(x: -390, y: -300)),
            ("ruins", "Tailblock Ruins", false, CGPoint(x: -250, y: 300)),
            ("crystals", "Prism Grove", false, CGPoint(x: 330, y: -180)),
            ("ore", "Cube Ore Field", false, CGPoint(x: 320, y: 280)),
            ("shrine", "Sky Gate Shrine", true, CGPoint(x: 480, y: 430))
        ]

        for spec in specs {
            let node = makeLandmark(title: spec.1, shrine: spec.2)
            node.position = spec.3
            overworldNode.addChild(node)
            landmarks.append(Landmark(id: spec.0, title: spec.1, isShrine: spec.2, node: node))
        }
    }

    private func spawnCaveEntrance() {
        let entrance = makeCaveEntrance(title: "Tailblock Cave")
        entrance.position = caveEntrancePosition
        overworldNode.addChild(entrance)
        caveEntrance = entrance
    }

    private func spawnDungeonExit() {
        let exit = makeCaveEntrance(title: "Exit")
        exit.position = dungeonExitPosition
        exit.setScale(0.82)
        dungeonNode.addChild(exit)
        dungeonExit = exit
    }

    private func spawnDungeonChests() {
        let node = makeChest(title: "Cave Key")
        node.position = CGPoint(x: -40, y: 135)
        dungeonNode.addChild(node)
        chests.append(Chest(id: "dungeon-key-chest", title: "Cave Key Chest", reward: .dungeonKey, area: .dungeon, node: node))
    }

    private func spawnDungeonEnemies() {
        let specs: [(String, EnemyKind, CGPoint, Int, Int)] = [
            ("cave-bramble-1", .thornling, CGPoint(x: -125, y: -92), 2, 2),
            ("cave-bramble-2", .thornling, CGPoint(x: 40, y: -96), 2, 2),
            ("sky-wyrm", .boss, CGPoint(x: 390, y: 0), 8, 3)
        ]

        for (index, spec) in specs.enumerated() {
            let node = spec.1 == .boss ? makeBoss() : makeEnemy(level: spec.4)
            addHealthPips(to: node, maxHealth: spec.3, yOffset: spec.1 == .boss ? 62 : 34)
            node.position = spec.2
            dungeonNode.addChild(node)
            enemies.append(Enemy(id: spec.0, kind: spec.1, area: .dungeon, node: node, home: spec.2, phase: CGFloat(index) * 0.8, level: spec.4, isQuestTarget: false, maxHealth: spec.3, health: spec.3))
        }
    }

    private func spawnBossDoor() {
        let door = makeBossDoor()
        door.position = bossDoorPosition
        dungeonNode.addChild(door)
        bossDoor = door
    }

    private func spawnGate() {
        let gate = makeGate()
        gate.position = CGPoint(x: 420, y: 390)
        overworldNode.addChild(gate)
        lockedGate = gate
    }

    private func spawnMarkers() {
        let specs: [(String, String, CGPoint)] = [
            ("camp-stone", "Camp Stone", CGPoint(x: -310, y: -250)),
            ("ruin-stone", "Ruin Stone", CGPoint(x: -170, y: 300)),
            ("shrine-stone", "Shrine Stone", CGPoint(x: 425, y: 390))
        ]

        for spec in specs {
            let node = makeCircle(radius: 24, color: UIColor(red: 0.18, green: 0.88, blue: 0.78, alpha: 1))
            node.position = spec.2
            node.zPosition = 4
            overworldNode.addChild(node)
            questMarkers.append(QuestMarker(id: spec.0, title: spec.1, node: node))
        }
    }

    private func updateEnemies(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard deltaTime > 0 else { return }

        for index in enemies.indices {
            guard enemies[index].area == currentArea, enemies[index].health > 0, enemies[index].node.parent != nil else { continue }
            if enemies[index].kind == .boss && !bossDoorUnlocked {
                continue
            }
            let node = enemies[index].node
            let distanceToDino = node.position.distance(to: dinoNode.position)
            let target: CGPoint
            let speed: CGFloat

            if distanceToDino < 270 {
                target = dinoNode.position
                speed = enemies[index].kind == .boss ? 58 : 64
            } else {
                let angle = CGFloat(currentTime) * 0.8 + enemies[index].phase
                target = enemies[index].home + CGPoint(x: cos(angle) * 48, y: sin(angle * 0.8) * 34)
                speed = enemies[index].kind == .boss ? 24 : 30
            }

            let direction = (target - node.position).normalized
            if direction.length > 0.001 {
                node.position += direction * speed * CGFloat(deltaTime)
                node.zRotation = atan2(direction.y, direction.x)
            }
        }
    }

    private func checkWorldProgress() {
        for item in items where item.area == currentArea && item.node.parent != nil && dinoNode.position.distance(to: item.node.position) < pickupRadius {
            item.node.removeFromParent()
            switch item.kind {
            case .amber:
                progress.collectAmber()
            case .relic:
                progress.collectRelic(id: item.id)
            case .heart:
                progress.heal()
            case .skyRelic:
                progress.collectSkyRelic()
                showMessage(StoryCodex.skyRelicRecovered(), duration: 2.4)
            }
        }

        guard currentArea == .overworld else { return }

        for index in landmarks.indices where !landmarks[index].discovered && dinoNode.position.distance(to: landmarks[index].node.position) < 92 {
            if landmarks[index].isShrine && !progress.gateUnlocked {
                continue
            }

            landmarks[index].discovered = true
            progress.discoverLandmark(id: landmarks[index].id, isShrine: landmarks[index].isShrine)
            landmarks[index].node.alpha = 1
            if progress.questStep == .completed {
                showMessage(StoryCodex.shrineRestored(), duration: 2.4)
            }
        }
    }

    private func checkEnemyContact(currentTime: TimeInterval) {
        guard currentTime - lastPlayerDamageTime > 1.15 else { return }

        for enemy in enemies where enemy.area == currentArea && enemy.health > 0 && enemy.node.parent != nil && dinoNode.position.distance(to: enemy.node.position) < (enemy.kind == .boss ? 62 : 45) {
            progress.takeDamage()
            lastPlayerDamageTime = currentTime
            let knockback = (dinoNode.position - enemy.node.position).normalized * 42
            dinoNode.position += knockback
            dinoNode.run(.sequence([.fadeAlpha(to: 0.45, duration: 0.08), .fadeAlpha(to: 1, duration: 0.18)]))

            if progress.health == 0 {
                showMessage("Knocked out. Returning to camp.", duration: 2.0)
                respawnAtCamp()
            } else {
                showMessage("Ouch. Tap A to slash back.")
            }
            return
        }
    }

    private func performAction() {
        pulseActionButton()
        if tryInteractNPC() { return }
        if tryAreaTransition() { return }
        if tryOpenChest() { return }
        if tryUnlockBossDoor() { return }
        if tryUnlockGate() { return }
        if tryCommune() { return }
        attack()
    }

    private func tryInteractNPC() -> Bool {
        guard currentArea == .overworld, let npc = nearestNPC(), dinoNode.position.distance(to: npc.node.position) < npcInteractionRadius else { return false }

        switch npc.role {
        case .trainer(let playerClass):
            if progress.chooseClass(playerClass) {
                applyClassStyle()
                showMessage(StoryCodex.classChosen(playerClass), duration: 2.4)
            } else if progress.playerClass == playerClass {
                showMessage(StoryCodex.trainerReminder(name: npc.name), duration: 2.4)
            } else {
                showMessage("Already walking the \(progress.classTitle) rite.", duration: 1.8)
            }
        case .elder:
            let previousStep = progress.questStep
            if progress.talkToElder() {
                showMessage(StoryCodex.elderSuccess(for: progress.questStep, previousStep: previousStep), duration: 2.8)
            } else {
                showMessage(StoryCodex.elderHint(for: progress.questStep, campDefeats: progress.campEnemiesDefeated), duration: 2.4)
            }
        }

        return true
    }

    private func tryAreaTransition() -> Bool {
        switch currentArea {
        case .overworld:
            guard let caveEntrance, dinoNode.position.distance(to: caveEntrance.position) < caveInteractionRadius else { return false }
            guard progress.canEnterDungeon else {
                showMessage(StoryCodex.caveLocked(), duration: 2.2)
                return true
            }
            enterDungeon()
            return true
        case .dungeon:
            guard let dungeonExit, dinoNode.position.distance(to: dungeonExit.position) < caveInteractionRadius else { return false }
            exitDungeon()
            return true
        }
    }

    private func enterDungeon() {
        currentArea = .dungeon
        overworldNode.isHidden = true
        dungeonNode.isHidden = false
        dinoNode.position = dungeonSpawn
        cameraRig.position = dinoNode.position
        resetInput()
        showMessage(StoryCodex.enterCave(), duration: 2.2)
    }

    private func exitDungeon() {
        currentArea = .overworld
        dungeonNode.isHidden = true
        overworldNode.isHidden = false
        dinoNode.position = caveEntrancePosition + CGPoint(x: 0, y: -86)
        cameraRig.position = dinoNode.position
        resetInput()
        showMessage(StoryCodex.exitCave(hasRelic: progress.skyRelicClaimed))
    }

    private func resetInput() {
        joystickTouch = nil
        actionTouch = nil
        joystickVector = .zero
        keyboardVector = .zero
        pressedKeys.removeAll()
        joystickKnob.position = joystickBase.position
        actionButton.alpha = 0.72
    }

    private func tryOpenChest() -> Bool {
        guard let index = nearestClosedChestIndex() else { return false }
        guard dinoNode.position.distance(to: chests[index].node.position) < chestInteractionRadius else { return false }

        chests[index].opened = true
        chests[index].node.alpha = 0.55
        chests[index].node.run(.sequence([.scale(to: 1.12, duration: 0.08), .scale(to: 1.0, duration: 0.14)]))

        guard progress.openChest(id: chests[index].id) else { return true }
        switch chests[index].reward {
        case .key:
            progress.collectKey()
            showMessage("Found a Sky Gate key.")
        case .dungeonKey:
            progress.collectDungeonKey()
            showMessage("Found the Cave Key.")
        case .amber(let amount):
            progress.collectAmber(amount: amount)
            showMessage("Found \(amount) amber.")
        case .gear(let id, let gold):
            if progress.grantGear(id: id, goldReward: gold, xpReward: 35) {
                showMessage("Equipped \(id). +\(gold) gold.")
            } else {
                showMessage("Found spare gear.")
            }
        case .heartContainer:
            progress.increaseMaxHealth()
            showMessage("Heart capacity increased.")
        }
        return true
    }

    private func tryUnlockGate() -> Bool {
        guard currentArea == .overworld else { return false }
        guard let gate = lockedGate, gate.parent != nil else { return false }
        guard dinoNode.position.distance(to: gate.position) < gateInteractionRadius else { return false }

        if progress.unlockGate() {
            gate.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
            showMessage(StoryCodex.skyGateOpened(), duration: 2.2)
        } else {
            showMessage("The Sky Gate needs the clan cache key.")
        }
        return true
    }

    private func tryUnlockBossDoor() -> Bool {
        guard currentArea == .dungeon, !bossDoorUnlocked, let bossDoor, bossDoor.parent != nil else { return false }
        guard dinoNode.position.distance(to: bossDoor.position) < gateInteractionRadius else { return false }

        if progress.useDungeonKey() {
            bossDoorUnlocked = true
            bossDoor.run(.sequence([.fadeOut(withDuration: 0.28), .removeFromParent()]))
            showMessage("Boss Door unlocked. Face the Sky Wyrm.", duration: 1.8)
        } else {
            showMessage("The Boss Door needs the Cave Key.")
        }
        return true
    }

    private func tryCommune() -> Bool {
        guard currentArea == .overworld else { return false }
        guard let index = questMarkers.indices.min(by: {
            dinoNode.position.distance(to: questMarkers[$0].node.position) < dinoNode.position.distance(to: questMarkers[$1].node.position)
        }) else { return false }

        guard !questMarkers[index].used, dinoNode.position.distance(to: questMarkers[index].node.position) < markerInteractionRadius else { return false }
        questMarkers[index].used = true
        questMarkers[index].node.alpha = 0.35
        progress.commune(marker: questMarkers[index].id)
        showMessage(StoryCodex.markerCommuned(title: questMarkers[index].title))
        return true
    }

    private func attack() {
        guard lastUpdateTime - lastAttackTime > progress.attackCooldown else { return }
        lastAttackTime = lastUpdateTime

        let forward = CGPoint(x: facingVector.dx, y: facingVector.dy).normalized
        let attackCenter = dinoNode.position + forward * CGFloat(66 + progress.attackRangeBonus / 2)
        showSlash(at: attackCenter, facing: forward)

        let hitEnemy = damageEnemies(facing: forward)
        let cutBrush = cutBrushes(near: attackCenter)
        if !hitEnemy && !cutBrush {
            showMessage("Slash.")
        }
    }

    private func damageEnemies(facing forward: CGPoint) -> Bool {
        var hitEnemy = false

        for index in enemies.indices {
            guard enemies[index].area == currentArea, enemies[index].health > 0, enemies[index].node.parent != nil else { continue }
            let offset = enemies[index].node.position - dinoNode.position
            let facingDot = forward.x * offset.normalized.x + forward.y * offset.normalized.y
            let attackReach = CGFloat(enemies[index].kind == .boss ? 132 : 112) + CGFloat(progress.attackRangeBonus)
            guard offset.length < attackReach, facingDot > 0.05 else { continue }

            hitEnemy = true
            enemies[index].health -= progress.attackDamage
            updateHealthPips(on: enemies[index].node, health: enemies[index].health)
            let knockback = offset.normalized * 32
            enemies[index].node.position += knockback
            enemies[index].node.run(.sequence([.scale(to: 1.22, duration: 0.06), .scale(to: 1.0, duration: 0.12)]))

            if enemies[index].health <= 0 {
                let defeatedPosition = enemies[index].node.position
                let defeatedID = enemies[index].id
                let defeatedKind = enemies[index].kind
                enemies[index].node.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))

                if defeatedKind == .boss {
                    progress.defeatBoss()
                    dropSkyRelic(at: defeatedPosition)
                    progress.grantGear(id: "Sky Wyrm Scale", xpReward: 0)
                    showMessage(StoryCodex.bossDefeated(), duration: 2.2)
                } else if progress.defeatEnemy(id: defeatedID, isQuestTarget: enemies[index].isQuestTarget) {
                    progress.collectAmber()
                    progress.collectGold(amount: enemies[index].level + 1)
                    if progress.enemiesDefeated % 2 == 0 {
                        dropHeart(at: defeatedPosition)
                    }
                    if progress.questStep == .returnToElder {
                        showMessage("Bramble Camp cleared. The migration song can pass.", duration: 2.2)
                    } else {
                        showMessage("Brambleling defeated.")
                    }
                }
            }
        }

        return hitEnemy
    }

    private func cutBrushes(near center: CGPoint) -> Bool {
        guard currentArea == .overworld else { return false }
        var didCut = false

        for index in brushPatches.indices {
            guard !brushPatches[index].cut, brushPatches[index].node.parent != nil else { continue }
            guard brushPatches[index].node.position.distance(to: center) < 72 else { continue }

            didCut = true
            brushPatches[index].cut = true
            let position = brushPatches[index].node.position
            brushPatches[index].node.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))

            if brushPatches[index].containsHeart {
                dropHeart(at: position)
                showMessage("Found a heart in the brush.")
            }
        }

        return didCut
    }

    private func dropHeart(at position: CGPoint) {
        let node = makeCircle(radius: 13, color: UIColor(red: 0.95, green: 0.16, blue: 0.24, alpha: 1))
        node.position = position
        rootNodeForCurrentArea.addChild(node)
        items.append(Item(id: "heart-\(items.count)", kind: .heart, area: currentArea, node: node))
    }

    private func dropSkyRelic(at position: CGPoint) {
        guard !progress.skyRelicClaimed, !items.contains(where: { $0.kind == .skyRelic && $0.node.parent != nil }) else { return }
        let node = makeSkyRelic()
        node.position = position
        dungeonNode.addChild(node)
        items.append(Item(id: "sky-relic", kind: .skyRelic, area: .dungeon, node: node))
    }

    private func respawnAtCamp() {
        currentArea = .overworld
        dungeonNode.isHidden = true
        overworldNode.isHidden = false
        progress.heal(progress.maxHealth)
        dinoNode.position = overworldSpawn
        cameraRig.position = dinoNode.position
    }

    private func updateHUD() {
        let compact = usesCompactHUD
        let affordance = currentActionAffordance(compact: compact)
        if compact {
            let keyCount = currentArea == .dungeon ? progress.dungeonKeys : progress.keys
            let area = currentArea == .dungeon ? "Cave" : "Dino"
            hudLabel.text = "\(area) Lv \(progress.level) \(shortClassTitle()) HP \(progress.health)/\(progress.maxHealth) K\(keyCount) G\(progress.gold) XP\(progress.xp)"
        } else if currentArea == .dungeon {
            hudLabel.text = "Tailblock Cave  Lv \(progress.level) \(progress.classTitle)  HP \(progress.health)/\(progress.maxHealth)  Key \(progress.dungeonKeys)  Gold \(progress.gold)  XP \(progress.xp)"
        } else {
            hudLabel.text = "Dino Blocklands  Lv \(progress.level) \(progress.classTitle)  HP \(progress.health)/\(progress.maxHealth)  Keys \(progress.keys)  Gold \(progress.gold)  Amber \(progress.amber)  XP \(progress.xp)"
        }

        if progress.isComplete {
            questLabel.text = StoryCodex.questText(for: .completed, campDefeats: progress.campEnemiesDefeated, isDungeon: currentArea == .dungeon, compact: compact)
        } else {
            questLabel.text = questText(compact: compact)
        }

        if let message = eventMessage, Date() < eventMessageUntil {
            promptLabel.text = message
        } else if let prompt = affordance.promptText {
            promptLabel.text = prompt
        } else if progress.isComplete {
            promptLabel.text = "MVP complete"
        } else {
            promptLabel.text = ""
        }

        actionLabel.text = affordance.buttonTitle
        updateActionButtonAppearance(for: affordance.kind)
        updateInteractionHighlight(target: affordance.highlightNode)
        updateObjectiveHUD()
    }

    private func currentActionAffordance(compact: Bool) -> ActionAffordance {
        if currentArea == .overworld, let npc = nearestNPC(), dinoNode.position.distance(to: npc.node.position) < npcInteractionRadius {
            switch npc.role {
            case .trainer(let playerClass) where progress.playerClass == nil:
                return ActionAffordance(
                    kind: .train,
                    buttonTitle: "Train",
                    promptText: compact ? "Train: \(playerClass.rawValue)" : "Tap Train to choose the \(playerClass.rawValue) rite",
                    highlightNode: npc.node
                )
            default:
                return ActionAffordance(
                    kind: .talk,
                    buttonTitle: "Talk",
                    promptText: compact ? "Talk: \(shortNPCName(npc))" : "Tap Talk to speak with \(npc.name)",
                    highlightNode: npc.node
                )
            }
        }

        if currentArea == .overworld, let caveEntrance, dinoNode.position.distance(to: caveEntrance.position) < caveInteractionRadius {
            if progress.canEnterDungeon {
                return ActionAffordance(
                    kind: .enter,
                    buttonTitle: "Enter",
                    promptText: compact ? "Enter: Cave" : "Tap Enter to enter Tailblock Cave",
                    highlightNode: caveEntrance
                )
            }
            return ActionAffordance(
                kind: .locked,
                buttonTitle: "Ask",
                promptText: compact ? "Ask Elder first" : "Hear Elder Mossbeak's warning first",
                highlightNode: caveEntrance
            )
        }

        if currentArea == .dungeon, let dungeonExit, dinoNode.position.distance(to: dungeonExit.position) < caveInteractionRadius {
            return ActionAffordance(
                kind: .exit,
                buttonTitle: "Exit",
                promptText: compact ? "Exit cave" : "Tap Exit to return to the Blocklands",
                highlightNode: dungeonExit
            )
        }

        if let chest = nearestClosedChest(), dinoNode.position.distance(to: chest.node.position) < chestInteractionRadius {
            return ActionAffordance(
                kind: .open,
                buttonTitle: "Open",
                promptText: compact ? "Open: \(chest.title)" : "Tap Open to open \(chest.title)",
                highlightNode: chest.node
            )
        }

        if currentArea == .dungeon, let bossDoor, !bossDoorUnlocked, bossDoor.parent != nil, dinoNode.position.distance(to: bossDoor.position) < gateInteractionRadius {
            if progress.dungeonKeys > 0 {
                return ActionAffordance(
                    kind: .unlock,
                    buttonTitle: "Unlock",
                    promptText: compact ? "Unlock: Boss Door" : "Tap Unlock to open the Boss Door",
                    highlightNode: bossDoor
                )
            }
            return ActionAffordance(
                kind: .locked,
                buttonTitle: "Key?",
                promptText: "Find the Cave Key",
                highlightNode: bossDoor
            )
        }

        if let gate = lockedGate, gate.parent != nil, dinoNode.position.distance(to: gate.position) < gateInteractionRadius {
            if progress.keys > 0 {
                return ActionAffordance(
                    kind: .unlock,
                    buttonTitle: "Unlock",
                    promptText: compact ? "Unlock: Sky Gate" : "Tap Unlock to open the Sky Gate",
                    highlightNode: gate
                )
            }
            return ActionAffordance(
                kind: .locked,
                buttonTitle: "Key?",
                promptText: compact ? "Find clan key" : "Find the clan cache key for the Sky Gate",
                highlightNode: gate
            )
        }

        if currentArea == .overworld, let marker = nearestUsableMarker(), dinoNode.position.distance(to: marker.node.position) < markerInteractionRadius {
            return ActionAffordance(
                kind: .commune,
                buttonTitle: "Commune",
                promptText: compact ? "Commune: \(marker.title)" : "Tap Commune at \(marker.title)",
                highlightNode: marker.node
            )
        }

        if nearestEnemyDistance() < 140 {
            return ActionAffordance(
                kind: .attack,
                buttonTitle: "Attack",
                promptText: compact ? "Attack" : "Tap Attack to use \(progress.classTitle) slash",
                highlightNode: nil
            )
        }

        return ActionAffordance(kind: .none, buttonTitle: "A", promptText: nil, highlightNode: nil)
    }

    private func updateActionButtonAppearance(for kind: ActionKind) {
        let attackReady = kind != .attack || lastUpdateTime - lastAttackTime >= progress.attackCooldown
        let alpha: CGFloat = actionTouch != nil ? 0.96 : (attackReady ? 0.78 : 0.42)
        actionButton.alpha = alpha
        actionButton.fillColor = actionColor(for: kind).withAlphaComponent(attackReady ? 0.84 : 0.48)
        actionButton.strokeColor = UIColor.white.withAlphaComponent(kind == .none ? 0.48 : 0.86)
        actionLabel.alpha = attackReady ? 1.0 : 0.62
    }

    private func actionColor(for kind: ActionKind) -> UIColor {
        switch kind {
        case .none:
            return UIColor(red: 0.95, green: 0.56, blue: 0.18, alpha: 1)
        case .talk:
            return UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1)
        case .train:
            return UIColor(red: 0.82, green: 0.42, blue: 0.92, alpha: 1)
        case .open:
            return UIColor(red: 0.94, green: 0.62, blue: 0.16, alpha: 1)
        case .enter, .exit:
            return UIColor(red: 0.28, green: 0.70, blue: 0.92, alpha: 1)
        case .unlock:
            return UIColor(red: 0.56, green: 0.42, blue: 0.92, alpha: 1)
        case .locked:
            return UIColor(red: 0.42, green: 0.42, blue: 0.45, alpha: 1)
        case .commune:
            return UIColor(red: 0.18, green: 0.78, blue: 0.72, alpha: 1)
        case .attack:
            return progress.playerClass.map(classColor(for:)) ?? UIColor(red: 0.88, green: 0.30, blue: 0.16, alpha: 1)
        }
    }

    private func updateInteractionHighlight(target: SKNode?) {
        guard let target, target.parent != nil else {
            interactionHighlight.isHidden = true
            return
        }

        interactionHighlight.isHidden = false
        interactionHighlight.position = target.position
    }

    private func updateObjectiveHUD() {
        guard let objective = currentSceneObjective(), !progress.isComplete else {
            objectiveNode.isHidden = true
            return
        }

        let offset = objective.target - dinoNode.position
        let distance = offset.length
        guard distance > 86 else {
            objectiveNode.isHidden = true
            return
        }

        let direction = offset.normalized
        let compact = usesCompactHUD
        let maxX = size.width / 2 - (compact ? 58 : 70)
        let maxY = size.height / 2 - (compact ? 170 : 132)
        let minY = -size.height / 2 + (compact ? 224 : 214)
        let xScale = direction.x == 0 ? CGFloat.greatestFiniteMagnitude : (direction.x > 0 ? maxX / direction.x : -maxX / direction.x)
        let yScale = direction.y == 0 ? CGFloat.greatestFiniteMagnitude : (direction.y > 0 ? maxY / direction.y : minY / direction.y)
        let edgeScale = max(0, min(xScale, yScale))

        objectiveNode.isHidden = false
        objectiveNode.position = CGPoint(x: direction.x * edgeScale, y: direction.y * edgeScale)
        objectiveArrow.zRotation = atan2(direction.y, direction.x) - .pi / 2
        objectiveLabel.text = objective.title

        let blockDistance = max(1, Int((distance / 58).rounded()))
        objectiveDistanceLabel.text = distance < 120 ? "Nearby" : "\(blockDistance) blocks"
    }

    private func currentSceneObjective() -> SceneObjective? {
        let playObjective = progress.playObjective(
            isInDungeon: currentArea == .dungeon,
            bossDoorUnlocked: bossDoorUnlocked,
            skyRelicVisible: skyRelicItemPosition() != nil
        )

        switch playObjective {
        case .chooseClass:
            return SceneObjective(title: "Choose rite", target: CGPoint(x: -372, y: -372))
        case .talkToElder:
            return SceneObjective(title: "Elder", target: npcPosition(id: "elder") ?? CGPoint(x: -368, y: -250))
        case .clearCamp:
            return SceneObjective(title: "Bramble Camp", target: firstAliveQuestEnemyPosition() ?? CGPoint(x: 170, y: 80))
        case .returnToElder:
            return SceneObjective(title: "Return Elder", target: npcPosition(id: "elder") ?? CGPoint(x: -368, y: -250))
        case .enterCave:
            return SceneObjective(title: "Tailblock Cave", target: caveEntrancePosition)
        case .findCaveKey:
            if currentArea == .dungeon {
                return SceneObjective(title: "Cave Key", target: dungeonKeyChestPosition() ?? CGPoint(x: -40, y: 135))
            }
            return SceneObjective(title: "Tailblock Cave", target: caveEntrancePosition)
        case .unlockBossDoor:
            if currentArea == .dungeon {
                return SceneObjective(title: "Boss Door", target: bossDoor?.position ?? bossDoorPosition)
            }
            return SceneObjective(title: "Tailblock Cave", target: caveEntrancePosition)
        case .defeatSkyWyrm:
            if currentArea == .dungeon {
                return SceneObjective(title: "Sky Wyrm", target: bossEnemyPosition() ?? CGPoint(x: 390, y: 0))
            }
            return SceneObjective(title: "Tailblock Cave", target: caveEntrancePosition)
        case .collectSkyRelic:
            if currentArea == .dungeon {
                return SceneObjective(title: "Sky Relic", target: skyRelicItemPosition() ?? bossEnemyPosition() ?? CGPoint(x: 390, y: 0))
            }
            return SceneObjective(title: "Tailblock Cave", target: caveEntrancePosition)
        case .unlockSkyGate:
            if currentArea == .dungeon {
                return SceneObjective(title: "Exit Cave", target: dungeonExit?.position ?? dungeonExitPosition)
            }
            return SceneObjective(title: "Sky Gate", target: lockedGate?.position ?? CGPoint(x: 420, y: 390))
        case .restoreShrine:
            return SceneObjective(title: "Shrine", target: CGPoint(x: 480, y: 430))
        case .completed:
            return nil
        }
    }

    private func npcPosition(id: String) -> CGPoint? {
        npcs.first { $0.id == id && $0.node.parent != nil }?.node.position
    }

    private func firstAliveQuestEnemyPosition() -> CGPoint? {
        enemies
            .filter { $0.area == .overworld && $0.isQuestTarget && $0.health > 0 && $0.node.parent != nil }
            .min { dinoNode.position.distance(to: $0.node.position) < dinoNode.position.distance(to: $1.node.position) }?
            .node.position
    }

    private func bossEnemyPosition() -> CGPoint? {
        enemies.first { $0.kind == .boss && $0.health > 0 && $0.node.parent != nil }?.node.position
    }

    private func skyRelicItemPosition() -> CGPoint? {
        items.first { $0.kind == .skyRelic && $0.node.parent != nil }?.node.position
    }

    private func dungeonKeyChestPosition() -> CGPoint? {
        chests.first { $0.id == "dungeon-key-chest" && !$0.opened && $0.node.parent != nil }?.node.position
    }

    private func questText(compact: Bool = false) -> String {
        StoryCodex.questText(for: progress.questStep, campDefeats: progress.campEnemiesDefeated, isDungeon: currentArea == .dungeon, compact: compact)
    }

    private func shortClassTitle() -> String {
        guard let playerClass = progress.playerClass else { return "NoRite" }
        switch playerClass {
        case .guardian:
            return "Guard"
        case .emberclaw:
            return "Ember"
        case .stonesinger:
            return "Stone"
        }
    }

    private func shortNPCName(_ npc: NPC) -> String {
        switch npc.role {
        case .elder:
            return "Elder"
        case .trainer(let playerClass):
            return "\(playerClass.rawValue)"
        }
    }

    private func showMessage(_ text: String, duration: TimeInterval = 1.5) {
        eventMessage = text
        eventMessageUntil = Date().addingTimeInterval(duration)
        promptLabel.text = text
    }

    private func nearestClosedChestIndex() -> Int? {
        chests.indices
            .filter { chests[$0].area == currentArea && !chests[$0].opened }
            .min { dinoNode.position.distance(to: chests[$0].node.position) < dinoNode.position.distance(to: chests[$1].node.position) }
    }

    private func nearestClosedChest() -> Chest? {
        guard let index = nearestClosedChestIndex() else { return nil }
        return chests[index]
    }

    private func nearestUsableMarker() -> QuestMarker? {
        questMarkers
            .filter { !$0.used }
            .min { dinoNode.position.distance(to: $0.node.position) < dinoNode.position.distance(to: $1.node.position) }
    }

    private func nearestNPC() -> NPC? {
        npcs
            .filter { $0.node.parent != nil }
            .min { dinoNode.position.distance(to: $0.node.position) < dinoNode.position.distance(to: $1.node.position) }
    }

    private func nearestEnemyDistance() -> CGFloat {
        enemies
            .filter { $0.area == currentArea && $0.health > 0 && $0.node.parent != nil }
            .map { dinoNode.position.distance(to: $0.node.position) }
            .min() ?? .greatestFiniteMagnitude
    }

    private func keepDinoInCurrentArea() {
        switch currentArea {
        case .overworld:
            let maxRadius: CGFloat = 560
            guard dinoNode.position.length > maxRadius else { return }
            dinoNode.position = dinoNode.position.normalized * maxRadius
        case .dungeon:
            var position = dinoNode.position
            position.x = min(max(position.x, dungeonBounds.minX + 38), dungeonBounds.maxX - 38)
            position.y = min(max(position.y, dungeonBounds.minY + 38), dungeonBounds.maxY - 38)

            if !bossDoorUnlocked && position.x > bossDoorPosition.x - 50 {
                position.x = bossDoorPosition.x - 50
            }
            dinoNode.position = position
        }
    }

    private func pulseActionButton() {
        actionButton.run(.sequence([.scale(to: 1.08, duration: 0.05), .scale(to: 1.0, duration: 0.12)]))
    }

    private func applyClassStyle() {
        guard let playerClass = progress.playerClass else { return }
        let color = classColor(for: playerClass)

        if let body = dinoNode.childNode(withName: "dinoBody") as? SKShapeNode {
            body.fillColor = color
        }
        if let head = dinoNode.childNode(withName: "dinoHead") as? SKShapeNode {
            head.fillColor = color.withAlphaComponent(0.88)
        }

        dinoNode.childNode(withName: "classBadge")?.removeFromParent()
        let badge = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 0)
        badge.name = "classBadge"
        badge.position = CGPoint(x: 18, y: 26)
        badge.fillColor = UIColor.white.withAlphaComponent(0.88)
        badge.strokeColor = UIColor.black.withAlphaComponent(0.35)
        badge.lineWidth = 1

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = trainerBadge(for: playerClass)
        label.fontSize = 12
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        badge.addChild(label)
        dinoNode.addChild(badge)
    }

    private func showSlash(at position: CGPoint, facing forward: CGPoint) {
        let slash = SKShapeNode(ellipseOf: CGSize(width: 96, height: 38))
        slash.position = position
        slash.zRotation = atan2(forward.y, forward.x)
        let color = progress.playerClass.map(classColor(for:)) ?? .white
        slash.fillColor = color.withAlphaComponent(0.26)
        slash.strokeColor = color.withAlphaComponent(0.88)
        slash.lineWidth = 3
        slash.zPosition = 45
        worldNode.addChild(slash)
        slash.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
    }

    private func classColor(for playerClass: PlayerClass) -> UIColor {
        switch playerClass {
        case .guardian:
            return UIColor(red: 0.30, green: 0.55, blue: 0.95, alpha: 1)
        case .emberclaw:
            return UIColor(red: 0.95, green: 0.32, blue: 0.16, alpha: 1)
        case .stonesinger:
            return UIColor(red: 0.56, green: 0.42, blue: 0.92, alpha: 1)
        }
    }

    private func trainerBadge(for playerClass: PlayerClass) -> String {
        switch playerClass {
        case .guardian:
            return "G"
        case .emberclaw:
            return "E"
        case .stonesinger:
            return "S"
        }
    }

    private func makeBlockBuilding(title: String, color: UIColor) -> SKNode {
        let node = SKNode()
        node.zPosition = 1

        let shadow = SKShapeNode(rectOf: CGSize(width: 118, height: 82), cornerRadius: 0)
        shadow.position = CGPoint(x: 6, y: -7)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        shadow.strokeColor = .clear
        node.addChild(shadow)

        let base = SKShapeNode(rectOf: CGSize(width: 112, height: 76), cornerRadius: 0)
        base.fillColor = color
        base.strokeColor = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        base.lineWidth = 3
        node.addChild(base)

        let roof = SKShapeNode(rectOf: CGSize(width: 124, height: 26), cornerRadius: 0)
        roof.position = CGPoint(x: 0, y: 42)
        roof.fillColor = UIColor(red: 0.62, green: 0.18, blue: 0.14, alpha: 1)
        roof.strokeColor = UIColor(red: 0.22, green: 0.06, blue: 0.04, alpha: 1)
        roof.lineWidth = 2
        node.addChild(roof)

        let door = SKShapeNode(rectOf: CGSize(width: 22, height: 34), cornerRadius: 0)
        door.position = CGPoint(x: -24, y: -20)
        door.fillColor = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1)
        door.strokeColor = .clear
        node.addChild(door)

        let window = SKShapeNode(rectOf: CGSize(width: 22, height: 18), cornerRadius: 0)
        window.position = CGPoint(x: 26, y: -4)
        window.fillColor = UIColor(red: 0.94, green: 0.78, blue: 0.34, alpha: 1)
        window.strokeColor = UIColor.black.withAlphaComponent(0.25)
        window.lineWidth = 1
        node.addChild(window)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 10
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -57)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func makeNPC(name: String, color: UIColor, badge: String) -> SKNode {
        let node = SKNode()
        node.zPosition = 22

        let shadow = SKShapeNode(rectOf: CGSize(width: 38, height: 20), cornerRadius: 0)
        shadow.position = CGPoint(x: 2, y: -17)
        shadow.fillColor = UIColor.black.withAlphaComponent(0.20)
        shadow.strokeColor = .clear
        node.addChild(shadow)

        let body = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 0)
        body.fillColor = color
        body.strokeColor = UIColor.black.withAlphaComponent(0.35)
        body.lineWidth = 2
        node.addChild(body)

        let head = SKShapeNode(rectOf: CGSize(width: 24, height: 22), cornerRadius: 0)
        head.position = CGPoint(x: 0, y: 28)
        head.fillColor = color.withAlphaComponent(0.88)
        head.strokeColor = UIColor.black.withAlphaComponent(0.30)
        head.lineWidth = 1.5
        node.addChild(head)

        let badgeNode = SKShapeNode(rectOf: CGSize(width: 18, height: 18), cornerRadius: 0)
        badgeNode.position = CGPoint(x: 22, y: 36)
        badgeNode.fillColor = UIColor.white.withAlphaComponent(0.95)
        badgeNode.strokeColor = UIColor.black.withAlphaComponent(0.25)
        badgeNode.lineWidth = 1

        let badgeLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        badgeLabel.text = badge
        badgeLabel.fontSize = 12
        badgeLabel.fontColor = color
        badgeLabel.verticalAlignmentMode = .center
        badgeLabel.horizontalAlignmentMode = .center
        badgeNode.addChild(badgeLabel)
        node.addChild(badgeNode)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = name
        label.fontSize = 10
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -43)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func makeDungeonTile(color: UIColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: 62, height: 62), cornerRadius: 0)
        node.fillColor = color
        node.strokeColor = UIColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1)
        node.lineWidth = 1.2
        node.zPosition = -20

        let topEdge = SKShapeNode(rectOf: CGSize(width: 52, height: 5), cornerRadius: 0)
        topEdge.position = CGPoint(x: 0, y: 25)
        topEdge.fillColor = UIColor.white.withAlphaComponent(0.06)
        topEdge.strokeColor = .clear
        node.addChild(topEdge)
        return node
    }

    private func makeCaveEntrance(title: String) -> SKNode {
        let node = SKNode()
        node.zPosition = 8

        let back = SKShapeNode(rectOf: CGSize(width: 92, height: 76), cornerRadius: 0)
        back.fillColor = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)
        back.strokeColor = UIColor(red: 0.46, green: 0.42, blue: 0.35, alpha: 1)
        back.lineWidth = 5
        node.addChild(back)

        let opening = SKShapeNode(rectOf: CGSize(width: 48, height: 52), cornerRadius: 0)
        opening.position = CGPoint(x: 0, y: -10)
        opening.fillColor = UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)
        opening.strokeColor = UIColor.black.withAlphaComponent(0.35)
        opening.lineWidth = 2
        node.addChild(opening)

        for x in [-36, 36] {
            let block = SKShapeNode(rectOf: CGSize(width: 18, height: 88), cornerRadius: 0)
            block.position = CGPoint(x: x, y: 0)
            block.fillColor = UIColor(red: 0.35, green: 0.34, blue: 0.32, alpha: 1)
            block.strokeColor = UIColor.black.withAlphaComponent(0.20)
            block.lineWidth = 1
            node.addChild(block)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 11
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -50)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func makeBossDoor() -> SKNode {
        let node = SKNode()
        node.zPosition = 18

        let slab = SKShapeNode(rectOf: CGSize(width: 74, height: 96), cornerRadius: 0)
        slab.fillColor = UIColor(red: 0.24, green: 0.24, blue: 0.27, alpha: 1)
        slab.strokeColor = UIColor(red: 0.58, green: 0.52, blue: 0.42, alpha: 1)
        slab.lineWidth = 4
        node.addChild(slab)

        for x in [-22, 0, 22] {
            let bar = SKShapeNode(rectOf: CGSize(width: 8, height: 86), cornerRadius: 0)
            bar.position = CGPoint(x: x, y: 0)
            bar.fillColor = UIColor(red: 0.70, green: 0.63, blue: 0.48, alpha: 1)
            bar.strokeColor = .clear
            node.addChild(bar)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Boss Door"
        label.fontSize = 11
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -62)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func makeBoss() -> SKNode {
        let node = SKNode()
        node.zPosition = 28

        let body = SKShapeNode(rectOf: CGSize(width: 92, height: 72), cornerRadius: 0)
        body.fillColor = UIColor(red: 0.50, green: 0.08, blue: 0.12, alpha: 1)
        body.strokeColor = UIColor(red: 0.18, green: 0.02, blue: 0.04, alpha: 1)
        body.lineWidth = 5
        node.addChild(body)

        let eye = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 0)
        eye.position = CGPoint(x: 28, y: 12)
        eye.fillColor = UIColor(red: 1, green: 0.88, blue: 0.32, alpha: 1)
        eye.strokeColor = .clear
        node.addChild(eye)

        let crown = SKShapeNode(rectOf: CGSize(width: 78, height: 18), cornerRadius: 0)
        crown.position = CGPoint(x: 0, y: 45)
        crown.fillColor = UIColor(red: 0.94, green: 0.60, blue: 0.16, alpha: 1)
        crown.strokeColor = .clear
        node.addChild(crown)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Sky Wyrm"
        label.fontSize = 12
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -58)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    private func makeSkyRelic() -> SKNode {
        let node = makeDiamond(color: UIColor(red: 0.28, green: 0.88, blue: 1, alpha: 1))
        node.setScale(1.2)
        node.run(.repeatForever(.sequence([.scale(to: 1.35, duration: 0.55), .scale(to: 1.2, duration: 0.55)])))
        return node
    }

    private func makeCircle(radius: CGFloat, color: UIColor) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: radius * 2, height: radius * 2), cornerRadius: 0)
        node.fillColor = color
        node.strokeColor = .white.withAlphaComponent(0.35)
        node.lineWidth = 2
        node.zPosition = 5
        return node
    }

    private func makeDiamond(color: UIColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 28))
        path.addLine(to: CGPoint(x: 24, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -28))
        path.addLine(to: CGPoint(x: -24, y: 0))
        path.closeSubpath()
        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .white.withAlphaComponent(0.45)
        node.lineWidth = 2
        node.zPosition = 6
        return node
    }

    private func makeLandmark(title: String, shrine: Bool) -> SKNode {
        let node = SKNode()
        node.alpha = shrine ? 0.78 : 0.72
        node.zPosition = 2

        let base = SKShapeNode(rectOf: shrine ? CGSize(width: 78, height: 44) : CGSize(width: 58, height: 36), cornerRadius: 0)
        base.fillColor = shrine ? UIColor(red: 0.36, green: 0.72, blue: 1, alpha: 1) : UIColor(red: 0.55, green: 0.55, blue: 0.50, alpha: 1)
        base.strokeColor = .white.withAlphaComponent(0.35)
        base.lineWidth = 2
        node.addChild(base)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 11
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -36)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        node.addChild(label)
        return node
    }

    private func makeChest(title: String) -> SKNode {
        let node = SKNode()
        node.zPosition = 7

        let body = SKShapeNode(rectOf: CGSize(width: 52, height: 38), cornerRadius: 0)
        body.fillColor = UIColor(red: 0.58, green: 0.31, blue: 0.13, alpha: 1)
        body.strokeColor = UIColor(red: 0.24, green: 0.11, blue: 0.04, alpha: 1)
        body.lineWidth = 3

        let band = SKShapeNode(rectOf: CGSize(width: 52, height: 8), cornerRadius: 0)
        band.position = CGPoint(x: 0, y: 4)
        band.fillColor = UIColor(red: 0.95, green: 0.72, blue: 0.26, alpha: 1)
        band.strokeColor = .clear

        let lock = SKShapeNode(rectOf: CGSize(width: 10, height: 14), cornerRadius: 0)
        lock.position = CGPoint(x: 0, y: -4)
        lock.fillColor = UIColor(red: 0.98, green: 0.82, blue: 0.34, alpha: 1)
        lock.strokeColor = .clear

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = title
        label.fontSize = 10
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -35)
        label.horizontalAlignmentMode = .center

        node.addChild(body)
        node.addChild(band)
        node.addChild(lock)
        node.addChild(label)
        return node
    }

    private func addHealthPips(to node: SKNode, maxHealth: Int, yOffset: CGFloat) {
        guard maxHealth > 0 else { return }
        let pipSize = CGSize(width: maxHealth > 5 ? 7 : 9, height: 6)
        let spacing: CGFloat = maxHealth > 5 ? 9 : 11
        let startX = -CGFloat(maxHealth - 1) * spacing / 2

        for index in 0..<maxHealth {
            let pip = SKShapeNode(rectOf: pipSize, cornerRadius: 0)
            pip.name = "health-pip-\(index)"
            pip.position = CGPoint(x: startX + CGFloat(index) * spacing, y: yOffset)
            pip.fillColor = UIColor(red: 0.94, green: 0.18, blue: 0.18, alpha: 1)
            pip.strokeColor = UIColor.black.withAlphaComponent(0.35)
            pip.lineWidth = 1
            pip.zPosition = 4
            node.addChild(pip)
        }
    }

    private func updateHealthPips(on node: SKNode, health: Int) {
        for child in node.children {
            guard let name = child.name, name.hasPrefix("health-pip-") else { continue }
            let indexText = name.replacingOccurrences(of: "health-pip-", with: "")
            guard let index = Int(indexText) else { continue }
            child.alpha = index < max(health, 0) ? 1.0 : 0.18
        }
    }

    private func makeEnemy(level: Int) -> SKNode {
        let node = SKNode()
        node.zPosition = 24

        let body = SKShapeNode(rectOf: CGSize(width: 42, height: 34), cornerRadius: 0)
        body.fillColor = UIColor(red: 0.58, green: 0.16, blue: 0.12, alpha: 1)
        body.strokeColor = UIColor(red: 0.26, green: 0.05, blue: 0.03, alpha: 1)
        body.lineWidth = 3

        let eye = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 0)
        eye.position = CGPoint(x: 14, y: 6)
        eye.fillColor = UIColor(red: 1, green: 0.88, blue: 0.35, alpha: 1)
        eye.strokeColor = .clear

        for x in [-16, 0, 16] {
            let spike = SKShapeNode(rectOf: CGSize(width: 10, height: 14), cornerRadius: 0)
            spike.position = CGPoint(x: x, y: 20)
            spike.fillColor = UIColor(red: 0.95, green: 0.64, blue: 0.20, alpha: 1)
            spike.strokeColor = .clear
            node.addChild(spike)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Lv \(level)"
        label.fontSize = 9
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -31)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        node.addChild(body)
        node.addChild(eye)
        return node
    }

    private func makeBrush() -> SKNode {
        let node = SKNode()
        node.zPosition = 3

        for offset in [CGPoint(x: -12, y: -2), CGPoint(x: 0, y: 7), CGPoint(x: 13, y: -4)] {
            let leaf = SKShapeNode(rectOf: CGSize(width: 28, height: 22), cornerRadius: 0)
            leaf.position = offset
            leaf.fillColor = UIColor(red: 0.10, green: 0.47, blue: 0.20, alpha: 1)
            leaf.strokeColor = UIColor(red: 0.05, green: 0.27, blue: 0.10, alpha: 1)
            leaf.lineWidth = 1.5
            node.addChild(leaf)
        }

        return node
    }

    private func makeGate() -> SKNode {
        let node = SKNode()
        node.zPosition = 12

        for x in [-28, 28] {
            let pillar = SKShapeNode(rectOf: CGSize(width: 18, height: 72), cornerRadius: 0)
            pillar.position = CGPoint(x: x, y: 0)
            pillar.fillColor = UIColor(red: 0.43, green: 0.43, blue: 0.39, alpha: 1)
            pillar.strokeColor = UIColor.white.withAlphaComponent(0.35)
            pillar.lineWidth = 2
            node.addChild(pillar)
        }

        for y in [-18, 0, 18] {
            let bar = SKShapeNode(rectOf: CGSize(width: 68, height: 9), cornerRadius: 0)
            bar.position = CGPoint(x: 0, y: y)
            bar.fillColor = UIColor(red: 0.60, green: 0.58, blue: 0.50, alpha: 1)
            bar.strokeColor = UIColor(red: 0.30, green: 0.29, blue: 0.25, alpha: 1)
            bar.lineWidth = 1
            node.addChild(bar)
        }

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "Sky Gate"
        label.fontSize = 11
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: -54)
        label.horizontalAlignmentMode = .center
        node.addChild(label)

        return node
    }
}

private extension CGPoint {
    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs = lhs + rhs
    }

    static func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: CGFloat {
        hypot(x, y)
    }

    var normalized: CGPoint {
        let magnitude = max(length, 0.0001)
        return CGPoint(x: x / magnitude, y: y / magnitude)
    }

    func distance(to other: CGPoint) -> CGFloat {
        (self - other).length
    }

    func clamped(to maxLength: CGFloat) -> CGPoint {
        length > maxLength ? normalized * maxLength : self
    }

    func lerp(to other: CGPoint, amount: CGFloat) -> CGPoint {
        self + (other - self) * amount
    }
}

private extension CGVector {
    var length: CGFloat {
        hypot(dx, dy)
    }

    var normalized: CGVector {
        let magnitude = max(length, 0.0001)
        return CGVector(dx: dx / magnitude, dy: dy / magnitude)
    }
}
