import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContactView: View {
    @Binding var isPresented: Bool
    
    @State private var email: String = ""
    @State private var subject: String = ""
    @State private var message: String = ""
    
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    
    // カードの表示アニメーション用
    @State private var showCard = false
    
    // 管理者のメールアドレス
    private let adminEmail = "ziora.app.contact@gmail.com"
    
    // 自動入力を削除（初期値は空欄）

    // ★追加: ローカライズヘルパー
    @AppStorage("selectedLanguage") private var language: String = "en"
    private func localized(_ key: String) -> String {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        }
        return key
    }

    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
                .transition(.opacity)
            
            // カード本体
            if showCard {
                VStack(spacing: 0) {
                    
                    // ヘッダーアイコン
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "6C6BFF"))
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 12)
                    
                    // タイトル
                    Text(localized("Contact Us"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.bottom, 20)
                    
                    // 入力フォーム
                    VStack(spacing: 12) {
                        
                        // 1. Email (アイコン引数を削除)
                        CustomTextField(placeholder: localized("Your Email"), text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        // 2. 件名 (アイコン引数を削除)
                        CustomTextField(placeholder: localized("Subject"), text: $subject)
                        
                        // 3. メッセージ
                        ZStack(alignment: .topLeading) {
                            if message.isEmpty {
                                Text(localized("Your Message..."))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                            }
                            TextEditor(text: $message)
                                .frame(height: 100)
                                // TextField(padding=16)に合わせるため、内部inset(~5)を考慮して調整
                                .padding(.leading, 11)
                                .padding(.top, 8) // カーソルの高さをプレースホルダーに合わせるため調整
                                .padding(.trailing, 11)
                                .padding(.bottom, 4)
                                .font(.system(size: 15)) // 他のフィールドと同じフォントサイズにしてカーソルサイズも合わせる
                                .background(Color.clear)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.clear, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    
                    // 送信ボタン
                    Button(action: submitInquiry) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(localized("Send Message"))
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .background(isValid ? Color(hex: "6C6BFF") : Color.gray.opacity(0.5))
                    .cornerRadius(25)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .disabled(!isValid || isSubmitting)
                    
                    // 閉じるボタン
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
                .compositingGroup()
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                showCard = true
            }
        }
        .alert(localized("Thank You!"), isPresented: $showSuccessAlert) {
            Button(localized("OK")) { close() }
        } message: {
            Text(localized("Your message has been sent successfully."))
        }
        .alert(localized("Error"), isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            Button(localized("OK"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "") // error.localizedDescription is usually OS localized, leave as is or use localized prefix
        }
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
    
    private var isValid: Bool {
        !email.isEmpty && !subject.isEmpty && !message.isEmpty
    }
    
    private func submitInquiry() {
        guard isValid else { return }
        isSubmitting = true
        
        let db = Firestore.firestore()
        let batch = db.batch()
        
        let userId = Auth.auth().currentUser?.uid ?? "guest"
        let timestamp = FieldValue.serverTimestamp()
        
        // 1. 履歴保存
        let inquiryRef = db.collection("inquiries").document()
        let inquiryData: [String: Any] = [
            "userId": userId,
            "email": email,
            "subject": subject,
            "message": message,
            "createdAt": timestamp,
            "status": "unread",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "osVersion": UIDevice.current.systemVersion
        ]
        batch.setData(inquiryData, forDocument: inquiryRef)
        
        // 2. ユーザーへの自動返信 (Trigger Email)

        
        // 3. 管理者への通知 (Trigger Email)
        let adminMailRef = db.collection("mail").document()
        let adminMailData: [String: Any] = [
            "to": [adminEmail],
            "message": [
                "subject": "[Ziora Admin] New Inquiry: \(subject)",
                "text": """
                New inquiry from: \(email)
                User ID: \(userId)
                
                Message:
                \(message)
                """,
                "html": """
                <h2>New Inquiry</h2>
                <p><strong>From:</strong> \(email)</p>
                <p><strong>User ID:</strong> \(userId)</p>
                <p><strong>Subject:</strong> \(subject)</p>
                <hr>
                <p><strong>Message:</strong></p>
                <p>\(message)</p>
                """
            ]
        ]
        batch.setData(adminMailData, forDocument: adminMailRef)
        
        batch.commit { error in
            isSubmitting = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                showSuccessAlert = true
            }
        }
    }
}

// MARK: - Components

// ★修正: アイコンを削除し、シンプルなテキストフィールドに変更
struct CustomTextField: View {
    // icon プロパティを削除
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 15))
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
    }
}
