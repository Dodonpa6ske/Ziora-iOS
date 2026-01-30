import SwiftUI

struct LanguageSettingsView: View {
    // 選択中の言語（UserDefaultsと連動）
    @AppStorage("selectedLanguage") private var selectedLanguageCode: String = "en"
    
    // 呼び出し元からバインディングする表示フラグ
    @Binding var isPresented: Bool
    
    // Assetsに含まれている国旗の画像名に合わせています
    private let languages: [LanguageOption] = [
        .init(code: "en",      label: "English",    flagAssetName: "flag_us"),
        .init(code: "ja",      label: "日本語",       flagAssetName: "flag_jp"),
        .init(code: "es",      label: "Español",    flagAssetName: "flag_es"),
        .init(code: "fr",      label: "Français",   flagAssetName: "flag_fr"),
        .init(code: "ko",      label: "한국어",       flagAssetName: "flag_kr")
    ]
    
    // カードアニメーション用
    @State private var showCard = false
    
    var body: some View {
        ZStack {
            // 背景（タップで閉じる）
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { close() }
                .transition(.opacity)
            
            // カード本体
            if showCard {
                cardContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: selectedLanguageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // --- ヘッダーアイコン ---
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)
                
                Image(systemName: "globe")
                    .font(.system(size: 32))
                    .foregroundColor(Color(hex: "6C6BFF"))
            }
            .padding(.top, 32)
            .padding(.bottom, 16)
            
            // --- タイトル ---
            Text(localized("Language"))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.bottom, 24)
            
            // --- 言語リスト ---
            VStack(spacing: 0) {
                ForEach(languages) { language in
                    languageRow(for: language)
                    
                    // 区切り線（最後以外）
                    if language.id != languages.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            // --- 閉じるボタン ---
            Button(localized("Cancel")) {
                close()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(32)
        .padding(.horizontal, 24)
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 12)
    }
    
    private func languageRow(for language: LanguageOption) -> some View {
        Button {
            selectedLanguageCode = language.code
            // 遅延させて閉じる（選択した感を出すため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                close()
            }
        } label: {
            HStack(spacing: 16) {
                // 国旗
                Image(language.flagAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .cornerRadius(2)
                    .shadow(color: .black.opacity(0.1), radius: 1)
                
                // 言語名
                Text(language.label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 選択中チェックマーク
                if selectedLanguageCode == language.code {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "6C6BFF"))
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(Color.gray.opacity(0.3))
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func close() {
        withAnimation(.easeIn(duration: 0.2)) {
            showCard = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                isPresented = false
            }
        }
    }
}
