import SwiftUI
import UserNotifications

struct NotificationPermissionSheet: View {
    @Binding var isPresented: Bool
    @State private var currentNotificationIndex = 0
    @State private var isAnimating = false
    let userRole: UserRole
    let onComplete: () -> Void
    
    var notifications: [NotificationModel] {
        switch userRole {
        case .creator:
            return [
                NotificationModel(
                    title: "New Match Alert",
                    body: "You have a new match with Nike! Check out their campaign details.",
                    time: "now"
                ),
                NotificationModel(
                    title: "Match Update",
                    body: "Your collaboration with Adidas has been approved. Time to create!",
                    time: "now"
                ),
                NotificationModel(
                    title: "Profile Views",
                    body: "Your profile views increased by 47% this week. You're trending!",
                    time: "now"
                ),
                NotificationModel(
                    title: "Action Required",
                    body: "Complete your license verification to unlock premium matches.",
                    time: "now"
                )
            ]
        case .brand:
            return [
                NotificationModel(
                    title: "New Creator Match",
                    body: "Joshua (@jxshdxniells) matched with your LGBTQ campaign.",
                    time: "now"
                ),
                NotificationModel(
                    title: "Campaign Update",
                    body: "Your summer collection campaign received 5 new applications today.",
                    time: "now"
                ),
                NotificationModel(
                    title: "Performance Alert",
                    body: "Your active campaigns are performing 23% above industry average.",
                    time: "now"
                ),
                NotificationModel(
                    title: "Payment Reminder",
                    body: "Invoice for collaboration with @mikefitness is ready for approval.",
                    time: "now"
                )
            ]
        }
    }
    
    var benefits: [(icon: String, text: String)] {
        switch userRole {
        case .creator:
            return [
                ("bell.badge.fill", "Stay informed about match statuses"),
                ("exclamationmark.triangle.fill", "Get alerted if you're missing info"),
                ("chart.line.uptrend.xyaxis", "Receive performance updates")
            ]
        case .brand:
            return [
                ("person.2.fill", "Get notified when creators apply"),
                ("chart.bar.fill", "Track campaign performance metrics"),
                ("dollarsign.circle.fill", "Receive payment and invoice alerts")
            ]
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 12)
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Text("Stay Updated")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Get notified about important updates on your matches")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 16) {
                            ZStack {
                                NotificationCard(notification: notifications[currentNotificationIndex])
                                    .id(currentNotificationIndex)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            }
                            .frame(height: 100)
                            .clipped()
                            .onAppear {
                                startNotificationCarousel()
                            }
                        }
                        
                        VStack(spacing: 12) {
                            ForEach(Array(benefits.enumerated()), id: \.offset) { _, benefit in
                                BenefitRow(
                                    icon: benefit.icon,
                                    text: benefit.text
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 40)
                    }
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        requestNotificationPermission()
                    }) {
                        Text("Enable Notifications")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [Color.white, Color.gray.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(28)
                            .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        isPresented = false
                        onComplete()
                    }) {
                        Text("Not now")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
    
    private func startNotificationCarousel() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.6)) {
                currentNotificationIndex = (currentNotificationIndex + 1) % notifications.count
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                print("Notification permission granted: \(granted)")
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                isPresented = false
                onComplete()
            }
        }
    }
}

struct NotificationCard: View {
    let notification: NotificationModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Text("U")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Upside")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(notification.time)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Text(notification.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(notification.body)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.purple)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
    }
}

struct NotificationModel {
    let title: String
    let body: String
    let time: String
}

#Preview {
    NotificationPermissionSheet(
        isPresented: .constant(true),
        userRole: .creator,
        onComplete: {}
    )
}
