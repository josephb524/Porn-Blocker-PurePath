import SwiftUI

struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Get the unlimited access in the app")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "globe", text: "Block millions of porn sites in safari")
                FeatureRow(icon: "shield", text: "Safe web surfing")
                FeatureRow(icon: "gear", text: "Database customization")
            }
            .padding(.vertical)
            
            Text("$69.99/year")
                .font(.title3)
            
            Button(action: {
                isPurchasing = true
                Task {
                    do {
                        try await subManager.purchase()
                        if subManager.isSubscribed {
                            isPresented = false
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isPurchasing = false
                }
            }) {
                Text(isPurchasing ? "Processing..." : "START NOW")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
            }
            .disabled(isPurchasing)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Text("Payment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
            
            HStack {
                Button("Privacy Policy") {
                    // Navigate to privacy policy
                }
                Spacer()
                Button("Terms of use") {
                    // Navigate to terms
                }
            }
            .font(.caption)
        }
        .padding()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Later") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Restore") {
                    Task { 
                        await subManager.restore()
                        if subManager.isSubscribed {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
} 