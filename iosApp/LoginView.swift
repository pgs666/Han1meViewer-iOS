import SwiftUI
import Han1meShared

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @StateObject private var viewModel: LoginViewModel

    init(authFeature: AuthFeature) {
        _viewModel = StateObject(wrappedValue: LoginViewModel(authFeature: authFeature))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                }

                Section {
                    Button {
                        viewModel.login(email: email, password: password)
                    } label: {
                        if case .submitting = viewModel.state {
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
                            .foregroundColor(messageColor)
                    }
                }
            }
            .navigationTitle("Han1meViewer")
        }
        .navigationViewStyle(.stack)
    }

    private var isSubmitting: Bool {
        if case .submitting = viewModel.state {
            return true
        }
        return false
    }

    private var message: String? {
        switch viewModel.state {
        case .idle, .submitting:
            return nil
        case .succeeded(let message), .failed(let message):
            return message
        }
    }

    private var messageColor: Color {
        if case .succeeded = viewModel.state {
            return .green
        }
        return .primary
    }
}
