import SwiftUI
import GoogleMobileAds
import Combine
import UIKit

// MARK: - ViewModel

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
        isLoading   = true
        loadFailed  = false
        nativeAd    = nil

        print("🟦 [NativeAd] refreshAd() adUnitID = \(adUnitID)")

        let request = Request()
        let rootVC = UIApplication.topViewController()

        print("🟦 [NativeAd] rootVC = \(String(describing: rootVC))")

        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(request)
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        print("✅ [NativeAd] didReceive nativeAd")
        DispatchQueue.main.async {
            nativeAd.rootViewController = UIApplication.topViewController()
            self.nativeAd = nativeAd
            self.isLoading = false
            self.loadFailed = false
        }
    }

    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        print("ℹ️ [NativeAd] adLoaderDidFinishLoading (nativeAd is \(self.nativeAd == nil ? "nil" : "set"))")
        DispatchQueue.main.async {
            self.isLoading = false
            if self.nativeAd == nil {
                self.loadFailed = true
            }
        }
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        print("❌ [NativeAd] didFailToReceiveAdWithError: \(error.localizedDescription)")
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
    private let adLabel = UILabel()
    private let advertiserLabel = UILabel()

    private let stackView = UIStackView()
    private let topStackView = UIStackView()

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

            // --- Ad Label ---
            adLabel.text = "Ad"
            adLabel.font = .systemFont(ofSize: 10, weight: .bold)
            adLabel.textColor = .white
            adLabel.backgroundColor = .systemBlue
            adLabel.layer.cornerRadius = 4
            adLabel.layer.masksToBounds = true
            adLabel.textAlignment = .center
            
            // パディング (UILabelではカスタム実装が必要)
            let adLabelWrapper = UIView()
            adLabelWrapper.addSubview(adLabel)
            adLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                adLabel.topAnchor.constraint(equalTo: adLabelWrapper.topAnchor, constant: 2),
                adLabel.bottomAnchor.constraint(equalTo: adLabelWrapper.bottomAnchor, constant: -2),
                adLabel.leadingAnchor.constraint(equalTo: adLabelWrapper.leadingAnchor, constant: 4),
                adLabel.trailingAnchor.constraint(equalTo: adLabelWrapper.trailingAnchor, constant: -4),
                adLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20)
            ])
            
            // --- Advertiser Label ---
            advertiserLabel.numberOfLines = 1
            advertiserLabel.font = .systemFont(ofSize: 13)
            advertiserLabel.textColor = .secondaryLabel

            // --- Top Stack (Ad Label & Advertiser Label) ---
            topStackView.axis = .horizontal
            topStackView.spacing = 8
            topStackView.addArrangedSubview(adLabelWrapper)
            topStackView.addArrangedSubview(advertiserLabel)
            
            // --- Headline / Body ---
            headlineLabel.numberOfLines = 2
            headlineLabel.font = .boldSystemFont(ofSize: 18)

            bodyLabel.numberOfLines = 2
            bodyLabel.font = .systemFont(ofSize: 14)
            bodyLabel.textColor = .secondaryLabel

            // --- Call To Action Button ---
            callButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
            callButton.setTitleColor(.white, for: .normal)
            callButton.backgroundColor = UIColor.systemBlue
            callButton.layer.cornerRadius = 16
            // 'contentEdgeInsets' の警告が出ても、iOS15未満互換のためこのままでOK
            callButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            callButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

            // --- Media View ---
            adMediaView.translatesAutoresizingMaskIntoConstraints = false
            adMediaView.clipsToBounds = true
            adMediaView.layer.cornerRadius = 20
            adMediaView.contentMode = .scaleAspectFill
            adMediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true

            // --- Main Vertical Stack ---
            stackView.axis = .vertical
            stackView.spacing = 10
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            stackView.addArrangedSubview(topStackView)
            stackView.addArrangedSubview(adMediaView)
            stackView.addArrangedSubview(headlineLabel)
            stackView.addArrangedSubview(bodyLabel)
            stackView.setCustomSpacing(20, after: bodyLabel)
            stackView.addArrangedSubview(callButton)

            addSubview(stackView)

            // --- Constraints ---
            let contentPadding: CGFloat = 18
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: topAnchor, constant: contentPadding),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentPadding),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentPadding),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -contentPadding),
            ])

            // --- AdMob Views Mapping ---
            mediaView = adMediaView
            headlineView = headlineLabel
            bodyView = bodyLabel
            callToActionView = callButton
            advertiserView = advertiserLabel

            // ★★★ 修正箇所: AdChoicesView の初期化 ★★★
            // if let ではなく、そのまま let で初期化します
            let adChoicesView = AdChoicesView()
            
            adChoicesView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(adChoicesView)
            
            // 右上に固定配置
            NSLayoutConstraint.activate([
                adChoicesView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
                adChoicesView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            ])
            self.adChoicesView = adChoicesView
        }

    func apply(nativeAd: NativeAd) {
        (headlineView as? UILabel)?.text = nativeAd.headline
        (bodyView as? UILabel)?.text = nativeAd.body
        (callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)

        let advertiserText = nativeAd.advertiser ?? nativeAd.store
        (advertiserView as? UILabel)?.text = advertiserText
        advertiserView?.isHidden = (advertiserText?.isEmpty ?? true)

        mediaView?.mediaContent = nativeAd.mediaContent
        self.nativeAd = nativeAd
    }
}

// MARK: - UIKit ラッパー

struct NativeAdViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: NativeAdViewModel

    func makeUIView(context: Context) -> CardNativeAdView {
        let adView = CardNativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        return adView
    }

    func updateUIView(_ uiView: CardNativeAdView, context: Context) {
        if let ad = viewModel.nativeAd {
            uiView.apply(nativeAd: ad)
        }
    }
}

// MARK: - SwiftUI ラッパー

struct NativeAdCardView: View {
    let adUnitID: String
    @StateObject private var viewModel: NativeAdViewModel

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        _viewModel = StateObject(wrappedValue: NativeAdViewModel(adUnitID: adUnitID))
    }

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading ad...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.loadFailed || viewModel.nativeAd == nil {
                // フォールバック
                Image(systemName: "nosign")
                    .resizable()
                    .scaledToFit()
                    .padding(40)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NativeAdViewContainer(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transaction { t in t.animation = nil }
            }
        }
        .drawingGroup()
    }
}
