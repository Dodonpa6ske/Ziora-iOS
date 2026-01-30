import SwiftUI
import GoogleMobileAds
import Combine
import UIKit

// MARK: - ViewModel

final class NativeAdViewModel: NSObject, ObservableObject, NativeAdLoaderDelegate {

    @Published var nativeAd: NativeAd?
    @Published var isLoading: Bool = true
    @Published var loadFailed: Bool = false
    
    var isReady: Bool {
        return nativeAd != nil
    }

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

// MARK: - カード内レイアウト専用 NativeAdView
// Explicitly inherit from NativeAdView (SDK Swift alias) to ensure proper AdMob handling
final class CardNativeAdView: NativeAdView {

    private let adLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let starRatingLabel = UILabel() // New
    private let adMediaView = MediaView()
    private let iconImageView = UIImageView() // New
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let callButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .white // ★修正: 背景を白に
        layer.cornerRadius = 28 // GachaResultCardに合わせる
        layer.masksToBounds = true
        
        // --- Ad Label (Required) ---
        adLabel.text = NSLocalizedString("Ad", comment: "Ad label")
        adLabel.font = .systemFont(ofSize: 11, weight: .bold)
        adLabel.textColor = .white
        adLabel.backgroundColor = .systemOrange // Distinct color
        adLabel.layer.cornerRadius = 3
        adLabel.layer.masksToBounds = true
        adLabel.textAlignment = .center
        adLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Advertiser Label ---
        advertiserLabel.numberOfLines = 1
        advertiserLabel.font = .systemFont(ofSize: 13, weight: .regular)
        advertiserLabel.textColor = .secondaryLabel
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Star Rating Label ---
        starRatingLabel.font = .systemFont(ofSize: 12, weight: .bold)
        starRatingLabel.textColor = .systemOrange
        starRatingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Icon View ---
        iconImageView.layer.cornerRadius = 12 // 少し丸く
        iconImageView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.backgroundColor = .systemGray6
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Media View ---
        adMediaView.clipsToBounds = true
        // adMediaView.layer.cornerRadius = 12 // メディアは上部全面表示にするため角丸解除（親Viewで切る）
        adMediaView.contentMode = .scaleAspectFill
        adMediaView.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Headline ---
        headlineLabel.numberOfLines = 2
        headlineLabel.font = .boldSystemFont(ofSize: 17) // 少し大きく
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Body ---
        bodyLabel.numberOfLines = 2
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // --- Call Button ---
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.background.cornerRadius = 24 // 丸みを強く
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .boldSystemFont(ofSize: 15)
            return outgoing
        }
        callButton.configuration = config
        callButton.translatesAutoresizingMaskIntoConstraints = false
        
        // --- AdChoices View (Required) ---
        // ★修正: AdChoicesは右上に配置
        let adChoicesView = AdChoicesView()
        adChoicesView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add Subviews
        // 順序を変更: AdChoicesなどが隠れないように (z-index管理)
        addSubview(adLabel)
        addSubview(adChoicesView)
        // MediaViewはHeaderの下に来るので順序はそこまで重要ではないが、明示的に
        addSubview(adMediaView)
        
        // Bottom Area
        addSubview(iconImageView)
        addSubview(headlineLabel)
        addSubview(starRatingLabel)
        addSubview(advertiserLabel)
        addSubview(bodyLabel)
        addSubview(callButton)
        
        // --- Constraints ---
        NSLayoutConstraint.activate([
            // 1. Header Area (Ad Label & AdChoices)
            // Stacked vertically on the left
            
            // Ad Label (Top Left)
            adLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            adLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            adLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
            adLabel.heightAnchor.constraint(equalToConstant: 16),
            
            // AdChoices (Below Ad Label, Left Aligned)
            adChoicesView.topAnchor.constraint(equalTo: adLabel.bottomAnchor, constant: 8),
            adChoicesView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            adChoicesView.widthAnchor.constraint(equalToConstant: 24),
            adChoicesView.heightAnchor.constraint(equalToConstant: 24),
            
            // 2. Footer Area (Bottom-Up Layout to maximize MediaView)
            
            // Call Button (Pinned to Bottom)
            callButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            callButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            callButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            callButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Body (Above Button)
            bodyLabel.bottomAnchor.constraint(equalTo: callButton.topAnchor, constant: -16),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Icon (Above Body)
            iconImageView.bottomAnchor.constraint(equalTo: bodyLabel.topAnchor, constant: -12),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56),
            
            // Info Row (Relative to Icon)
            // Headline
            headlineLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            headlineLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            headlineLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Star + Advertiser
            starRatingLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            starRatingLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            
            advertiserLabel.centerYAnchor.constraint(equalTo: starRatingLabel.centerYAnchor),
            advertiserLabel.leadingAnchor.constraint(equalTo: starRatingLabel.trailingAnchor, constant: 8),
            advertiserLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),

            // 3. Media View (Fills remaining space)
            // Top: Below AdChoices (Header)
            adMediaView.topAnchor.constraint(equalTo: adChoicesView.bottomAnchor, constant: 8),
            // Bottom: Above Icon (Footer)
            adMediaView.bottomAnchor.constraint(equalTo: iconImageView.topAnchor, constant: -16),
            // Sides
            adMediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            adMediaView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        
        // --- AdMob Mapping ---
        mediaView = adMediaView
        headlineView = headlineLabel
        bodyView = bodyLabel
        callToActionView = callButton
        iconView = iconImageView
        advertiserView = advertiserLabel
        starRatingView = starRatingLabel
        self.adChoicesView = adChoicesView
    }
    


    override func layoutSubviews() {
        super.layoutSubviews()
    }

    func apply(nativeAd: NativeAd) {
        (headlineView as? UILabel)?.text = nativeAd.headline
        (bodyView as? UILabel)?.text = nativeAd.body
        (callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        
        // Icon
        if let icon = nativeAd.icon {
            (iconView as? UIImageView)?.image = icon.image
            iconView?.isHidden = false
        } else {
            iconView?.isHidden = true
        }

        // Stars
        if let starRating = nativeAd.starRating {
            // ★★★★☆ (Example)
            let rating = starRating.doubleValue
            let stars = String(repeating: "★", count: Int(rating))
            (starRatingView as? UILabel)?.text = "\(stars)"
            starRatingView?.isHidden = false
        } else {
            starRatingView?.isHidden = true
        }

        let advertiserText = nativeAd.advertiser ?? nativeAd.store
        (advertiserView as? UILabel)?.text = advertiserText
        advertiserView?.isHidden = (advertiserText?.isEmpty ?? true)

        mediaView?.mediaContent = nativeAd.mediaContent
        
        // Always register the ad
        self.nativeAd = nativeAd
        print("✅ [NativeAd] Registered nativeAd to view") 
    }
}

// MARK: - UIKit ラッパー

struct NativeAdViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: NativeAdViewModel

    func makeUIView(context: Context) -> CardNativeAdView {
        let adView = CardNativeAdView()
        // Enable frame-based layout to strictly follow SwiftUI's frame (520pt)
        adView.translatesAutoresizingMaskIntoConstraints = true 
        adView.clipsToBounds = true
        adView.layer.cornerRadius = 28
        adView.layer.cornerCurve = .continuous
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
    @ObservedObject var viewModel: NativeAdViewModel

    init(viewModel: NativeAdViewModel) {
        self.viewModel = viewModel
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the card (520pt)
                    .transaction { t in t.animation = nil }
            }
        }
        .clipped()
        // Native Ads cannot be in a drawingGroup as they are UIKit views that need to be in the hierarchy
        // .drawingGroup() was causing 0 impressions
    }
}
