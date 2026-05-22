import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }

                Section {
                    Button {
                        isSubmitting = true
                        message = "Shared login wiring pending"
                        isSubmitting = false
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Login")
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSubmitting)
                }

                if let message {
                    Section {
                        Text(message)
                    }
                }
            }
            .navigationTitle("Han1meViewer")
        }
    }
}
