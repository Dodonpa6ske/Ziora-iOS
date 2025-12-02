import SwiftUI
import SceneKit

struct GlobeSceneView: UIViewRepresentable {
    /// 1回の「ガチャスピン」が始まるタイミングで呼ばれる
    /// spinDuration: そのスピンにかかる予定時間（秒）
    var onSpin: (_ spinDuration: TimeInterval) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false

        // ===== Scene / node セットアップ =====
        let scene = SCNScene(named: "ziora.usdz") ?? SCNScene()
        let root  = scene.rootNode

        let globeNode = SCNNode()
        for child in root.childNodes {
            globeNode.addChildNode(child)
        }

        globeNode.scale = SCNVector3(9.7, 9.7, 9.7)
        globeNode.position = SCNVector3(0, -0.3, 0)
        globeNode.eulerAngles = SCNVector3(
            Float.pi * 1.5,
            Float.pi,
            0
        )

        // --- カメラ ---
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // --- ライティング（黒潰れ防止） ---
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 900
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)

        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(-3.0, 3.0, 6.0)
        keyLightNode.look(at: SCNVector3(0, 0, 0))

        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 600
        fillLight.color = UIColor(red: 0.92, green: 0.94, blue: 1.0, alpha: 1.0)

        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(3.0, -2.0, 6.0)
        fillLightNode.look(at: SCNVector3(0, 0, 0))

        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 950
        rimLight.color = UIColor(white: 1.0, alpha: 1.0)

        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(0.0, 0.5, -6.5)
        rimLightNode.look(at: SCNVector3(0, 0, 0))

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 120
        ambientLight.color = UIColor(white: 0.9, alpha: 1.0)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight

        scene.rootNode.addChildNode(keyLightNode)
        scene.rootNode.addChildNode(fillLightNode)
        scene.rootNode.addChildNode(rimLightNode)
        scene.rootNode.addChildNode(ambientLightNode)

        // コンテナ
        let containerNode = SCNNode()
        containerNode.addChildNode(globeNode)
        scene.rootNode.addChildNode(containerNode)

        scnView.scene = scene

        // Coordinator にノードを渡す
        context.coordinator.globeNode = globeNode

        // アイドリング回転開始
        context.coordinator.setIdleRotation(enabled: true)

        // パンジェスチャ
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let parent: GlobeSceneView

        weak var globeNode: SCNNode?
        private var idleRotationEnabled = true
        
        private var isDraggingGlobe = false

        init(parent: GlobeSceneView) {
            self.parent = parent
        }

        // アイドル回転（常にゆっくり右回転）
        func setIdleRotation(enabled: Bool) {
            idleRotationEnabled = enabled
            guard let node = globeNode else { return }

            node.removeAction(forKey: "idleRotation")

            guard enabled else { return }

            let rotate = SCNAction.rotateBy(
                x: 0,
                y: CGFloat.pi * 2,
                z: 0,
                duration: 30
            )
            rotate.timingMode = .linear

            let forever = SCNAction.repeatForever(rotate)
            node.runAction(forever, forKey: "idleRotation")
        }

        // MARK: - Pan gesture

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard
                let view = gesture.view as? SCNView,
                let node = globeNode
            else { return }

            switch gesture.state {
            case .began:
                // 👇 タッチ位置が地球に当たっているか判定
                let location = gesture.location(in: view)
                let hits = view.hitTest(location, options: nil)

                let hitGlobe = hits.contains { result in
                    guard let globe = self.globeNode else { return false }
                    return result.node === globe || result.node.isChild(of: globe)
                }

                // 地球に当たっていなければ、このジェスチャーは無視
                guard hitGlobe else {
                    isDraggingGlobe = false
                    return
                }

                isDraggingGlobe = true

                // ここから先はこれまで通り
                setIdleRotation(enabled: false)
                node.removeAllActions()

            case .changed:
                // 👇 地球をドラッグしていないジェスチャーは無視
                guard isDraggingGlobe else { return }

                let translation = gesture.translation(in: view)
                let anglePerPoint: CGFloat = .pi / 360
                let deltaAngle = translation.x * anglePerPoint

                node.runAction(
                    SCNAction.rotateBy(
                        x: 0,
                        y: deltaAngle,
                        z: 0,
                        duration: 0.1
                    )
                )
                gesture.setTranslation(.zero, in: view)

            case .ended, .cancelled:
                guard isDraggingGlobe else { return }
                isDraggingGlobe = false

                let velocityX = gesture.velocity(in: view).x
                let absV = abs(velocityX)

                let minV: CGFloat = 600
                let maxV: CGFloat = 2400

                if absV > minV {
                    let direction: CGFloat = (velocityX >= 0) ? 1 : -1

                    let clampedV = max(minV, min(maxV, absV))
                    let t = (clampedV - minV) / (maxV - minV)

                    let turns = 1.7 + 2.0 * t
                    let baseAngle = CGFloat.pi * 2 * turns * direction
                    let boostedAngle = baseAngle * 1.5

                    let minDuration: TimeInterval = 0.9
                    let maxDuration: TimeInterval = 1.8
                    let duration = maxDuration - (maxDuration - minDuration) * TimeInterval(t)

                    DispatchQueue.main.async {
                        self.parent.onSpin(duration)
                    }

                    let spin = SCNAction.rotateBy(
                        x: 0,
                        y: boostedAngle,
                        z: 0,
                        duration: duration
                    )
                    spin.timingMode = .linear
                    spin.timingFunction = { t in
                        let x = 1 - t
                        return 1 - x * x * x * x
                    }
                    node.runAction(spin) { [weak self] in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            self.setIdleRotation(enabled: true)
                        }
                    }
                } else {
                    setIdleRotation(enabled: true)
                }

            default:
                break
            }
        }
        }
}
private extension SCNNode {
    /// self が target の子孫かどうか
    func isChild(of target: SCNNode) -> Bool {
        var p = parent
        while let current = p {
            if current === target { return true }
            p = current.parent
        }
        return false
    }
}
