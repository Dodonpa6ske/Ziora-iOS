import SwiftUI
import SceneKit

struct GlobeSceneView: UIViewRepresentable {
    var onSpin: (_ spinDuration: TimeInterval) -> Void = { _ in }
    
    // パーティクルへ速度を伝えるための参照
    @ObservedObject var interactionState: InteractionState

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.isJitteringEnabled = true

        let scene = SCNScene(named: "ziora.usdz") ?? SCNScene()
        let root  = scene.rootNode

        let globeNode = SCNNode()
        for child in root.childNodes {
            globeNode.addChildNode(child)
        }

        // 基本スケール
        globeNode.scale = SCNVector3(9.7, 9.7, 9.7)
        globeNode.position = SCNVector3(0, -0.3, 0)
        // 初期角度: X=270度
        globeNode.eulerAngles = SCNVector3(Float.pi * 1.5, Float.pi, 0)

        // カメラ設定
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.wantsHDR = true
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // ライティング（既存コード通り）
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 50
        ambientLight.color = UIColor(white: 0.5, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 3000
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.castsShadow = true
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(-18.0, 10.0, 15.0)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)

        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 2500
        fillLight.color = UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
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
        rimLightNode.position = SCNVector3(0, 8, -10)
        rimLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLightNode)

        let sideLight = SCNLight()
        sideLight.type = .directional
        sideLight.intensity = 1500
        sideLight.color = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        let sideLightNode = SCNNode()
        sideLightNode.light = sideLight
        sideLightNode.position = SCNVector3(20.0, 0.0, 5.0)
        sideLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(sideLightNode)

        // ★ コンテナノードの構成
        let containerNode = SCNNode()
        containerNode.addChildNode(globeNode)
        scene.rootNode.addChildNode(containerNode)

        scnView.scene = scene

        setupGlobeMaterial(for: globeNode)

        // Coordinator に globeNode と containerNode の両方を渡す
        context.coordinator.globeNode = globeNode
        context.coordinator.containerNode = containerNode // ★追加
        context.coordinator.setIdleRotation(enabled: true)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        scnView.addGestureRecognizer(pan)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    // MARK: - Material Setup
    private func setupGlobeMaterial(for node: SCNNode) {
        // (省略: 元のコードと同じ内容)
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
        let parent: GlobeSceneView
        weak var globeNode: SCNNode?
        weak var containerNode: SCNNode? // ★追加: 横回転（Y軸）を担当する親ノード
        
        private var idleRotationEnabled = true
        private var isDraggingGlobe = false
        
        private let baseScale: CGFloat = 9.7
        private let defaultPitch: Float = Float.pi * 1.5

        init(parent: GlobeSceneView) { self.parent = parent }

        func setIdleRotation(enabled: Bool) {
            idleRotationEnabled = enabled
            guard let node = globeNode else { return }
            node.removeAction(forKey: "idleRotation")
            guard enabled else { return }
            
            // アイドル回転は地球儀自体（ローカルY軸）を回す
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 30)
            rotate.timingMode = .linear
            node.runAction(SCNAction.repeatForever(rotate), forKey: "idleRotation")
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  let globe = globeNode,
                  let container = containerNode else { return }
            
            switch gesture.state {
            case .began:
                let location = gesture.location(in: view)
                let hits = view.hitTest(location, options: nil)
                let hitGlobe = hits.contains { $0.node === globe || $0.node.isChild(of: globe) }
                guard hitGlobe else { isDraggingGlobe = false; return }
                
                isDraggingGlobe = true
                setIdleRotation(enabled: false)
                globe.removeAllActions()
                container.removeAllActions() // コンテナのアクションも止める
                
            case .changed:
                guard isDraggingGlobe else { return }
                let translation = gesture.translation(in: view)
                let velocity = gesture.velocity(in: view)
                
                parent.interactionState.velocity = velocity.x / 5.0
                
                let sensitivity: CGFloat = 0.005
                
                // ★ 修正ポイント: 回転軸の分離
                
                // 1. 横スワイプ (translation.x) -> コンテナ(親)をY軸回転させる
                //    コンテナは傾かないため、常に「画面に対して垂直な軸」で回転します
                container.runAction(SCNAction.rotateBy(x: 0, y: translation.x * sensitivity, z: 0, duration: 0.1))
                
                // 2. 縦スワイプ (translation.y) -> 地球儀(子)をX軸回転（チルト）させる
                //    地球儀がどれだけ横に回っていても、自身のX軸で回れば正しくお辞儀します
                globe.runAction(SCNAction.rotateBy(x: -translation.y * sensitivity, y: 0, z: 0, duration: 0.1))
                
                gesture.setTranslation(.zero, in: view)
                
            case .ended, .cancelled:
                guard isDraggingGlobe else { return }
                isDraggingGlobe = false
                
                let v = gesture.velocity(in: view)
                let magnitude = sqrt(v.x * v.x + v.y * v.y)
                let minV: CGFloat = 1000
                
                // 直立に戻すアクション（globeNodeの傾きXのみリセットすればOK）
                func makeStraightenAction(duration: TimeInterval) -> SCNAction {
                    let startX = globe.eulerAngles.x
                    let startZ = globe.eulerAngles.z
                    let targetX = self.defaultPitch
                    let targetZ: Float = 0
                    
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

                    let turns = 1.2 + 1.5 * t
                    let baseAngle = CGFloat.pi * 2 * turns * direction
                    let boostedAngle = baseAngle * 1.5

                    let minDuration: TimeInterval = 0.9
                    let maxDuration: TimeInterval = 1.8
                    let duration = maxDuration - (maxDuration - minDuration) * TimeInterval(t)

                    DispatchQueue.main.async { self.parent.onSpin(duration) }

                    // ガチャ回転（メインY軸）
                    // ここは地球儀自体のスピン（自転）なので globeNode を回してOK
                    let spin = SCNAction.rotateBy(x: 0, y: boostedAngle, z: 0, duration: duration)
                    spin.timingMode = .linear
                    spin.timingFunction = { t in
                        let x = 1 - t
                        return 1 - x * x * x * x
                    }
                    
                    let straighten = makeStraightenAction(duration: duration)
                    let group = SCNAction.group([spin, straighten])
                    
                    globe.runAction(group) {
                        globe.eulerAngles.x = self.defaultPitch
                        globe.eulerAngles.z = 0
                        DispatchQueue.main.async { self.setIdleRotation(enabled: true) }
                    }
                    
                } else {
                    // --- ガチャ不発（慣性） ---
                    // 慣性は単純化のため globeNode に適用（すぐに straighten で戻るため違和感は少ない）
                    let inertiaX = -v.y * 0.001
                    let inertiaY = v.x * 0.001
                    let inertia = SCNAction.rotateBy(x: inertiaX, y: inertiaY, z: 0, duration: 1.0)
                    inertia.timingMode = .easeOut
                    
                    let straighten = makeStraightenAction(duration: 1.0)
                    let group = SCNAction.group([inertia, straighten])
                    
                    globe.runAction(group) {
                        globe.eulerAngles.x = self.defaultPitch
                        globe.eulerAngles.z = 0
                        DispatchQueue.main.async { self.setIdleRotation(enabled: true) }
                    }
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
