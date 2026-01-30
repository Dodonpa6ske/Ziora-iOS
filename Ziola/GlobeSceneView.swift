import SwiftUI
import SceneKit

struct GlobeSceneView: UIViewRepresentable {
    var onSpin: (_ spinDuration: TimeInterval) -> Void = { _ in }
    var onCardTiming: () -> Void = {} // ★追加
    
    // パーティクルへ速度を伝えるための参照
    @ObservedObject var interactionState: InteractionState
    var isInteractionEnabled: Bool = true // ★追加: 外部からの操作無効化

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        let scene = SCNScene() // Start empty for instant UI load
        
        // メインスレッドでノードの枠だけ先に作る (Scopeエラー回避)
        let globeNode = SCNNode()
        // ★修正: 生成直後はScale 0にしておく（ロード完了前のチラつき防止）
        globeNode.scale = SCNVector3(0, 0, 0)
        
        let containerNode = SCNNode()
        
        // 構成
        containerNode.addChildNode(globeNode)
        scene.rootNode.addChildNode(containerNode)
        
        // ローディング（非同期）
        DispatchQueue.global(qos: .userInitiated).async {
            if let loadedScene = SCNScene(named: "ziora.usdz") {
                let loadedNodes = loadedScene.rootNode.childNodes
                
                DispatchQueue.main.async {
                    // 読み込んだモデルをglobeNodeの子として追加
                    for child in loadedNodes {
                        globeNode.addChildNode(child)
                    }
                    
                    // 初期変形 (念のため再度0に)
                    globeNode.scale = SCNVector3(0, 0, 0)
                    globeNode.position = SCNVector3(0, -0.3, 0)
                    globeNode.eulerAngles = SCNVector3(Float.pi * 1.5, Float.pi, 0)
                    globeNode.opacity = 0 // ★追加: 透明から始める
                    
                    // マテリアル設定（モデル読み込み後に実行）
                    self.setupGlobeMaterial(for: globeNode)
                    
                    // 登場アニメーション (バウンス調整: 0 -> 105% -> 100%)
                    let fadeIn = SCNAction.fadeIn(duration: 0.2)
                    let scaleUp = SCNAction.scale(to: 9.7 * 1.05, duration: 0.35)
                    scaleUp.timingMode = .easeOut
                    
                    let appearGroup = SCNAction.group([fadeIn, scaleUp])
                    
                    let scaleBack = SCNAction.scale(to: 9.7, duration: 0.25)
                    scaleBack.timingMode = .easeOut
                    
                    // 少し待ってから開始（画面遷移アニメーションとの被りを避ける）
                    let sequence = SCNAction.sequence([
                        SCNAction.wait(duration: 0.1),
                        appearGroup, 
                        scaleBack
                    ])
                    globeNode.runAction(sequence)
                }
            }
        }


