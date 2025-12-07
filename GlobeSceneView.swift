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
        //   ライティング設定（5灯体制・維持）
        // =========================

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 50
        ambientLight.color = UIColor(white: 0.5, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight

        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 3000
        keyLight.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.castsShadow = true
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(-18.0, 10.0, 15.0)
        keyLightNode.look(at: SCNVector3(0, 0, 0))

        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 2500
        fillLight.color = UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(15.0, -20.0, 5.0)
        fillLightNode.look(at: SCNVector3(0, 0, 0))

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

        let sideLight = SCNLight()
        sideLight.type = .directional
        sideLight.intensity = 1500
        sideLight.color = UIColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0)
        let sideLightNode = SCNNode()
        sideLightNode.light = sideLight
        sideLightNode.position = SCNVector3(20.0, 0.0, 5.0)
        sideLightNode.look(at: SCNVector3(0, 0, 0))

        scene.rootNode.addChildNode(ambientLightNode)
        scene.rootNode.addChildNode(keyLightNode)
        scene.rootNode.addChildNode(fillLightNode)
        scene.rootNode.addChildNode(rimLightNode)
        scene.rootNode.addChildNode(sideLightNode)

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
        private var idleRotationEnabled = true
        private var isDraggingGlobe = false

        init(parent: GlobeSceneView) { self.parent = parent }

        func setIdleRotation(enabled: Bool) {
            idleRotationEnabled = enabled
            guard let node = globeNode else { return }
            node.removeAction(forKey: "idleRotation")
            guard enabled else { return }
            // アイドル回転（ゆっくり）
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
                
                // ★ 変更: 感度を下げて「回りすぎ」を防止 (0.008 -> 0.004)
                let sensitivity: CGFloat = 0.004
                node.runAction(SCNAction.rotateBy(x: 0, y: translation.x * sensitivity, z: 0, duration: 0.1))
                gesture.setTranslation(.zero, in: view)
                
            case .ended, .cancelled:
                guard isDraggingGlobe else { return }
                isDraggingGlobe = false
                
                let vX = gesture.velocity(in: view).x
                let absV = abs(vX)
                
                // ★ 変更: ガチャ発動のしきい値を上げて、誤発動を減らす (600 -> 1000)
                let minV: CGFloat = 1000
                
                if absV > minV {
                    let maxV: CGFloat = 2400
                    let direction: CGFloat = (vX >= 0) ? 1 : -1

                    let clampedV = max(minV, min(maxV, absV))
                    let t = (clampedV - minV) / (maxV - minV)

                    // ★ 変更: 回転数を抑えめにする (1.7~3.7回転 -> 1.2~2.7回転)
                    let turns = 1.2 + 1.5 * t
                    let baseAngle = CGFloat.pi * 2 * turns * direction
                    let boostedAngle = baseAngle * 1.5

                    let minDuration: TimeInterval = 0.9
                    let maxDuration: TimeInterval = 1.8
                    let duration = maxDuration - (maxDuration - minDuration) * TimeInterval(t)

                    DispatchQueue.main.async { self.parent.onSpin(duration) }

                    let spin = SCNAction.rotateBy(x: 0, y: boostedAngle, z: 0, duration: duration)
                    
                    // 自然な減速
                    spin.timingMode = .linear
                    spin.timingFunction = { t in
                        let x = 1 - t
                        return 1 - x * x * x * x
                    }
                    
                    node.runAction(spin) {
                        DispatchQueue.main.async { self.setIdleRotation(enabled: true) }
                    }
                } else {
                    // ★ 変更: 通常の慣性も弱めて、ピタッと止まりやすくする (0.002 -> 0.001)
                    let inertia = SCNAction.rotateBy(x: 0, y: vX * 0.001, z: 0, duration: 1.0)
                    inertia.timingMode = .easeOut
                    node.runAction(inertia) {
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
