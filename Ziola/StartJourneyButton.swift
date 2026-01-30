import SwiftUI

struct StartJourneyButton: View {
    var onComplete: () -> Void

    @State private var isPressing = false
    @State private var progress: CGFloat = 0.0
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    @State private var particleTimer: Timer?
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    private let requiredDuration: TimeInterval = 1.5 // 長押し必要時間

    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }
    
    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var angle: Double
        var speed: Double
        var scale: CGFloat
        var opacity: Double
    }
    
    var body: some View {
        ZStack {
            // 背景の円形プログレス (オプション) or ボタン自体のエフェクト
            
            // 本体ボタン
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                
                // プログレス表示 (背景色を変えるなど)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "908FF7")) // Ziola Color or similar
                        .frame(width: geo.size.width * progress)
                        .opacity(progress > 0 ? 1 : 0)
                }
                .mask(RoundedRectangle(cornerRadius: 16))
                
                // ラベル
                HStack(spacing: 8) {
                    if progress >= 1.0 {
                        Image(systemName: "checkmark")
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text(progress >= 1.0 ? localized("Ready") : (isPressing ? localized("Hold") : localized("Start_Journey")))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }
            .frame(height: 56)
            .scaleEffect(isPressing ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
            
            // パーティクルレイヤー
            ForEach(particles) { particle in
                Image(systemName: "star.fill")
                    .foregroundColor(Color(hex: "FFD700")) // Gold stars
                    .font(.system(size: 10))
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(
                        x: particle.position.x,
                        y: particle.position.y
                    )
            }
        }
        .frame(maxWidth: .infinity)
        // タップ/長押し制御
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing {
                        startPress()
                    }
                }
                .onEnded { _ in
                    endPress()
                }
        )
    }
    
    private func startPress() {
        guard progress < 1.0 else { return }
        isPressing = true
        
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.prepare()
        
        // プログレスタイマー
        let startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let newProgress = CGFloat(min(elapsed / requiredDuration, 1.0))
            
            self.progress = newProgress
            
            // 完了判定
            if newProgress >= 1.0 {
                completePress()
            } else {
                // 押し下げ中の微弱ハプティクス (間引いて実行)
                if Int(elapsed * 100) % 10 == 0 {
                   feedback.impactOccurred(intensity: 0.5)
                }
            }
        }
        
        // パーティクル発生タイマー
        particleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            emitParticle()
        }
    }
    
    private func endPress() {
        isPressing = false
        timer?.invalidate()
        particleTimer?.invalidate()
        
        if progress < 1.0 {
            // 未完了ならリセット
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 0.0
                particles.removeAll()
            }
        }
    }
    
    private func completePress() {
        endPress() // タイマー停止
        progress = 1.0
        
        // 成功ハプティクス
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // 大量のパーティクル放出
        for _ in 0..<20 { emitParticle(burst: true) }
        
        // 少し待ってから遷移実行
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete()
        }
    }
    
    private func emitParticle(burst: Bool = false) {
        // 修正: GeometryReaderを使わないと正確なWidthが取れないが、
        // 簡易的に乱数で散らす。
        
        let startX: CGFloat = CGFloat.random(in: 100...200) // ボタンの適当な幅
        let startY: CGFloat = 28
        
        let angle = Double.random(in: 0...(2 * .pi))
        
        let newParticle = Particle(
            position: CGPoint(x: startX, y: startY), // 出現位置
            angle: angle,
            speed: Double.random(in: 2...5),
            scale: CGFloat.random(in: 0.5...1.2),
            opacity: 1.0
        )
        
        particles.append(newParticle)
        
        // アニメーション (SwiftUIのアニメーションシステムには乗りにくいので、
        // 本来はTimelineViewやCanvasを使うのがベストだが、ここでは簡易的にViewModifier遷移で実装するか、
        // あるいはonAppearでanimateさせる)
        
        // 簡易実装として、配列に追加した瞬間にView側でtransition/animationさせる手法をとるため、
        // updateループは回さない。
        // しかし、座標を動かすにはState更新が必要。
        // ここでは「出現して消える」だけの単純なエフェクトにする。
    }
}

// 改善版: 個別のパーティクルViewが自律的に動き回るスタイル
struct StarParticleView: View {
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        Image(systemName: "star.fill")
            .foregroundColor(Color(hex: "FFD700"))
            .font(.system(size: 10))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    let angle = Double.random(in: -Double.pi...0) // 上方向中心
                    let distance = CGFloat.random(in: 40...80)
                    offset = CGSize(
                        width: cos(angle) * distance,
                        height: sin(angle) * distance
                    )
                    opacity = 0
                    scale = 0.1
                }
            }
    }
}

// 最終的な置き換え用コンポーネント（上記試作を統合）
struct LongPressStartButton: View {
    var onComplete: () -> Void

    @State private var isPressing = false
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?
    @State private var starID = 0
    // 表示するパーティクルのIDリスト
    @State private var activeStars: [Int] = []
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "en"

    private let requiredDuration: TimeInterval = 1.5

    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: "", comment: "")
        }
        return key
    }
    
    var body: some View {
        ZStack {
            // パーティクル (ボタンの背後に配置して飛び出させる)
            ForEach(activeStars, id: \.self) { _ in
                StarParticleView()
            }
            
            // ボタン本体
            ZStack(alignment: .leading) {
                // ガラスモーフィズム背景
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )

                // プログレスバー背景 (押すと伸びる)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                }
                .mask(RoundedRectangle(cornerRadius: 28))

                // テキスト
                HStack(spacing: 12) {
                    Spacer()
                    Image(systemName: isPressing ? "hand.tap.fill" : "arrow.right")
                        .font(.system(size: 18, weight: .semibold))
                        .scaleEffect(isPressing ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3), value: isPressing)

                    Text(progress >= 1.0 ? localized("Lets_Go") : (isPressing ? localized("Hold_to_Start") : localized("Start_Journey")))
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .foregroundColor(progress > 0.3 ? .black : .white)
                .animation(.easeInOut(duration: 0.2), value: progress)
            }
            .frame(height: 56)
            .scaleEffect(isPressing ? 0.98 : 1.0)
            .shadow(
                color: Color.white.opacity(isPressing ? 0.4 : 0.2),
                radius: isPressing ? 20 : 12,
                x: 0,
                y: isPressing ? 8 : 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressing)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing { startPress() }
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private func startPress() {
        guard progress < 1.0 else { return }
        isPressing = true
        
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()
        
        let startTime = Date()
        // プログレスタイマー
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(startTime)
            let newProgress = CGFloat(min(elapsed / requiredDuration, 1.0))
            self.progress = newProgress
            
            // パーティクル発生 (確率で)
            if Int(elapsed * 100) % 5 == 0 {
                addStar()
                feedback.impactOccurred(intensity: 0.4) // 軽い振動
            }
            
            if newProgress >= 1.0 {
                completePress()
            }
        }
    }
    
    private func endPress() {
        // 完了していなければリセット
        if progress < 1.0 {
            isPressing = false
            timer?.invalidate()
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 0.0
            }
        }
    }
    
    private func completePress() {
        timer?.invalidate()
        progress = 1.0
        
        // 成功フィードバック
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // 完了エフェクト（バースト）
        for _ in 0..<10 { addStar() }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
    
    private func addStar() {
        let id = starID
        starID += 1
        activeStars.append(id)
        
        // 一定時間後に削除してメモリ管理
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            activeStars.removeAll { $0 == id }
        }
    }
}
