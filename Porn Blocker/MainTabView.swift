import SwiftUI
import StoreKit

struct MainTabView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var selectedTab = 0
    
    @StateObject private var ratingManager = RatingRequestManager.shared
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Image(systemName: "shield.fill")
                        Text("Protection")
                    }
                    .tag(0)
                
                StatsView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("Streaks")
                    }
                    .tag(1)
                
                SafeBrowserView()
                    .tabItem {
                        Image(systemName: "safari.fill")
                        Text("Safe Browse")
                    }
                    .tag(2)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
                    .tag(3)
            }
            
            // Custom Review Prompt Overlay
            if ratingManager.showReviewPrompt {
                ReviewPromptView(
                    isPresented: $ratingManager.showReviewPrompt,
                    onReviewAction: {
                        print("User opted to rate from prompt")
                    },
                    onDismiss: {
                        print("User dismissed review prompt")
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(100)
            }
        }
    }
}

// MARK: - Review Prompt View Component

struct ReviewPromptView: View {
    @Binding var isPresented: Bool
    let onReviewAction: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPrompt()
                }
            
            // Main prompt card
            VStack(spacing: 24) {
                // App icon and title section
                VStack(spacing: 16) {
                    // App icon placeholder (themed for Porn Blocker)
                    RoundedRectangle(cornerRadius: 16)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hue: 0.38, saturation: 0.65, brightness: 0.8), Color(hue: 0.42, saturation: 0.7, brightness: 0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                    
                    VStack(spacing: 8) {
                        Text("Enjoying Porn Blocker?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("Your feedback is important and helps us improve the protection experience for everyone.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(nil)
                    }
                }
                .padding(.top, 8)
                
                // Star rating display
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.title2)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Action buttons
                VStack(spacing: 12) {
                    // Primary action - Rate app
                    Button(action: {
                        rateApp()
                    }) {
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .font(.body)
                            Text("Rate App")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Secondary actions
                    HStack(spacing: 12) {
                        // Maybe later button
                        Button(action: {
                            dismissPrompt()
                        }) {
                            Text("Maybe later")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // No thanks button
                        Button(action: {
                            dismissPermanently()
                        }) {
                            Text("No, thanks")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemGray6))
                                .foregroundColor(.secondary)
                                .cornerRadius(10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
        .opacity(isPresented ? 1 : 0)
        .scaleEffect(isPresented ? 1 : 0.8)
    }
    
    private func rateApp() {
        onReviewAction()
        
        // Open App Store for rating
        if let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(RatingRequestManager.shared.appStoreID)?action=write-review") {
            UIApplication.shared.open(writeReviewURL)
        } else {
            // Fallback to native review prompt
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
        
        isPresented = false
    }
    
    private func dismissPrompt() {
        onDismiss()
        isPresented = false
    }
    
    private func dismissPermanently() {
        RatingRequestManager.shared.userDismissedReview()
        onDismiss()
        isPresented = false
    }
}

#Preview {
    MainTabView()
}
