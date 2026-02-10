import SwiftUI

struct ChatStubView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Chat")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Messaging is coming soon.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Button(action: onClose) {
                    Text("Close")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.upsideGreen)
                        .cornerRadius(26)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
    }
}

#Preview {
    ChatStubView(onClose: {})
}
