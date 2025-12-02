import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - ViewModel（ネイティブ広告の読み込み担当）

final class NativeAdViewModel: NSObject, ObservableObject, NativeAdLoaderDelegate {

    @Published var nativeAd: NativeAd?
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false

    private var adLoader: AdLoader?
    private let adUnitID: String

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        refreshAd()
    }

    func refreshAd() {
        isLoading = true
        loadFailed = false
        
        let request = Request()

        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(request)
    }

    // MARK: - NativeAdLoaderDelegate

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        DispatchQueue.main.async {
            self.nativeAd = nativeAd
            self.isLoading = false
            self.loadFailed = false
        }
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("Native ad failed: \(error)")
        DispatchQueue.main.async {
            self.isLoading = false
            self.loadFailed = true
        }
    }
}

// MARK: - カード内レイアウト専用 NativeAdView

final class CardNativeAdView: NativeAdView {

    private let adMediaView = MediaView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callButton = UIButton(type: .system)
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        clipsToBounds = true

        adMediaView.translatesAutoresizingMaskIntoConstraints = false
        adMediaView.clipsToBounds = true
        adMediaView.layer.cornerRadius = 20
        adMediaView.contentMode = .scaleAspectFill

        headlineLabel.numberOfLines = 2
        headlineLabel.font = .boldSystemFont(ofSize: 18)

        bodyLabel.numberOfLines = 2
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel

        callButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
        callButton.setTitleColor(.white, for: .normal)
        callButton.backgroundColor = UIColor.systemBlue
        callButton.layer.cornerRadius = 14
        callButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(adMediaView)
        stackView.addArrangedSubview(headlineLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(callButton)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -18),

            adMediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            adMediaView.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])

        mediaView = adMediaView
        headlineView = headlineLabel
        bodyView = bodyLabel
        callToActionView = callButton
    }

    func apply(nativeAd: NativeAd) {
        (headlineView as? UILabel)?.text = nativeAd.headline
        (bodyView as? UILabel)?.text = nativeAd.body
        (callToActionView as? UIButton)?
            .setTitle(nativeAd.callToAction, for: .normal)

        mediaView?.mediaContent = nativeAd.mediaContent
        self.nativeAd = nativeAd
    }
}

// MARK: - UIKit ラッパー（CardNativeAdView を SwiftUI で使う）

struct NativeAdViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: NativeAdViewModel

    func makeUIView(context: Context) -> CardNativeAdView {
        let adView = CardNativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        return adView
    }

    func updateUIView(_ uiView: CardNativeAdView, context: Context) {
        guard let nativeAd = viewModel.nativeAd else { return }
        uiView.apply(nativeAd: nativeAd)
    }
}

// MARK: - ネイティブ広告を 1 枚表示する SwiftUI ラッパー

struct NativeAdCardView: View {
    let adUnitID: String
    @StateObject private var viewModel: NativeAdViewModel

    init(adUnitID: String) {
        _viewModel = StateObject(wrappedValue: NativeAdViewModel(adUnitID: adUnitID))
        self.adUnitID = adUnitID
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                // ★ 読み込み中のプレースホルダー
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading ad...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadFailed || viewModel.nativeAd == nil {
                // ★ 読み込み失敗時のフォールバック（空白表示）
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Ad not available")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Tap to continue")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // ★ 広告正常表示
                NativeAdViewContainer(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transaction { t in
                        t.animation = nil
                    }
            }
        }
        .drawingGroup()
    }
}
