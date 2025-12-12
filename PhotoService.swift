import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import CoreLocation

// MARK: - Firestore モデル

/// Firestore に保存するメタ情報
struct PhotoMeta {
    let country: String
    let region: String
    let city: String
    let countryCode: String?   // "JP" など
    let latitude: Double?
    let longitude: Double?
    let dateText: String       // UI 表示用の撮影日時文字列
}

/// Firestore から読み出すとき用のモデル
struct PhotoDocument {
    let id: String
    let userId: String
    let imagePath: String
    let country: String
    let region: String
    let city: String
    let countryCode: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Timestamp?
    let randomSeed: Double
    let status: String
    let likeCount: Int
    let dateText: String?      // 追加フィールド
}

/// ガチャの範囲指定
enum GachaScope {
    case global
    case country(code: String)
    case region(code: String, region: String)
    case city(code: String, city: String)
}

// MARK: - PhotoService

final class PhotoService {

    static let shared = PhotoService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // 画像キャッシュ
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {}

    struct UploadedPhotoMeta {
        let id: String
        let imagePath: String
    }

    // ★追加: アプリ独自のエラー定義
    enum ZioraError: LocalizedError {
        case notSignedIn
        case offline
        case imageProcessingFailed
        case noData
        case serverError(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "Please sign in to continue."
            case .offline:
                return "No internet connection. Please check your network settings."
            case .imageProcessingFailed:
                return "Failed to process the image."
            case .noData:
                return "Content not found."
            case .serverError(let msg):
                return "Server Error: \(msg)"
            case .unknown:
                return "An unknown error occurred."
            }
        }
    }

    // MARK: - Upload

    /// 位置情報付きで写真をアップロードし、Firestore にメタを保存
    func uploadPhoto(image: UIImage, meta: PhotoMeta) async throws -> UploadedPhotoMeta {
        // ★追加: ネットワークチェック
        guard NetworkMonitor.shared.isConnected else {
            throw ZioraError.offline
        }
        
        // ★追加: 禁止地域チェック (ユーザー保護とリスク回避のため)
        // CN:中国, KP:北朝鮮, RU:ロシア, SY:シリア, IR:イラン, CU:キューバ
        // 地図のズレ(中国)や、法的・経済的リスク(その他)を回避するためにブロックします
        let blockedCountryCodes = ["CN", "KP", "RU", "SY", "IR", "CU"]
        if let code = meta.countryCode, blockedCountryCodes.contains(code.uppercased()) {
            throw ZioraError.serverError("Service is not available in your region (\(code)).")
        }
        
        // 1. ユーザー確認
        guard let user = Auth.auth().currentUser else {
            throw ZioraError.notSignedIn
        }

        // 2. JPEG データに変換
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw ZioraError.imageProcessingFailed
        }

        // 3. Firestore のドキュメント参照を先に作る
        let docRef = db.collection("photos").document()
        let photoId = docRef.documentID

        // Storage パス: photos/{uid}/{photoId}.jpg
        let imagePath = "photos/\(user.uid)/\(photoId).jpg"
        let storageRef = storage.reference(withPath: imagePath)

        // 4. Storage にアップロード (エラーハンドリング追加)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                storageRef.putData(data, metadata: metadata) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            throw ZioraError.serverError("Failed to upload image: \(error.localizedDescription)")
        }

        // 5. Firestore にメタデータ保存 (エラーハンドリング追加)
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
            "dateText":    meta.dateText
        ]

        if let code = meta.countryCode {
            payload["countryCode"] = code
        }
        if let lat = meta.latitude {
            payload["latitude"] = lat
        }
        if let lng = meta.longitude {
            payload["longitude"] = lng
        }

        do {
            try await docRef.setData(payload)
        } catch {
            throw ZioraError.serverError("Failed to save metadata: \(error.localizedDescription)")
        }

        return UploadedPhotoMeta(id: photoId, imagePath: imagePath)
    }

    /// 旧バージョン互換用：位置情報なしアップロード
    func uploadPhoto(image: UIImage) async throws -> UploadedPhotoMeta {
        let dummy = PhotoMeta(
            country: "Unknown",
            region: "Unknown",
            city: "Unknown",
            countryCode: nil,
            latitude: nil,
            longitude: nil,
            dateText: ""
        )
        return try await uploadPhoto(image: image, meta: dummy)
    }

    // MARK: - Gacha (Random fetch)

    /// ランダムに 1 枚写真を取得（世界 or エリア別）
    func fetchRandomPhoto(scope: GachaScope) async throws -> PhotoDocument? {
        // ★追加: ネットワークチェック
        guard NetworkMonitor.shared.isConnected else {
            throw ZioraError.offline
        }

        var query: Query = db.collection("photos")
            .whereField("status", isEqualTo: "active")

        // エリア別フィルター
        switch scope {
        case .global:
            break
        case .country(let code):
            query = query.whereField("countryCode", isEqualTo: code)
        case .region(let code, let region):
            query = query
                .whereField("countryCode", isEqualTo: code)
                .whereField("region", isEqualTo: region)
        case .city(let code, let city):
            query = query
                .whereField("countryCode", isEqualTo: code)
                .whereField("city", isEqualTo: city)
        }

        // ランダムな起点
        let seed = Double.random(in: 0..<1)

        // エラーをキャッチして ZioraError に変換
        do {
            // まず「seed 以上」から 1 件
            var snapshot = try await getRandomSnapshot(
                baseQuery: query,
                seed: seed,
                searchDirection: .forward
            )

            // 足りなければ「seed 未満」から
            if snapshot?.documents.isEmpty ?? true {
                snapshot = try await getRandomSnapshot(
                    baseQuery: query,
                    seed: seed,
                    searchDirection: .backward
                )
            }

            guard
                let doc = snapshot?.documents.first,
                let randomSeed = doc.data()["randomSeed"] as? Double
            else {
                return nil // 写真が0枚の場合はエラーではなくnil
            }

            let data = doc.data()
            let likeCount = data["likeCount"] as? Int ?? 0

            return PhotoDocument(
                id: doc.documentID,
                userId: data["userId"] as? String ?? "",
                imagePath: data["imagePath"] as? String ?? "",
                country: data["country"] as? String ?? "",
                region: data["region"] as? String ?? "",
                city: data["city"] as? String ?? "",
                countryCode: data["countryCode"] as? String,
                latitude: data["latitude"] as? Double,
                longitude: data["longitude"] as? Double,
                createdAt: data["createdAt"] as? Timestamp,
                randomSeed: randomSeed,
                status: data["status"] as? String ?? "active",
                likeCount: likeCount,
                dateText: data["dateText"] as? String
            )
        } catch {
            throw ZioraError.serverError(error.localizedDescription)
        }
    }

    private enum RandomSearchDirection {
        case forward
        case backward
    }

    /// randomSeed を使って前後どちらかから 1 件取る
    private func getRandomSnapshot(
        baseQuery: Query,
        seed: Double,
        searchDirection: RandomSearchDirection
    ) async throws -> QuerySnapshot? {

        var q = baseQuery.order(by: "randomSeed")

        switch searchDirection {
        case .forward:
            q = q.start(at: [seed])
        case .backward:
            q = q.end(before: [seed])
        }

        q = q.limit(to: 1)

        let snapshot = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<QuerySnapshot?, Error>) in
            q.getDocuments { snap, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snap)
                }
            }
        }

        return snapshot
    }

    // MARK: - Storage から画像を取る

    /// Firestore の imagePath から UIImage を取得 (キャッシュ対応)
    func downloadImage(imagePath: String) async throws -> UIImage {
        // 1. キャッシュチェック
        if let cached = imageCache.object(forKey: imagePath as NSString) {
            return cached
        }
        
        // 2. ★追加: ネットワークチェック（キャッシュがない場合のみ）
        guard NetworkMonitor.shared.isConnected else {
            throw ZioraError.offline
        }

        let ref = storage.reference(withPath: imagePath)
        let maxSize: Int64 = 10 * 1024 * 1024

        do {
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                ref.getData(maxSize: maxSize) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PhotoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                    }
                }
            }
            
            guard let image = UIImage(data: data) else {
                throw ZioraError.imageProcessingFailed
            }
            
            // 3. キャッシュ保存
            imageCache.setObject(image, forKey: imagePath as NSString)
            
            return image
            
        } catch {
            throw ZioraError.serverError("Image download failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Thumbnail Download

    /// サムネイル画像（200x200）をダウンロードする (キャッシュ対応)
    func downloadThumbnail(originalPath: String) async throws -> UIImage {
        let thumbPath: String
        if let dotRange = originalPath.range(of: ".", options: .backwards) {
            let base = originalPath[..<dotRange.lowerBound]
            let ext = originalPath[dotRange.lowerBound...]
            thumbPath = "\(base)_200x200\(ext)"
        } else {
            thumbPath = originalPath + "_200x200"
        }

        // 1. キャッシュチェック
        if let cached = imageCache.object(forKey: thumbPath as NSString) {
            return cached
        }
        
        // 2. ★追加: ネットワークチェック
        guard NetworkMonitor.shared.isConnected else {
            // オフライン時はフォールバックせずエラーにする（オリジナルを取りに行っても失敗するため）
            throw ZioraError.offline
        }

        let ref = storage.reference(withPath: thumbPath)
        let maxSize: Int64 = 1 * 1024 * 1024

        do {
            let data = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                ref.getData(maxSize: maxSize) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let data = data {
                        continuation.resume(returning: data)
                    } else {
                        continuation.resume(throwing: NSError(domain: "PhotoService", code: -1, userInfo: nil))
                    }
                }
            }
            
            if let image = UIImage(data: data) {
                // 3. キャッシュ保存
                imageCache.setObject(image, forKey: thumbPath as NSString)
                return image
            } else {
                throw ZioraError.imageProcessingFailed
            }
        } catch {
            print("Thumbnail not found, falling back to original: \(thumbPath)")
            return try await downloadImage(imagePath: originalPath)
        }
    }
    
    // MARK: - Fetch my photos (Pagination)

    func fetchMyPhotos(limit: Int = 20, lastSnapshot: DocumentSnapshot? = nil) async throws -> (photos: [PhotoDocument], lastSnapshot: DocumentSnapshot?) {
        guard let user = Auth.auth().currentUser else {
            throw ZioraError.notSignedIn
        }

        var query = db.collection("photos")
            .whereField("userId", isEqualTo: user.uid)
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        
        if let lastSnapshot = lastSnapshot {
            query = query.start(afterDocument: lastSnapshot)
        }

        // Firestoreのクエリはオフラインキャッシュが効くため、厳密なネットワークチェックは行わず
        // 取得エラーのみをキャッチして ZioraError にラップします
        do {
            let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
                query.getDocuments { snap, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let snap = snap {
                        continuation.resume(returning: snap)
                    }
                }
            }

            let photos = snapshot.documents.compactMap { doc -> PhotoDocument? in
                let data = doc.data()
                guard
                    let userId      = data["userId"]      as? String,
                    let imagePath   = data["imagePath"]   as? String,
                    let country     = data["country"]     as? String,
                    let region      = data["region"]      as? String,
                    let city        = data["city"]        as? String,
                    let randomSeed  = data["randomSeed"]  as? Double,
                    let status      = data["status"]      as? String
                else { return nil }

                let countryCode = data["countryCode"] as? String
                let latitude    = data["latitude"]    as? Double
                let longitude   = data["longitude"]   as? Double
                let createdAt   = data["createdAt"]   as? Timestamp
                let dateText    = data["dateText"]    as? String
                let likeCount   = data["likeCount"]   as? Int ?? 0

                return PhotoDocument(
                    id: doc.documentID, userId: userId, imagePath: imagePath,
                    country: country, region: region, city: city,
                    countryCode: countryCode, latitude: latitude, longitude: longitude,
                    createdAt: createdAt, randomSeed: randomSeed, status: status,
                    likeCount: likeCount, dateText: dateText
                )
            }

            return (photos, snapshot.documents.last)
            
        } catch {
            throw ZioraError.serverError(error.localizedDescription)
        }
    }

    // MARK: - Delete photo (cancel sending)

    func deletePhoto(documentId: String, imagePath: String) async throws {
        // Firestore削除
        let docRef = db.collection("photos").document(documentId)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            docRef.delete { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }

        // Storage削除
        let ref = storage.reference(withPath: imagePath)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    // MARK: - Notification Support

    func saveFCMToken(_ token: String) {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("users").document(user.uid).setData([
            "fcmToken": token,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func sendLike(photoId: String) async {
        guard let user = Auth.auth().currentUser else { return }
        
        let likeRef = db.collection("photos").document(photoId)
                        .collection("likes").document(user.uid)
        
        do {
            try await likeRef.setData([
                "likerId": user.uid,
                "createdAt": FieldValue.serverTimestamp()
            ])
            try await db.collection("photos").document(photoId).updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("Failed to send like: \(error)")
        }
    }

    // MARK: - Validation

    func validateExistence(ids: [String]) async -> [String] {
        var existingIds: [String] = []
        
        await withTaskGroup(of: String?.self) { group in
            for id in ids {
                group.addTask {
                    let docRef = self.db.collection("photos").document(id)
                    do {
                        // キャッシュではなくサーバーに問い合わせて削除を確認する
                        let snap = try await docRef.getDocument(source: .server)
                        return snap.exists ? id : nil
                    } catch {
                        // オフラインやエラー時は勝手に消さないように「存在する」扱いとして返す
                        return id
                    }
                }
            }
            
            for await id in group {
                if let id = id { existingIds.append(id) }
            }
        }
        return existingIds
    }
    
    // MARK: - Report & Block

    func reportPhoto(photoId: String, reason: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        
        let reportData: [String: Any] = [
            "photoId": photoId,
            "reporterId": user.uid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending"
        ]
        
        try await db.collection("reports").addDocument(data: reportData)
    }
    
    func blockUser(blockedUserId: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        
        let blockData: [String: Any] = [
            "blockedUserId": blockedUserId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(user.uid)
            .collection("blocked_users").document(blockedUserId).setData(blockData)
    }

} // ← クラスの閉じカッコ
