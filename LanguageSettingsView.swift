import SwiftUI

struct LanguageSettingsView: View {
    // 選択中の言語（UserDefaultsと連動）
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = "en"
    @Environment(\.dismiss) private var dismiss

    // 言語リスト (LanguageSelectionViewと共通の構造体を使用)
    // Assetsに含まれている国旗の画像名に合わせています
    private let languages: [LanguageOption] = [
        .init(code: "en",      label: "English",    flagAssetName: "flag_us"),
        .init(code: "ja",      label: "日本語",       flagAssetName: "flag_jp"),
        .init(code: "es",      label: "Español",    flagAssetName: "flag_es"),
        .init(code: "fr",      label: "Français",   flagAssetName: "flag_fr"),
        .init(code: "ko",      label: "한국어",       flagAssetName: "flag_kr"),
        .init(code: "zh",      label: "中文",         flagAssetName: "flag_cn"),
        .init(code: "ru",      label: "Русский",      flagAssetName: "flag_ru")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(languages) { language in
                    Button {
                        selectedLanguageCode = language.code
                        // チェックマークを見せてから少し遅らせて閉じる
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            dismiss()
                        }
                    } label: {
                        HStack {
                            // 国旗
                            Image(language.flagAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .cornerRadius(2)
                                .shadow(color: .black.opacity(0.1), radius: 1)
                            
                            // 言語名
                            Text(language.label)
                                .foregroundColor(.primary)
                                .font(.system(size: 16))
                            
                            Spacer()
                            
                            // 選択中のチェックマーク
                            if selectedLanguageCode == language.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle()) // 行全体をタップ可能に
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
