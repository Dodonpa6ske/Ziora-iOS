import Foundation
import Combine
import UIKit

/// いいねした写真 1 件分（保存用）
/// UIImage は直接保存できないため除外しています
struct LikedPhoto: Identifiable, Hashable, Codable {
    let id: String
    let imagePath: String   // Storageのパス（サーバー用）
    
    // メタデータ
    let country: String
    let region: String
    let city: String
    let subLocality: String? // ★追加
    let dateText: String
    let latitude: Double?
    let longitude: Double?
    
    // ★ 追加: ローカル保存した画像のファイル名
    var localFileName: String {
        return "liked_\(id).jpg"
    }
}

/// いいね済み写真をアプリ全体で共有・保存するストア
final class LikedPhotoStore: ObservableObject {

    static let shared = LikedPhotoStore()

    @Published private(set) var photos: [LikedPhoto] = []
    
    private let userDefaultsKey = "saved_liked_photos"

    private init() {
        loadFromLocal()
    }

    // MARK: - 判定
    func isLiked(id: String) -> Bool {
        photos.contains { $0.id == id }
    }

    // MARK: - 追加 / 削除

    /// 画像データを受け取って保存する
    func add(photo: LikedPhoto, image: UIImage) {
        guard !isLiked(id: photo.id) else { return }
        
        // 1. 画像をローカル（ドキュメントフォルダ）に保存
        saveImageToDocuments(image: image, fileName: photo.localFileName)
        
        // 2. リストに追加して保存
        photos.append(photo)
        saveToUserDefaults()
    }

    func remove(id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let photo = photos[index]
        
        // 1. ローカル画像を削除
        removeImageFromDocuments(fileName: photo.localFileName)
        
        // 2. リストから削除して保存
        photos.remove(at: index)
        saveToUserDefaults()
    }

    // MARK: - 永続化ロジック (UserDefaults + FileManager)

    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadFromLocal() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedPhotos = try? JSONDecoder().decode([LikedPhoto].self, from: data) {
            self.photos = savedPhotos
        }
    }
    
    private func saveImageToDocuments(image: UIImage, fileName: String) {
        guard let data = image.jpegData(compressionQuality: 0.9),
              let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let fileURL = docURL.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
    }
    
    private func removeImageFromDocuments(fileName: String) {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = docURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    /// ローカルに保存された画像を読み込むヘルパー
    func loadLocalImage(for photo: LikedPhoto) -> UIImage? {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = docURL.appendingPathComponent(photo.localFileName)
        return UIImage(contentsOfFile: fileURL.path)
    }
}
