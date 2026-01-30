import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions
import CoreLocation

// MARK: - Firestore モデル

struct PhotoMeta {
    let country: String
    let region: String
    let city: String
    let subLocality: String? // ★追加
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
    let dateText: String
}

struct PhotoDocument {
    let id: String
    let userId: String
    let imagePath: String
    let country: String
    let region: String
    let city: String
    let subLocality: String? // ★追加
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Timestamp?
    let expireAt: Timestamp?
    let randomSeed: Double
    let status: String
    let likeCount: Int
    let impressionCount: Int // ★追加
    let dateText: String?
}

enum GachaScope {
    case global
    case country(code: String)
    case region(code: String, region: String)
    case city(code: String, city: String)
}

enum LocationField: String {
    case country
    case region
    case city
}

// MARK: - PhotoService

final class PhotoService {

    static let shared = PhotoService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {}

    struct UploadedPhotoMeta {
        let id: String
        let imagePath: String
    }

    enum ZioraError: LocalizedError {
        case notSignedIn
        case offline
        case imageProcessingFailed
        case noData
        case serverError(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Please sign in to continue."
            case .offline: return "No internet connection."
            case .imageProcessingFailed: return "Failed to process the image."
            case .noData: return "Content not found."
            case .serverError(let msg): return "Server Error: \(msg)"
            case .unknown: return "An unknown error occurred."
            }
        }
    }

    // MARK: - Upload
    func uploadPhoto(image: UIImage, meta: PhotoMeta) async throws -> UploadedPhotoMeta {
        guard NetworkMonitor.shared.isConnected else { throw ZioraError.offline }
        
        let blockedCountryCodes = RemoteConfigManager.shared.blockedCountryCodes
        if let code = meta.countryCode, blockedCountryCodes.contains(code.uppercased()) {
            throw ZioraError.serverError("Service is not available in your region (\(code)).")
        }
        
        guard let user = Auth.auth().currentUser else { throw ZioraError.notSignedIn }
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw ZioraError.imageProcessingFailed }

        let docRef = db.collection("photos").document()
        let photoId = docRef.documentID
        let imagePath = "photos/\(user.uid)/\(photoId).jpg"
        let storageRef = storage.reference(withPath: imagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(data, metadata: metadata)
        } catch {
            throw ZioraError.serverError("Failed to upload image: \(error.localizedDescription)")
        }

        let now = FieldValue.serverTimestamp()
        let expireDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let expireTimestamp = Timestamp(date: expireDate)
        let randomSeed = Double.random(in: 0..<1)

        var payload: [String: Any] = [
            "userId":      user.uid,
            "imagePath":   imagePath,
            "country":     meta.country,
            "region":      meta.region,
            "city":        meta.city,
            "createdAt":   now,
            "expireAt":    expireTimestamp,
            "randomSeed":  randomSeed,
            "status":      "active",
            "likeCount":   0,
            "impressionCount": 0, // ★追加: 初期値0
            "dateText":    meta.dateText
        ]
        if let sub = meta.subLocality { payload["subLocality"] = sub } // ★追加
        if let code = meta.countryCode { payload["countryCode"] = code }
        if let lat = meta.latitude { payload["latitude"] = lat }
        if let lng = meta.longitude { payload["longitude"] = lng }

        try await docRef.setData(payload)
        return UploadedPhotoMeta(id: photoId, imagePath: imagePath)
    }

    func uploadPhoto(image: UIImage) async throws -> UploadedPhotoMeta {
        let dummy = PhotoMeta(country: "Unknown", region: "Unknown", city: "Unknown", subLocality: nil, countryCode: nil, latitude: nil, longitude: nil, dateText: "")
        return try await uploadPhoto(image: image, meta: dummy)
    }

    // MARK: - Fetch

    private func documentToPhoto(_ doc: DocumentSnapshot) -> PhotoDocument? {
        guard let data = doc.data() else { return nil }
        guard
            let userId      = data["userId"]      as? String,
            let imagePath   = data["imagePath"]   as? String,
            let country     = data["country"]     as? String,
            let region      = data["region"]      as? String,
            let city        = data["city"]        as? String,
            let randomSeed  = data["randomSeed"]  as? Double,
            let status      = data["status"]      as? String
        else { return nil }

        let subLocality = data["subLocality"] as? String // ★追加
        let countryCode = data["countryCode"] as? String
        let latitude    = data["latitude"]    as? Double
        let longitude   = data["longitude"]   as? Double
        let createdAt   = data["createdAt"]   as? Timestamp
        let expireAt    = data["expireAt"]    as? Timestamp
        let dateText    = data["dateText"]    as? String
        let likeCount   = data["likeCount"]   as? Int ?? 0
        let impressionCount = data["impressionCount"] as? Int ?? 0 // ★追加


        return PhotoDocument(
            id: doc.documentID, userId: userId, imagePath: imagePath,
            country: country, region: region, city: city, subLocality: subLocality, // ★追加
            countryCode: countryCode, latitude: latitude, longitude: longitude,
            createdAt: createdAt, expireAt: expireAt,
            randomSeed: randomSeed, status: status,
            likeCount: likeCount, impressionCount: impressionCount, // ★追加
            dateText: dateText
        )
    }

    func fetchRandomPhoto(scope: GachaScope, excludedUserId: String?, excludedPhotoIds: Set<String>, retryCount: Int = 0) async throws -> PhotoDocument? {
        guard NetworkMonitor.shared.isConnected else { throw ZioraError.offline }
        var query: Query = db.collection("photos").whereField("status", isEqualTo: "active")

        switch scope {
        case .global: break
        case .country(let code): query = query.whereField("countryCode", isEqualTo: code)
        case .region(let code, let region): query = query.whereField("countryCode", isEqualTo: code).whereField("region", isEqualTo: region)
        case .city(let code, let city): query = query.whereField("countryCode", isEqualTo: code).whereField("city", isEqualTo: city)
        }
        
        // 除外リストにあるIDのドキュメントをクライアント側で弾くために、少し多めに取得する
        // Firestoreは "not-in" クエリに制限がある（最大10個など）ため、
        // ランダムな位置からN件取得して、その中から条件に合うものを探す方式をとる。
        
        let seed = Double.random(in: 0..<1)
        let batchSize = 10
        
        func fetchBatch(direction: Bool) async throws -> PhotoDocument? {
            var q = query.order(by: "randomSeed")
            if direction { q = q.start(at: [seed]) } else { q = q.end(before: [seed]) }
            
            let snap = try await q.limit(to: batchSize).getDocuments()
            
            for doc in snap.documents {
                // 変換
                guard let photo = documentToPhoto(doc) else { continue }
                
                // 1. 自分の写真を除外
                if let currentUserId = excludedUserId, photo.userId == currentUserId {
                    continue
                }
                
                // 2. 既読写真を除外
                if excludedPhotoIds.contains(photo.id) {
                    continue
                }
                
                // ブロックユーザーの除外はここでは簡易的に（本来はここでもチェックすべきだが今回は省略、必要なら追加）
                
                return photo
            }
            return nil
        }

        if let doc = try await fetchBatch(direction: true) { return doc }
        if let doc = try await fetchBatch(direction: false) { return doc }
        
        // ★修正: 再取得ロジック (空振り防止)
        // フィルタリングですべて弾かれてしまった場合、シード値を変えて再試行する
        if retryCount < 3 {
             print("♻️ Gacha retrying... (\(retryCount + 1)/3)")
             // 少し待っても良いが、UX的には即時リトライで良い
             return try await fetchRandomPhoto(scope: scope, excludedUserId: excludedUserId, excludedPhotoIds: excludedPhotoIds, retryCount: retryCount + 1)
        }
        
        return nil
    }

    // ★追加: リセット後の新着写真優先取得
    func fetchPriorityPhotos(after date: Date, excludedUserId: String?, excludedPhotoIds: Set<String>, limit: Int = 50) async throws -> [PhotoDocument] {
        guard NetworkMonitor.shared.isConnected else { return [] }
        
        let timestamp = Timestamp(date: date)
        
        let query = db.collection("photos")
            .whereField("status", isEqualTo: "active")
            .whereField("createdAt", isGreaterThan: timestamp)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            
        let snapshot = try await query.getDocuments()
        
        // クライアントサイドフィルタリング
        return snapshot.documents.compactMap { doc -> PhotoDocument? in
            guard let photo = documentToPhoto(doc) else { return nil }
            
            // 1. 自分の除外
            if let currentUserId = excludedUserId, photo.userId == currentUserId { return nil }
            
            // 2. 既読の除外
            if excludedPhotoIds.contains(photo.id) { return nil }
            
            return photo
        }
    }

    func fetchMyPhotos(limit: Int = 20, lastSnapshot: DocumentSnapshot? = nil) async throws -> (photos: [PhotoDocument], lastSnapshot: DocumentSnapshot?) {
        guard let user = Auth.auth().currentUser else { throw ZioraError.notSignedIn }

        var query = db.collection("photos")
            .whereField("userId", isEqualTo: user.uid)
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        do {
            let snapshot = try await query.getDocuments()
            let photos = snapshot.documents.compactMap { documentToPhoto($0) }
            return (photos, snapshot.documents.last)
        } catch {
            throw ZioraError.serverError(error.localizedDescription)
        }
    }
    
    func fetchLatestPhoto() async throws -> PhotoDocument? {
        // オフラインでもキャッシュがあるかもしれないが、基本はオンライン想定
        guard NetworkMonitor.shared.isConnected else { return nil }
        
        let query = db.collection("photos")
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            
        let snapshot = try await query.getDocuments()
        guard let doc = snapshot.documents.first else { return nil }
        return documentToPhoto(doc)
    }
    
    // ★追加: ID指定で写真を取得（通知からのディープリンク用）
    func fetchPhoto(photoId: String) async throws -> PhotoDocument? {
        let doc = try await db.collection("photos").document(photoId).getDocument()
        if !doc.exists { return nil }
        return documentToPhoto(doc) // QueryDocumentSnapshotではなくDocumentSnapshotを受け取れるよう修正が必要かも？
    }

    // MARK: - Actions

    func downloadImage(imagePath: String) async throws -> UIImage {
        if let cached = imageCache.object(forKey: imagePath as NSString) { return cached }
        guard NetworkMonitor.shared.isConnected else { throw ZioraError.offline }
        let ref = storage.reference(withPath: imagePath)
        
        let data = try await ref.data(maxSize: 10 * 1024 * 1024)
        guard let image = UIImage(data: data) else { throw ZioraError.imageProcessingFailed }
        imageCache.setObject(image, forKey: imagePath as NSString)
        return image
    }
    
    func downloadThumbnail(originalPath: String) async throws -> UIImage {
        let thumbPath: String
        if let dotRange = originalPath.range(of: ".", options: .backwards) {
            let base = originalPath[..<dotRange.lowerBound]
            let ext = originalPath[dotRange.lowerBound...]
            thumbPath = "\(base)_200x200\(ext)"
        } else {
            thumbPath = originalPath + "_200x200"
        }

        if let cached = imageCache.object(forKey: thumbPath as NSString) { return cached }
        guard NetworkMonitor.shared.isConnected else { throw ZioraError.offline }

        do {
            let data = try await storage.reference(withPath: thumbPath).data(maxSize: 1 * 1024 * 1024)
            if let image = UIImage(data: data) {
                imageCache.setObject(image, forKey: thumbPath as NSString)
                return image
            } else {
                throw ZioraError.imageProcessingFailed
            }
        } catch {
            print("Thumbnail fallback to original: \(thumbPath)")
            return try await downloadImage(imagePath: originalPath)
        }
    }

    func deletePhoto(documentId: String, imagePath: String) async throws {
        try await db.collection("photos").document(documentId).delete()
        try await storage.reference(withPath: imagePath).delete()
    }
    

    
    // ★追加: 編集内容で位置情報をまとめて更新
    // ★追加: 編集内容で位置情報をまとめて更新
    func updateLocationData(photoId: String, country: String, region: String, city: String, subLocality: String?) async throws {
        // フィールドが空なら削除扱い、値があれば更新
        // ※ここでは削除された項目は空文字で上書きする想定
        var data: [String: Any] = [
            "country": country,
            "region": region,
            "city": city
        ]
        // 警告回避: 明示的にStringとして扱う
        if let sub = subLocality {
            data["subLocality"] = sub
        } else {
            data["subLocality"] = ""
        }
        
        try await db.collection("photos").document(photoId).updateData(data)
    }

    // MARK: - Social & Safety

    func saveFCMToken(_ token: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid).setData([
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // ★追加: 言語保存（通知のローカライズ用）
    func saveUserLanguage(_ languageCode: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid).setData([
            "language": languageCode,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // ★修正: いいね送信時に国コードも保存
    func sendLike(photoId: String, countryName: String, countryCode: String?, targetUserId: String) async {
        guard let user = Auth.auth().currentUser else { return }
        
        // IDが空の場合も処理しない（クラッシュ防止）
        print("❤️ sendLike called: photoId=\(photoId), target=\(targetUserId), me=\(user.uid), countryCode=\(countryCode ?? "nil")")
        
        if user.uid == targetUserId || targetUserId.isEmpty {
            print("⚠️ sendLike skipped: Self-like (\(user.uid == targetUserId)) or Empty ID (\(targetUserId.isEmpty))")
            return
        }
        
        let photoRef = db.collection("photos").document(photoId)
        let likeRef = photoRef.collection("likes").document(user.uid)
        
        do {
            // 1. いいね情報の保存
            try await likeRef.setData([
                "likerId": user.uid,
                "likerCountry": countryName,
                "likerCountryCode": countryCode ?? "", // ★追加
                "createdAt": FieldValue.serverTimestamp()
            ])
            
            // 2. カウントアップ
            try await photoRef.updateData(["likeCount": FieldValue.increment(Int64(1))])
            
            // 3. 相手への通知作成
            let notificationData: [String: Any] = [
                "type": "like",
                "fromUserId": user.uid,
                "fromCountry": countryName,
                "likerCountryCode": countryCode ?? "", // ★追加 (Cloud Functionsで使う)
                "photoId": photoId,
                "createdAt": FieldValue.serverTimestamp(),
                "read": false
            ]
            
            try await db.collection("users").document(targetUserId).collection("notifications").addDocument(data: notificationData)
            
        } catch { print("Like failed: \(error)") }
    }

    // ★追加: いいね取り消し (Firestoreから削除)
    func removeLike(photoId: String) async {
        guard let user = Auth.auth().currentUser else { return }
        
        // 自分自身へのいいね取り消しなどのチェックは不要（ドキュメントがなければエラーになるだけか、無視される）
        let photoRef = db.collection("photos").document(photoId)
        let likeRef = photoRef.collection("likes").document(user.uid)
        
        do {
            // 1. いいねドキュメントの削除
            try await likeRef.delete()
            
            // 2. カウントダウン
            try await photoRef.updateData(["likeCount": FieldValue.increment(Int64(-1))])
            
            print("💔 removeLike success: \(photoId)")
        } catch {
            print("removeLike failed: \(error)")
        }
    }

    func validateExistence(ids: [String]) async -> [String] {
        var existing: [String] = []
        await withTaskGroup(of: String?.self) { group in
            for id in ids {
                group.addTask {
                    if let snap = try? await self.db.collection("photos").document(id).getDocument(), snap.exists {
                        return id
                    }
                    return nil
                }
            }
            for await id in group { if let id = id { existing.append(id) } }
        }
        return existing
    }
    
    func reportPhoto(photoId: String, reason: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db.collection("reports").addDocument(data: [
            "photoId": photoId, "reporterId": user.uid, "reason": reason, "createdAt": FieldValue.serverTimestamp(), "status": "pending"
        ])
    }
    
    func blockUser(blockedUserId: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db.collection("users").document(user.uid).collection("blocked_users").document(blockedUserId).setData([
            "blockedUserId": blockedUserId, "createdAt": FieldValue.serverTimestamp()
        ])
    }

    
    // MARK: - Location Localization
    func localizeLocation(latitude: Double, longitude: Double) async -> (country: String?, region: String?, city: String?, subLocality: String?) {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        let languageCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        // CLGeocoderが言語設定を確実に反映するように、地域コード付きのLocaleを作成する
        let identifier: String
        switch languageCode {
        case "ja": identifier = "ja_JP"
        case "ko": identifier = "ko_KR"
        case "zh": identifier = "zh_CN"
        case "fr": identifier = "fr_FR"
        case "es": identifier = "es_ES"
        default: identifier = languageCode
        }
        let locale = Locale(identifier: identifier)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: locale)
            guard let p = placemarks.first else { return (nil, nil, nil, nil) }
            
            let isoCode = p.isoCountryCode ?? ""
            let country = p.country ?? (isoCode.isEmpty ? "Country" : isoCode)
            
            let adminArea = p.administrativeArea ?? ""
            let region = adminArea.isEmpty ? "State" : adminArea
            
            let locality = p.locality ?? ""
            let subLocality = p.subLocality ?? ""
            
            let city = locality.isEmpty ? "City" : locality
            let sub = subLocality.isEmpty ? nil : subLocality
            
            return (country, region, city, sub)
        } catch {
            print("Localization Error: \(error)")
            return (nil, nil, nil, nil)
        }
    }
}
