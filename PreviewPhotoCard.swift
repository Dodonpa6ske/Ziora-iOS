import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Preview card (upload)

struct PreviewPhotoCard: View {
    let image: UIImage
    let country: String
    let region: String
    let city: String
    let dateText: String
    let isUploading: Bool
    let onDeleteLayer: (String) -> Void   // "country" / "region" / "city"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .frame(width: 350, height: 520)
                .shadow(radius: 16)

            VStack(spacing: 10) {
                // 画像
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 330, height: 410)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                // 位置情報 + 日付
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if !country.isEmpty {
                            DraggablePill(text: country, key: "country")
                        }
                        if !region.isEmpty {
                            DraggablePill(text: region, key: "region")
                        }
                        if !city.isEmpty {
                            DraggablePill(text: city, key: "city")
                        }
                        Spacer()
                    }

                    Text(dateText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 10)         // 写真との間隔 10pt
                .padding(.bottom, 10)
                .padding(.leading, 12)     // ← カード左端から 12pt
                .padding(.trailing, 18)

                Spacer(minLength: 0)
            }
            .frame(width: 350, height: 520, alignment: .top)

            // ゴミ箱（カードの内側、下端から 30pt 上）
            VStack {
                Spacer()
                TrashDropZone { key in
                    onDeleteLayer(key)
                }
                .padding(.bottom, 30)
            }
            .frame(width: 350, height: 520)

            if isUploading {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Color(hex: "6C6BFF"))
            }
        }
    }
}

// MARK: - Draggable pill

struct DraggablePill: View {
    let text: String
    let key: String

    var body: some View {
        Text(text)
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .onDrag {
                NSItemProvider(object: key as NSString)
            }
    }
}

// MARK: - Trash drop zone

struct TrashDropZone: View {
    let onDelete: (String) -> Void
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .frame(width: 52, height: 52)
                .shadow(radius: 4)

            Image(systemName: "trash.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.red)
        }
        .scaleEffect(isTargeted ? 1.1 : 1.0)
        .opacity(isTargeted ? 1.0 : 0.9)
        .onDrop(of: [UTType.plainText], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }

            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier,
                              options: nil) { item, _ in
                var key: String?

                if let data = item as? Data {
                    key = String(data: data, encoding: .utf8)
                } else if let str = item as? String {
                    key = str
                } else if let ns = item as? NSString {
                    key = ns as String
                }

                if let key = key {
                    DispatchQueue.main.async {
                        onDelete(key)
                    }
                }
            }
            return true
        }
    }
}
