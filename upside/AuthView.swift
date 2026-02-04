import SwiftUI
import AuthenticationServices

struct AuthView: View {
    let userRole: UserRole
    let onAuthComplete: () -> Void
    @State private var isAnimated = false
    @State private var showEmailAuth = false
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("Create your\naccount")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : -20)
                        .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimated)
                    
                    Text("Join as a \(userRole.displayName.lowercased()) and start connecting")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(isAnimated ? 1 : 0)
                        .offset(y: isAnimated ? 0 : -20)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)
                }
                .padding(.top, 80)
                
                Spacer()
                
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    let userID = appleIDCredential.user
                                    let email = appleIDCredential.email ?? ""
                                    let fullName = appleIDCredential.fullName
                                    let name = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
                                    
                                    authManager.user = User(id: userID, email: email, name: name.isEmpty ? "Apple User" : name)
                                    authManager.isAuthenticated = true
                                }
                            case .failure(let error):
                                print("Apple Sign In failed: \(error)")
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(28)
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                    
                    GoogleSignInButton(
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            authManager.signInWithGoogle()
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: isAnimated)
                    
                    AuthButton(
                        title: "Continue with Email",
                        icon: "envelope.fill",
                        backgroundColor: Color.white.opacity(0.1),
                        foregroundColor: .white,
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showEmailAuth = true
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(1.0), value: isAnimated)
                    
                    #if DEBUG
                    AuthButton(
                        title: "Demo Login",
                        icon: "hammer.fill",
                        backgroundColor: Color.purple.opacity(0.2),
                        foregroundColor: .purple,
                        onTap: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            authManager.signInDemo()
                        }
                    )
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(1.2), value: isAnimated)
                    #endif
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimated = true
        }
        .onChange(of: authManager.isAuthenticated) { authenticated in
            if authenticated {
                onAuthComplete()
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView(onAuthComplete: {
                showEmailAuth = false
                onAuthComplete()
            })
        }
    }
}

struct GoogleSignInButton: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Continue with Google")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(28)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct AuthButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .cornerRadius(28)
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    AuthView(userRole: .creator, onAuthComplete: {})
}