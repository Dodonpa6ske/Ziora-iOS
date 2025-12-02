import Foundation
import Combine
import UIKit   // UIImage を使う

/// いいねした写真 1 件分
struct LikedPhoto: Identifiable, Hashable {
    let id: String          // Firestore の docId など一意な文字列
    let image: UIImage      // 一覧表示用の画像
    let imagePath: String   // Storage のパス

    let country: String
    let region: String
    let city: String
    let dateText: String
    let latitude: Double?
    let longitude: Double?
}

/// いいね済み写真をアプリ全体で共有するストア
final class LikedPhotoStore: ObservableObject {

    static let shared = LikedPhotoStore()

    /// いいね済みの写真一覧
    @Published private(set) var photos: [LikedPhoto] = []

    private init() {}

    // MARK: - 判定

    func isLiked(id: String) -> Bool {
        photos.contains { $0.id == id }
    }

    // MARK: - 追加 / 削除

    func add(_ photo: LikedPhoto) {
        guard !isLiked(id: photo.id) else { return }
        photos.append(photo)
    }

    func remove(id: String) {
        photos.removeAll { $0.id == id }
    }

    /// isLiked の値に合わせて add / remove するヘルパ
    func setLiked(_ liked: Bool, photo: LikedPhoto) {
        if liked {
            add(photo)
        } else {
            remove(id: photo.id)
        }
    }
}