        // カメラ設定
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.wantsHDR = true
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // ライティング
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 50
        ambientLight.color = UIColor(white: 0.5, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        ambientLightNode.name = "ambient" // Name for access
        scene.rootNode.addChildNode(ambientLightNode)

        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 3000
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.castsShadow = true
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.name = "key"
        keyLightNode.position = SCNVector3(-18.0, 10.0, 15.0)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)

        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 2500
        fillLight.color = UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.name = "fill"
        fillLightNode.position = SCNVector3(15.0, -20.0, 5.0)
        fillLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(fillLightNode)

        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.intensity = 1800
        rimLight.color = UIColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0)
        rimLight.spotInnerAngle = 0
        rimLight.spotOuterAngle = 120
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.name = "rim"
        rimLightNode.position = SCNVector3(0, 8, -10)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)

        let sideLight = SCNLight()
        sideLight.type = .directional
        sideLight.intensity = 1500
        sideLight.color = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        let sideLightNode = SCNNode()
        sideLightNode.light = sideLight
        sideLightNode.name = "side"
        sideLightNode.position = SCNVector3(20.0, 0.0, 5.0)
        sideLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(sideLightNode)

        // scnViewにシーンセット
        scnView.scene = scene

        // Coordinator への参照渡し (globeNodeは空だが参照は有効)
        context.coordinator.globeNode = globeNode
        context.coordinator.containerNode = containerNode
        context.coordinator.scene = scene // Save scene reference
        context.coordinator.updateRotationState()
        context.coordinator.updateLightingState() // Initial state

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // ★追加: 親view (struct) の最新状態をCoordinatorに渡す
        context.coordinator.parent = self
        
        // インタラクション状態に応じて回転状態を更新
        context.coordinator.updateRotationState()
        context.coordinator.updateLightingState()
    }

    // MARK: - Material Setup
    private func setupGlobeMaterial(for node: SCNNode) {
        let shader = """
        #pragma arguments
        float rimStrength;
        float rimPower;
        float3 rimColor;
        #pragma body
        float ndv = dot(_surface.normal, _surface.view);
        ndv = clamp(ndv, 0.0, 1.0);
        float rim = pow(1.0 - ndv, rimPower) * rimStrength;
        _surface.emission.rgb += rim * rimColor;
        """

        node.enumerateChildNodes { child, _ in
            guard let geom = child.geometry else { return }

            for material in geom.materials {
                material.lightingModel = .physicallyBased
                material.roughness.contents = NSNumber(value: 0.6)
                material.metalness.contents = NSNumber(value: 0.1)
                material.specular.contents = UIColor(white: 0.8, alpha: 1.0)

                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = shader
                material.shaderModifiers = modifiers

                material.setValue(2.0 as NSNumber,         forKey: "rimStrength")
                material.setValue(4.0 as NSNumber,         forKey: "rimPower")
                material.setValue(SCNVector3(0.8, 0.9, 1.0), forKey: "rimColor")
            }
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject {
        var parent: GlobeSceneView // ★修正: let -> var にして更新可能にする
        weak var globeNode: SCNNode?
        weak var containerNode: SCNNode?
        weak var scene: SCNScene? // Reference to scene for lighting
        
        enum RotationMode { case stopped, idle, loading }
        var rotationMode: RotationMode = .stopped
        var rotationDirection: CGFloat = 1.0
        
        var idleRotationEnabled = false
        var isSpinning = false
        private var isDraggingGlobe = false

        // MARK: - Lighting Logic
        func updateLightingState() {
            guard let scene = scene else { return }
            
            // Paused (Popup active) = Dimmed, Otherwise = Normal
            let isDimmed = parent.interactionState.isIdlePaused
            
            // ★非対称アニメーション: 暗くなる時はゆっくり(0.5s)、戻る時は一瞬(0.1s)
            // これにより「ボワっと影が消える」現象を防ぎ、カード消去と同時に明るくする
            let duration: TimeInterval = isDimmed ? 0.5 : 0.1
            
            func animateLight(_ name: String, to intensity: CGFloat) {
                guard let node = scene.rootNode.childNode(withName: name, recursively: true),
                      let light = node.light else { return }
                
                SCNTransaction.begin()
                SCNTransaction.animationDuration = duration
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
                light.intensity = intensity
                SCNTransaction.commit()
            }
            
            if isDimmed {
                // Dimmed State (Popup open) - 50% Intensity
                animateLight("key", to: 1500)   // 3000 * 0.5
                animateLight("fill", to: 1250)  // 2500 * 0.5
                animateLight("rim", to: 900)    // 1800 * 0.5
                animateLight("side", to: 750)   // 1500 * 0.5
            } else {
                // Normal State (Idle)
                animateLight("key", to: 3000)
                animateLight("fill", to: 2500)
                animateLight("rim", to: 1800)
                animateLight("side", to: 1500)
            }
        }
        
        private let baseScale: CGFloat = 9.7
        private let defaultPitch: Float = Float.pi * 1.5

        init(parent: GlobeSceneView) { self.parent = parent }

        // 回転状態を一括管理
        func updateRotationState() {
            let node = globeNode
            
            // 1. 一時停止(カード表示中など) - 最優先
            if parent.interactionState.isIdlePaused {
                node?.removeAction(forKey: "idleRotation")
                
                // スピン中なら強制停止
                if isSpinning {
                    containerNode?.removeAction(forKey: "spin")
                    isSpinning = false
                }
                return
            }
            
            // ドラッグ中、またはガチャ回転アニメ中はアイドリング制御しない
            guard !isDraggingGlobe, !isSpinning else { return }
            
            // 優先度順にターゲットを決定
            var targetMode: RotationMode = .idle
            if parent.interactionState.isGachaLoading { targetMode = .loading }
            
            // 状態が変わらなければ何もしない (ただし停止->再開などはRampしたいのでチェックは厳密に)
            // モードが同じで、かつアクションが実行中ならスキップ
            if rotationMode == targetMode && node?.action(forKey: "idleRotation") != nil { return }
            
            rotationMode = targetMode
            node?.removeAction(forKey: "idleRotation")
            
            guard targetMode != .stopped else { return }
            
            // 回転設定
            let oneTurnDuration: TimeInterval = (targetMode == .loading) ? 25.0 : 30.0
            
            // --- Ramp Up Logic ---
            // いきなり定速回転ではなく、停止状態から徐々に加速して定速に移行する
            let rampDuration: TimeInterval = 3.0 // ゆっくり加速
            let targetSpeed = CGFloat.pi * 2 / oneTurnDuration // rad/sec
            
            // 現在のY軸角度を基準にする
            let startY = CGFloat(node?.eulerAngles.y ?? 0)
            
            // CustomActionで滑らかな立ち上がり（S字カーブ的加速）を実装
            // 速度プロファイル v(t) が smoothstep のようになり、加速の「カクツキ」を消す
            // DeltaAngle = TargetSpeed * T * (u^3 - 0.5 * u^4), where u = t/T
            let ramp = SCNAction.customAction(duration: rampDuration) { [weak self] node, elapsedTime in
                guard let self = self else { return }
                
                let t = CGFloat(elapsedTime)
                let u = t / CGFloat(rampDuration)
                
                // 積分計算による変位
                let factor = (u * u * u) - 0.5 * (u * u * u * u)
                let delta = targetSpeed * CGFloat(rampDuration) * factor
                
                node.eulerAngles.y = Float(startY + delta * self.rotationDirection)
            }
            
            let steady = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2 * rotationDirection, z: 0, duration: oneTurnDuration)
            steady.timingMode = .linear
            
            let sequence = SCNAction.sequence([ramp, SCNAction.repeatForever(steady)])
            node?.runAction(sequence, forKey: "idleRotation")
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  let globe = globeNode,
                  let container = containerNode else { return }
            
            // ★追加: インタラクション無効時は何もしない
            if !parent.isInteractionEnabled {
                return
            }
            
            switch gesture.state {
            case .began:
                isDraggingGlobe = true
                globe.removeAllActions()
                container.removeAllActions()
                updateRotationState() // 状態更新
                
            case .changed:
                guard isDraggingGlobe else { return }
                let translation = gesture.translation(in: view)
                let dragScale: CGFloat = 0.0025
                // X軸回転だけ適用 (上下の移動で) -> ユーザー要望で水平のみにするため、Y軸回転(左右の移動)のみ適用
                // let angleX = Float(translation.y) * Float(dragScale)
                let angleY = Float(translation.x) * Float(dragScale)
                
                // globe.eulerAngles.x += angleX // 上下回転ロック
                globe.eulerAngles.y += angleY

                gesture.setTranslation(.zero, in: view)
                
            case .ended, .cancelled:
                guard isDraggingGlobe else { return }
                isDraggingGlobe = false
                
                let v = gesture.velocity(in: view)
                let magnitude = sqrt(v.x * v.x + v.y * v.y)
                let minV: CGFloat = 800 // ★感度アップ
                
                // 回転方向を保存
                self.rotationDirection = v.x >= 0 ? 1.0 : -1.0
                
                func makeStraightenAction(duration: TimeInterval) -> SCNAction {
                    let startX = globe.eulerAngles.x
                    let startZ = globe.eulerAngles.z
                    
                    // ターゲット: Xはデフォルトの傾き(-90度など)、Zは0
                    let targetX = defaultPitch
                    let targetZ: Float = 0
                    
                    // 回転数を考慮しない最短経路での補正になってしまうため、
                    // スピン中に少しずつ戻す
                    
                    return SCNAction.customAction(duration: duration) { node, elapsedTime in
                        let t = CGFloat(elapsedTime) / CGFloat(duration)
                        let factor = Float(t * (2 - t))
                        node.eulerAngles.x = startX + (targetX - startX) * factor
                        node.eulerAngles.z = startZ + (targetZ - startZ) * factor
                    }
                }

                if magnitude > minV {
                    // --- ガチャ発動 ---
                    let scaleDown = SCNAction.scale(to: baseScale * 0.95, duration: 0.2)
                    scaleDown.timingMode = .easeOut
                    let scaleUp = SCNAction.scale(to: baseScale, duration: 0.3)
                    scaleUp.timingMode = .easeOut
                    globe.runAction(SCNAction.sequence([scaleDown, scaleUp]))
                    
                    let maxV: CGFloat = 2400
                    let direction: CGFloat = (v.x >= 0) ? 1 : -1
                    
                    let clampedV = max(minV, min(maxV, magnitude))
                    let t = (clampedV - minV) / (maxV - minV)
                    
                    // ★回転数アップ: 4回転〜8回転
                    let turns = 4.0 + 4.0 * t
                    let boostedAngle = CGFloat.pi * 2 * turns * direction

                    // ★時間短縮: 1.5秒〜2.5秒 (キビキビ止まる)
                    let minDuration: TimeInterval = 1.5
                    let maxDuration: TimeInterval = 2.5
                    let duration = minDuration + (maxDuration - minDuration) * TimeInterval(t)

                    // HomeViewに完了時間(=duration)を伝えて処理開始
                    Task { @MainActor in
                        self.parent.onSpin(duration)
                        self.parent.interactionState.hasSpunGlobe = true
                    }

                    // ★追加: 止まる1.0秒前にシグナルを送るアクション (0.5秒早めた)
                    let signalDelay = max(0, duration - 1.0)
                    let signalAction = SCNAction.sequence([
                        SCNAction.wait(duration: signalDelay),
                        SCNAction.run { [weak self] _ in
                            Task { @MainActor in
                                guard let self = self else { return }
                                self.parent.onCardTiming()
                            }
                        }
                    ])
                    container.runAction(signalAction, forKey: "signal")

                    let startY = container.eulerAngles.y // コンテナのY回転
                    let spinAction = SCNAction.customAction(duration: duration) { node, elapsedTime in
                        
                        let t = CGFloat(elapsedTime) / CGFloat(duration)
                        // EaseOutSext: 1 - (1-t)^6
                        let x = 1.0 - t
                        let easeVal = 1.0 - x * x * x * x * x * x
                        
                        let currentAngle = startY + Float(boostedAngle) * Float(easeVal)
                        node.eulerAngles.y = currentAngle
                    }
                    
                    let straighten = makeStraightenAction(duration: duration)
                    
                    isSpinning = true
                    
                    container.runAction(spinAction, forKey: "spin", completionHandler: { [weak self] in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.isSpinning = false
                            self.updateRotationState()
                        }
                    })
                    globe.runAction(straighten)
                    
                } else {
                    // --- ガチャ不発 ---
                    // let inertiaX = -v.y * 0.001 // 無効化
                    let inertiaY = v.x * 0.0005
                    
                    isSpinning = true // 慣性移動中もアイドリング再開を防ぐためtrue扱いにする
                    
                    // 不発時も一瞬暗くするか？ いや、低速ならチカチカしないので不要。明るいままがいい。
                    // なので animateLighting は呼ばない
                    
                    let inertia = SCNAction.rotateBy(x: 0, y: inertiaY, z: 0, duration: 1.0)
                    inertia.timingMode = .easeOut
                    
                    let straighten = makeStraightenAction(duration: 1.0)
                    
                    container.runAction(inertia, completionHandler: { [weak self] in
                        Task { @MainActor in
                            guard let self = self else { return }
                            self.isSpinning = false
                            self.updateRotationState()
                        }
                    })
                    globe.runAction(straighten)
                }
            default: break
            }
        }
    }
}

private extension SCNNode {
    func isChild(of target: SCNNode) -> Bool {
        var p = parent
        while let current = p { if current === target { return true }; p = current.parent }
        return false
    }
}
