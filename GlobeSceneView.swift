import SwiftUI
import SceneKit

struct GlobeSceneView: UIViewRepresentable {
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

        let scene = SCNScene(named: "ziora.usdz") ?? SCNScene()
        let root  = scene.rootNode

        let globeNode = SCNNode()
        for child in root.childNodes {
            globeNode.addChildNode(child)
        }

        globeNode.scale = SCNVector3(9.7, 9.7, 9.7)
        globeNode.position = SCNVector3(0, -0.3, 0)
        globeNode.eulerAngles = SCNVector3(Float.pi * 1.5, Float.pi, 0)

        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = false
        camera.wantsHDR = true
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 7)
        scene.rootNode.addChildNode(cameraNode)

        // =========================
        //   ライティング設定（メリハリ版・継続）
        // =========================

        // 1. アンビエントライト
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 150
        ambientLight.color = UIColor(white: 0.8, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight

        // 2. メインライト
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 1000
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.castsShadow = true
        
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(-5.0, 8.0, 10.0)
        keyLightNode.look(at: SCNVector3(0, 0, 0))

        // 3. フィルライト
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 600
        fillLight.color = UIColor(red: 0.6, green: 0.5, blue: 0.9, alpha: 1.0)
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(5.0, -5.0, 5.0)
        fillLightNode.look(at: SCNVector3(0, 0, 0))

        // 4. リムライト
        let rimLight = SCNLight()
        rimLight.type = .spot
        rimLight.intensity = 1200
        rimLight.color = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
        rimLight.spotInnerAngle = 0
        rimLight.spotOuterAngle = 120
        
        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        rimLightNode.position = SCNVector3(0, 5, -10)
        rimLightNode.look(at: SCNVector3(0, 0, 0))

        scene.rootNode.addChildNode(ambientLightNode)
        scene.rootNode.addChildNode(keyLightNode)
        scene.rootNode.addChildNode(fillLightNode)
        scene.rootNode.addChildNode(rimLightNode)

        let containerNode = SCNNode()
        containerNode.addChildNode(globeNode)
        scene.rootNode.addChildNode(containerNode)

        scnView.scene = scene

        setupGlobeMaterial(for: globeNode)

        context.coordinator.globeNode = globeNode
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
                
                // 質感設定（はっきりとした印象用）
                material.roughness.contents = NSNumber(value: 0.8)
                material.metalness.contents = NSNumber(value: 0.1)
                material.specular.contents = UIColor(white: 0.2, alpha: 1.0)

                var modifiers = material.shaderModifiers ?? [:]
                modifiers[.surface] = shader
                material.shaderModifiers = modifiers

                material.setValue(1.0 as NSNumber,         forKey: "rimStrength")
                material.setValue(2.5 as NSNumber,         forKey: "rimPower")
                material.setValue(SCNVector3(1.0, 1.0, 1.3), forKey: "rimColor")
            }
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject {
        let parent: GlobeSceneView
        weak var globeNode: SCNNode?
        private var idleRotationEnabled = true
        private var isDraggingGlobe = false

        init(parent: GlobeSceneView) { self.parent = parent }

        func setIdleRotation(enabled: Bool) {
            idleRotationEnabled = enabled
            guard let node = globeNode else { return }
            node.removeAction(forKey: "idleRotation")
            guard enabled else { return }
            let rotate = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 30)
            rotate.timingMode = .linear
            node.runAction(SCNAction.repeatForever(rotate), forKey: "idleRotation")
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView, let node = globeNode else { return }
            switch gesture.state {
            case .began:
                let location = gesture.location(in: view)
                let hits = view.hitTest(location, options: nil)
                let hitGlobe = hits.contains { $0.node === node || $0.node.isChild(of: node) }
                guard hitGlobe else { isDraggingGlobe = false; return }
                isDraggingGlobe = true
                setIdleRotation(enabled: false)
                node.removeAllActions()
            case .changed:
                guard isDraggingGlobe else { return }
                let translation = gesture.translation(in: view)
                node.runAction(SCNAction.rotateBy(x: 0, y: translation.x * (.pi / 360), z: 0, duration: 0.1))
                gesture.setTranslation(.zero, in: view)
            case .ended, .cancelled:
                guard isDraggingGlobe else { return }
                isDraggingGlobe = false
                
                // 元の回転ロジックを復元（型指定でコンパイルエラー回避）
                let vX = gesture.velocity(in: view).x
                let absV = abs(vX)
                let minV: CGFloat = 600
                
                if absV > minV {
                    let maxV: CGFloat = 2400
                    let direction: CGFloat = (vX >= 0) ? 1 : -1

                    // 速度のクランプと t値（0.0〜1.0）の計算
                    let clampedV = max(minV, min(maxV, absV))
                    let t = (clampedV - minV) / (maxV - minV)

                    // 元の「勢い」計算式を復元
                    let turns = 1.7 + 2.0 * t
                    let baseAngle = CGFloat.pi * 2 * turns * direction
                    let boostedAngle = baseAngle * 1.5

                    // 時間計算
                    let minDuration: TimeInterval = 0.9
                    let maxDuration: TimeInterval = 1.8
                    let duration = maxDuration - (maxDuration - minDuration) * TimeInterval(t)

                    DispatchQueue.main.async { self.parent.onSpin(duration) }

                    let spin = SCNAction.rotateBy(x: 0, y: boostedAngle, z: 0, duration: duration)
                    
                    // ★ 復元: 元の独自イージング関数（Quartic Ease-Out）
                    spin.timingMode = .linear
                    spin.timingFunction = { t in
                        let x = 1 - t
                        return 1 - x * x * x * x
                    }
                    
                    node.runAction(spin) {
                        DispatchQueue.main.async { self.setIdleRotation(enabled: true) }
                    }
                } else {
                    setIdleRotation(enabled: true)
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
