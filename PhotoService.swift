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
    let dateText: String?      // 追加フィールド（ない古いデータも考えて Optional）
}

/// ガチャの範囲指定
enum GachaScope {
    case global
    case country(code: String)                  // 例: "JP"
    case region(code: String, region: String)   // 例: ("JP", "Osaka")
    case city(code: String, city: String)       // 例: ("JP", "Osaka")
}

// MARK: - PhotoService

final class PhotoService {

    static let shared = PhotoService()

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private init() {}

    struct UploadedPhotoMeta {
        let id: String
        let imagePath: String
    }

    enum UploadError: LocalizedError {
        case notSignedIn
        case couldNotEncodeJPEG

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You need to be signed in to upload."
            case .couldNotEncodeJPEG:
                return "Could not prepare image for upload."
            }
        }
    }

    // MARK: - Upload

    /// 位置情報付きで写真をアップロードし、Firestore にメタを保存
    ///
    /// - Parameters:
    ///   - image: 撮影した UIImage
    ///   - meta: 位置情報などのメタデータ
    func uploadPhoto(image: UIImage, meta: PhotoMeta) async throws -> UploadedPhotoMeta {
        // 1. ユーザー確認（匿名ログインでも OK）
        guard let user = Auth.auth().currentUser else {
            throw UploadError.notSignedIn
        }

        // 2. JPEG データに変換
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw UploadError.couldNotEncodeJPEG
        }

        // 3. Firestore のドキュメント参照を先に作る
        let docRef = db.collection("photos").document()
        let photoId = docRef.documentID

        // Storage パス: photos/{uid}/{photoId}.jpg
        let imagePath = "photos/\(user.uid)/\(photoId).jpg"
        let storageRef = storage.reference(withPath: imagePath)

        // 4. Storage にアップロード
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storageRef.putData(data, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        // 5. Firestore にメタデータ保存
        let now = FieldValue.serverTimestamp()
        let randomSeed = Double.random(in: 0..<1)

        var payload: [String: Any] = [
            "userId":      user.uid,
            "imagePath":   imagePath,
            "country":     meta.country,
            "region":      meta.region,
            "city":        meta.city,
            "createdAt":   now,
            "randomSeed":  randomSeed,
            "status":      "active",
            "likeCount":   0,
            "dateText":    meta.dateText   // 文字列としてそのまま保存
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

        try await docRef.setData(payload)

        return UploadedPhotoMeta(id: photoId, imagePath: imagePath)
    }

    /// 旧バージョン互換用：位置情報なしアップロード
    /// HomeView 側が完全に新しい meta を渡すようになったら不要になる想定
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
            return nil
        }

        let data = doc.data()

        let likeCount = data["likeCount"] as? Int ?? 0

        let photo = PhotoDocument(
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
            likeCount: likeCount,          // ★ 追加
            dateText: data["dateText"] as? String
        )

        return photo
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
            // seed 以上
            q = q.start(at: [seed])
        case .backward:
            // 0〜seed の中から
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

    /// Firestore の imagePath から UIImage を取得
    func downloadImage(imagePath: String) async throws -> UIImage {
        let ref = storage.reference(withPath: imagePath)
        let maxSize: Int64 = 10 * 1024 * 1024

        let data = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Data, Error>) in
            ref.getData(maxSize: maxSize) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "PhotoService",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No data"]
                        )
                    )
                }
            }
        }

        guard let image = UIImage(data: data) else {
            throw NSError(
                domain: "PhotoService",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid image data"]
            )
        }
        return image
    }

     // MARK: - Fetch my photos (for sent list)

    func fetchMyPhotos() async throws -> [PhotoDocument] {
        guard let user = Auth.auth().currentUser else {
            throw UploadError.notSignedIn
        }

        let query = db.collection("photos")
            .whereField("userId", isEqualTo: user.uid)
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)

        let snapshot = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<QuerySnapshot, Error>) in
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
            else {
                return nil
            }

            let countryCode = data["countryCode"] as? String
            let latitude    = data["latitude"]    as? Double
            let longitude   = data["longitude"]   as? Double
            let createdAt   = data["createdAt"]   as? Timestamp
            let dateText    = data["dateText"]    as? String

            // ★ ここを追加（フィールドが無い古いデータは 0 にする）
            let likeCount   = data["likeCount"]   as? Int ?? 0

            return PhotoDocument(
                id: doc.documentID,
                userId: userId,
                imagePath: imagePath,
                country: country,
                region: region,
                city: city,
                countryCode: countryCode,
                latitude: latitude,
                longitude: longitude,
                createdAt: createdAt,
                randomSeed: randomSeed,
                status: status,
                likeCount: likeCount,   // ★ ここ追加
                dateText: dateText
            )
        }

        return photos
    }

     // MARK: - Delete photo (cancel sending)

    func deletePhoto(documentId: String, imagePath: String) async throws {
        // Firestore のドキュメント削除
        let docRef = db.collection("photos").document(documentId)
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            docRef.delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        // Storage 上の実ファイル削除
        let ref = storage.reference(withPath: imagePath)
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            ref.delete { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    } // ← PhotoService クラスはこの 1 個だけで閉じる
