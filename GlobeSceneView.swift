import SwiftUI
import SceneKit

struct GlobeSceneView: UIViewRepresentable {
    /// 1回の「ガチャスピン」が始まるタイミングで呼ばれる
    var onSpin: (_ spinDuration: TimeInterval) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        // ===== Scene / node セットアップ =====
        let scene = SCNScene(named: "ziora.usdz") ?? SCNScene()
        let root  = scene.rootNode

        // ★ もうライトは消さない（Blender 側の設定も生かす）
        // root.enumerateChildNodes { node, _ in node.light = nil }

        // 地球ノードだけまとめる
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
        let camera     = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // =========================
        //   ざっくりしたライト構成
        // =========================

        // MARK: 左上からのメインライト（白っぽい・広め）

        let keyLight = SCNLight()
        keyLight.type      = .directional
        keyLight.intensity = 2600
        keyLight.color     = UIColor(white: 1.0, alpha: 1.0)
        keyLight.castsShadow = false

        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        // 左上から全体をなでる
        keyLightNode.position = SCNVector3(-10.0, 10.0, 6.0)
        keyLightNode.look(at: SCNVector3(0.0, 1.1, 0.0))



        // MARK: 右側〜右下をふわっと紫で包むフィルライト

        let fillLight = SCNLight()
        fillLight.type      = .spot
        fillLight.intensity = 3200                       // 紫の明るさ（強すぎたら 2800〜3000）
        fillLight.color     = UIColor(
            red:   0.93,   // しっかり紫寄り
            green: 0.68,
            blue:  1.0,
            alpha: 1.0
        )
        fillLight.castsShadow = false

        // ライトの広がり：かなり大きめにして「光源っぽさ」を消す
        fillLight.spotInnerAngle = 65                    // コア（縁の一番明るい部分）
        fillLight.spotOuterAngle = 150                   // ふわっと広がる範囲

        // 距離減衰をかなりゆるくして、右側一帯にまわり込むように
        fillLight.attenuationStartDistance   = 4.0
        fillLight.attenuationEndDistance     = 80.0
        fillLight.attenuationFalloffExponent = 0.8      // 小さいほど全体にふんわり回る

        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight

        // 右前やや上から、地球の「右側面〜右下縁」をなでる
        fillLightNode.position = SCNVector3(24.0, 4.0, 16.0)
        // ← ここを動かすと右側の当たり方が変わる：x で左右、y で上下、z で距離

        // 狙う場所を「地球の右側」に変更（x をプラスに）
        fillLightNode.look(at: SCNVector3(2.0, -0.3, 0.0))
        // ↑ もっと下側を紫にしたければ y を -0.6 とかに、
        //   もっと真正面寄りなら x を 1.0〜1.5 にしてみて



        // MARK: 全体の底上げ用アンビエント

        let ambientLight = SCNLight()
        ambientLight.type      = .ambient
        ambientLight.intensity = 80                      // ちょい上げて影をやわらかく
        ambientLight.color     = UIColor(white: 0.95, alpha: 1.0)

        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight



        // ルートに追加
        scene.rootNode.addChildNode(keyLightNode)
        scene.rootNode.addChildNode(fillLightNode)
        scene.rootNode.addChildNode(ambientLightNode)

        // コンテナ
        let containerNode = SCNNode()
        containerNode.addChildNode(globeNode)
        scene.rootNode.addChildNode(containerNode)

        scnView.scene = scene

        // ★ ここで “ぐるっと一周・ふわっと光る” リムライトをマテリアルに付ける
        applyRimShader(to: globeNode)

        // Coordinator にノードを渡す
        context.coordinator.globeNode = globeNode
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

    // MARK: - Rim light shader

    /// 法線と視線ベクトルのなす角で縁を判断して、
    /// 地球のシルエット全周を白く発光させるシェーダ
    private func applyRimShader(to globeNode: SCNNode) {
        // surface ステージで emission を足す
        let shader =
        """
        #pragma arguments
        float rimStrength;
        float rimPower;
        float3 rimColor;
        #pragma body

        // normal と view の内積（0 = 真横, 1 = 正面）
        float ndv = dot(_surface.normal, _surface.view);
        ndv = clamp(ndv, 0.0, 1.0);

        // 縁ほど値が大きくなるように反転＆べき乗
        float rim = pow(1.0 - ndv, rimPower) * rimStrength;

        // emission に追加して “ふわっと” 光らせる
        _surface.emission.rgb += rim * rimColor;
        """

        globeNode.enumerateChildNodes { node, _ in
            guard let geom = node.geometry else { return }

            for material in geom.materials {
                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = shader
                material.shaderModifiers = modifiers

                // 好きな感じになるまでここを微調整
                material.setValue(1.2 as NSNumber,         forKey: "rimStrength") // 縁の明るさ
                material.setValue(4.0 as NSNumber,          forKey: "rimPower")    // 縁の「幅」（大きいほど細くシャープ）
                material.setValue(SCNVector3(1.4, 1.4, 1.7), forKey: "rimColor")   // 少しだけ青寄りの白
            }
        }
    }

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
                let location = gesture.location(in: view)
                let hits = view.hitTest(location, options: nil)

                let hitGlobe = hits.contains { result in
                    guard let globe = self.globeNode else { return false }
                    return result.node === globe || result.node.isChild(of: globe)
                }

                guard hitGlobe else {
                    isDraggingGlobe = false
                    return
                }

                isDraggingGlobe = true
                setIdleRotation(enabled: false)
                node.removeAllActions()

            case .changed:
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

// MARK: - 小さなヘルパー

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
