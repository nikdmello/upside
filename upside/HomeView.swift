import SwiftUI

struct HomeView: View {
    let userRole: UserRole
    @State private var isAnimated = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        UpsideLogo()
                            .scaleEffect(isAnimated ? 1.0 : 0.8)
                            .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimated)
                        
                        Text("You're in!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.4), value: isAnimated)
                        
                        Text(userRole == .creator ? 
                             "Start connecting with brands\nand grow your influence" :
                             "Discover creators who match\nyour brand perfectly"
                        )
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .opacity(isAnimated ? 1 : 0)
                            .offset(y: isAnimated ? 0 : 20)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: isAnimated)
                    }
                    
                    VStack(spacing: 20) {
                        FeatureCard(
                            icon: userRole == .creator ? "person.2.fill" : "magnifyingglass",
                            title: userRole == .creator ? "Find Brand Deals" : "Discover Creators",
                            description: userRole == .creator ? 
                                "Browse campaigns that match your audience" :
                                "Search creators by audience, location, and rates"
                        )
                        
                        FeatureCard(
                            icon: "doc.text.fill",
                            title: "Stay Compliant",
                            description: "All partnerships follow GCC regulations automatically"
                        )
                        
                        FeatureCard(
                            icon: "dollarsign.circle.fill",
                            title: userRole == .creator ? "Get Paid Fast" : "Secure Payments",
                            description: userRole == .creator ? 
                                "Receive payments within 24 hours of completion" :
                                "Protected payments with milestone tracking"
                        )
                    }
                    .opacity(isAnimated ? 1 : 0)
                    .offset(y: isAnimated ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.8), value: isAnimated)
                }
                .padding(.horizontal, 32)
                .padding(.top, 60)
                
                Spacer()
                
                Text("Full marketplace coming soon")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(isAnimated ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(1.2), value: isAnimated)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimated = true
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.upsideGreen)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

#Preview {
    HomeView(userRole: .creator)
}
