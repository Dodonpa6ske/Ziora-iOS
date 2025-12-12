import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var email: String = ""
    @State private var message: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var errorMessage: String?
    
    // ログイン中の場合、メアドを自動入力
    init() {
        if let user = Auth.auth().currentUser, let userEmail = user.email {
            _email = State(initialValue: userEmail)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("We appreciate your feedback and reports. Please fill out the form below.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                
                Section(header: Text("Email Address")) {
                    TextField("your@email.com", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Message")) {
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Describe your issue or feedback...")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                    }
                }
                
                Section {
                    Button(action: submitInquiry) {
                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Send Message")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.bold)
                                .foregroundColor(isValid ? .blue : .gray)
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Thank You!", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your message has been sent successfully.")
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var isValid: Bool {
        !email.isEmpty && !message.isEmpty
    }
    
    private func submitInquiry() {
        guard isValid else { return }
        isSubmitting = true
        
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "userId": Auth.auth().currentUser?.uid ?? "guest",
            "email": email,
            "message": message,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "unread",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "osVersion": UIDevice.current.systemVersion
        ]
        
        db.collection("inquiries").addDocument(data: data) { error in
            isSubmitting = false
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                showSuccessAlert = true
            }
        }
    }
}
