import SpriteKit
import SwiftUI

@main
struct DinoRealmsIOSApp: App {
    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea()
                .statusBarHidden(true)
        }
    }
}

struct GameContainerView: View {
    @State private var scene = GameScene()

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .onAppear {
                    scene.resize(to: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    scene.resize(to: newSize)
                }
        }
    }
}
