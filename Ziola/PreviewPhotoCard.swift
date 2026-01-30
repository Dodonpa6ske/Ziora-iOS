import SwiftUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Preview card (upload)

struct PreviewPhotoCard: View {
    let image: UIImage
    let country: String
    let region: String
    let city: String
    let subLocality: String? // ★追加
    let dateText: String
    let isUploading: Bool
    let onDeleteLayer: (String) -> Void   // "country" / "region" / "city" / "subLocality"

    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18),
                        radius: 18, x: 0, y: 10)

            VStack(spacing: 0) {
                // 1. 画像エリア
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    // GachaResultCard同様に固定幅を指定して揺れを防ぐ
                    .frame(width: UIScreen.main.bounds.width - 48 - 20)
                    .frame(maxHeight: .infinity)
                    .clipped()
                    .cornerRadius(20)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                // 2. 下部情報エリア (左揃え)
                VStack(alignment: .leading, spacing: 12) {
                    
                    // 上段: 位置情報タグ (アイコン + スクロール)
                    // ★修正: 位置情報が一切ない場合は行ごと非表示（許可されていない場合など）
                    let hasLocation = !city.isEmpty || !country.isEmpty || !region.isEmpty || (subLocality != nil && !subLocality!.isEmpty)
                    
                    if hasLocation {
                        HStack(spacing: 8) {
                            // Icon removed
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    if let sub = subLocality, !sub.isEmpty {
                                         LocationTagPill(text: sub, key: "subLocality", onDelete: onDeleteLayer)
                                    }
                                    if !city.isEmpty {
                                        LocationTagPill(text: city, key: "city", onDelete: onDeleteLayer)
                                    }
                                    if !region.isEmpty && region != city {
                                        LocationTagPill(text: region, key: "region", onDelete: onDeleteLayer)
                                    }
                                    if !country.isEmpty {
                                        LocationTagPill(text: country, key: "country", onDelete: onDeleteLayer)
                                    }
                                }
                            }
                            // フェードマスク処理
                            .mask(
                                HStack(spacing: 0) {
                                    Rectangle().fill(Color.black)
                                    LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .leading, endPoint: .trailing).frame(width: 16)
                                }
                            )
                        }
                    }
                    
                    // 下段: 撮影日時 (左揃え)
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary) // グレー
                            .font(.system(size: 14))
                            .frame(width: 20) // 上のピンアイコンと幅を合わせる
                        
                        Text(dateText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer() // 右側を空けて左詰めにする
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 20) // 全体の横余白
                .padding(.bottom, 24)     // 下部の余白
            }
            
            // アップロード中の表示
            if isUploading {
                ZStack {
                    Color.white.opacity(0.6)
                    .cornerRadius(28)
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(Color(hex: "6C6BFF"))
                }
            }
        }
        // 横幅は親ビューで制限することを想定 -> 内部で固定する方針に変更
        .frame(width: UIScreen.main.bounds.width - 48)
        .frame(height: 520)
    }
}

// MARK: - Location Tag Pill (Menu対応版)

struct LocationTagPill: View {
    let text: String
    let key: String
    let onDelete: (String) -> Void

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .contextMenu {
                Button(role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    withAnimation {
                        onDelete(key)
                    }
                } label: {
                    Label("Remove Location", systemImage: "trash")
                }
            }
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
    }
}
