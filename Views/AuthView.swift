import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""

    var body: some View {
        ZStack {
            DesignSystem.Colors.parchment
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.xl) {
                // Logo
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "wind")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.ocean)

                    Text("Aeolian Note")
                        .font(DesignSystem.Fonts.elegant(size: 32))
                        .foregroundColor(DesignSystem.Colors.ink)

                    Text("Messages carried by the wind")
                        .font(DesignSystem.Fonts.body(size: 14))
                        .foregroundColor(DesignSystem.Colors.ink.opacity(0.6))
                }
                .padding(.top, 60)

                Spacer()

                // Form
                VStack(spacing: DesignSystem.Spacing.md) {
                    if isSignUp {
                        TextField("Display Name", text: $displayName)
                            .textFieldStyle(ParchmentTextFieldStyle())
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(ParchmentTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .textFieldStyle(ParchmentTextFieldStyle())
                        .textContentType(isSignUp ? .newPassword : .password)

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }

                    Button(action: submit) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isSignUp ? "Create Account" : "Sign In")
                                .font(DesignSystem.Fonts.elegant(size: 18))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DesignSystem.Colors.ocean)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                Button(action: { isSignUp.toggle() }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.ocean)
                }

                Spacer()
            }
        }
    }

    private func submit() {
        Task {
            if isSignUp {
                await authViewModel.signUp(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            } else {
                await authViewModel.signIn(email: email, password: password)
            }
        }
    }
}

struct ParchmentTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(DesignSystem.Colors.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignSystem.Colors.parchmentDark, lineWidth: 1)
            )
            .cornerRadius(8)
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
