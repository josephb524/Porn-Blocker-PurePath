import SwiftUI

struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var showingError = false
    
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
                FeatureRow(icon: "textformat.abc", text: "Custom keywords & websites")
                FeatureRow(icon: "checkmark.shield", text: "Real-time protection updates")
            }
            .padding(.vertical)
            
            // Dynamic pricing from App Store
            VStack(spacing: 8) {
                if subManager.isLoading && subManager.subscriptionProduct == nil {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading pricing...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text(subManager.subscriptionPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("per \(subManager.subscriptionPeriod)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                Task {
                    do {
                        try await subManager.purchase()
                        if subManager.isSubscribed {
                            isPresented = false
                        }
                    } catch SubscriptionError.userCancelled {
                        // User cancelled, don't show error
                        return
                    } catch {
                        showingError = true
                    }
                }
            }) {
                HStack {
                    if subManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Processing...")
                    } else {
                        Image(systemName: "crown.fill")
                        Text("START NOW")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(subManager.isLoading || subManager.subscriptionProduct == nil)
            .opacity(subManager.isLoading || subManager.subscriptionProduct == nil ? 0.6 : 1.0)
            
            Text("Payment will be charged to iTunes Account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24-hours before the end of the current period. Account will be charged for renewal within 24-hours prior to the end of the current period.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
            
//            HStack {
//                Button("Privacy Policy") {
//                    // Navigate to privacy policy
//                }
//                Spacer()
//                Button("Terms of use") {
//                    // Navigate to terms
//                }
//            }
//            .font(.caption)
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
                        } else if let errorMessage = subManager.errorMessage {
                            showingError = true
                        }
                    }
                }
                .disabled(subManager.isLoading)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(subManager.errorMessage ?? "An unexpected error occurred. Please try again.")
        }
        .onAppear {
            // Load products when the view appears if not already loaded
            if subManager.subscriptionProduct == nil && !subManager.isLoading {
                Task {
                    await subManager.loadProducts()
                }
            }
        }
    }
} 
