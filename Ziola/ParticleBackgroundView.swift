import SwiftUI
import SpriteKit
import Combine

// HomeViewやGlobeSceneViewで使用する状態クラス
// ※このファイルに定義を残しておくことで、他ファイルからの参照エラーを防ぎます
class InteractionState: ObservableObject {
    @Published var velocity: CGFloat = 0.0
    @Published var isGachaLoading: Bool = false
    @Published var isIdlePaused: Bool = false
    @Published var hasSpunGlobe: Bool = false // Track if globe has been spun
}

struct ParticleBackgroundView: View {
    // パーティクルの動きは固定・ランダム出現になったため、外部からの操作(InteractionState)は不要になりました
    @State private var scene: ParticleScene? = nil

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "FFFFFF"), location: 0.0),
                    .init(color: Color(hex: "ABACF4"), location: 0.25),
                    .init(color: Color(hex: "4347E6"), location: 1.0)
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()

            // シーンが表示可能になったら描画
            if let scene = scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            // シーンの初期化（初回のみ）
            if scene == nil {
                let newScene = ParticleScene()
                newScene.size = UIScreen.main.bounds.size
                newScene.scaleMode = .resizeFill
                self.scene = newScene
            }
        }
    }
}

// MARK: - SpriteKit Scene

final class ParticleScene: SKScene {
    
    private let particleCount = 100

    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        self.scaleMode = .resizeFill
        
        // パーティクルを生成
        for _ in 0..<particleCount {
            createParticle()
        }
    }
    
    private func createParticle() {
        // 粒子の基本ノード（最初は透明にしておく）
        let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.0...2.5))
        particle.fillColor = .white
        particle.strokeColor = .clear
        particle.alpha = 0
        
        addChild(particle)
        
        // --- アニメーションサイクル ---
        
        // 1. リセットアクション: 消えている間に場所とサイズを再抽選する
        let resetState = SKAction.run { [weak self, weak particle] in
            guard let self = self, let p = particle else { return }
            
            // 画面内のランダムな位置へ移動
            p.position = CGPoint(
                x: CGFloat.random(in: 0...self.size.width),
                y: CGFloat.random(in: 0...self.size.height)
            )
            
            // 奥行き（サイズ）をランダムに変更
            let depth = CGFloat.random(in: 0.1...1.0)
            let scale = depth * 0.8 + 0.2
            p.xScale = scale
            p.yScale = scale
            
            // この回の「最大不透明度」を計算して保存（手前ほど明るく）
            p.userData = ["targetAlpha": depth * 0.6 + 0.2]
        }
        
        // 2. フェードイン: 0 から targetAlpha まで徐々に明るくする
        let fadeInDuration = Double.random(in: 1.5...3.0)
        let fadeIn = SKAction.customAction(withDuration: fadeInDuration) { node, elapsedTime in
            guard let targetAlpha = node.userData?["targetAlpha"] as? CGFloat else { return }
            let percentage = CGFloat(elapsedTime) / CGFloat(fadeInDuration)
            node.alpha = targetAlpha * percentage
        }
        
        // 3. 待機: しばらく表示しておく
        let waitVisible = SKAction.wait(forDuration: Double.random(in: 1.0...3.0))
        
        // 4. フェードアウト: 徐々に消える
        let fadeOut = SKAction.fadeOut(withDuration: Double.random(in: 1.5...3.0))
        
        // 5. 待機: 消えたまま少し待つ（次の出現までの間隔）
        let waitHidden = SKAction.wait(forDuration: Double.random(in: 0.5...2.0))
        
        // サイクルを作成
        let cycle = SKAction.sequence([
            resetState,
            fadeIn,
            waitVisible,
            fadeOut,
            waitHidden
        ])
        
        // --- 実行開始 ---
        // アプリ起動時に一斉に光り出さないよう、開始タイミングをランダムにずらす
        let initialDelay = SKAction.wait(forDuration: Double.random(in: 0...5.0))
        
        let loop = SKAction.sequence([
            initialDelay,
            SKAction.repeatForever(cycle)
        ])
        
        particle.run(loop)
    }
}
