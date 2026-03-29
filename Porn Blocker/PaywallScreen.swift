import SwiftUI

struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var showingError = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var featuresAppeared = false
    
    private let features: [(icon: String, text: String, color: Color)] = [
        ("globe.badge.chevron.backward", "Block millions of porn sites in Safari", Color(hue: 0.6,  saturation: 0.7, brightness: 0.75)),
        ("shield.fill",                  "Safe, private web browsing",              Color(hue: 0.38, saturation: 0.65, brightness: 0.5)),
        ("gear",                         "Fully customizable block list",            Color(hue: 0.08, saturation: 0.8,  brightness: 0.9)),
        ("textformat.abc",               "Custom keywords & websites",               Color(hue: 0.7,  saturation: 0.65, brightness: 0.8)),
        ("arrow.triangle.2.circlepath",  "Automatic database updates",               Color(hue: 0.0,  saturation: 0.7,  brightness: 0.65)),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Features
                featuresSection
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                
                // Trial info + CTA
                ctaSection
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                
                // Legal
                legalSection
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Later") { isPresented = false }
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Restore") {
                    Task {
                        await subManager.restore()
                        if subManager.isSubscribed { isPresented = false }
                        else if subManager.errorMessage != nil { showingError = true }
                    }
                }
                .foregroundColor(.white)
                .disabled(subManager.isLoading)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(subManager.errorMessage ?? "An unexpected error occurred. Please try again.")
        }
        .sheet(isPresented: $showPrivacyPolicy) { NavigationView { PrivacyPolicyView() } }
        .sheet(isPresented: $showTermsOfUse)  { NavigationView { TermsView() } }
        .onAppear {
            if subManager.subscriptionProduct == nil && !subManager.isLoading {
                Task { await subManager.loadProducts() }
            }
            withAnimation(.easeOut(duration: 0.5)) { featuresAppeared = true }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hue: 0.6, saturation: 0.75, brightness: 0.45),
                    Color(hue: 0.38, saturation: 0.65, brightness: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)
            
            // Decorative circles
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 220, height: 220)
                    .offset(x: -100, y: 40)
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .offset(x: 120, y: -30)
            }
            
            VStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.15), radius: 8)
                
                Text("PurePath Premium")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Try 7 days free, then \(subManager.subscriptionPrice)/\(subManager.subscriptionPeriod)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Features
    
    private var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(feature.color.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: feature.icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(feature.color)
                    }
                    
                    Text(feature.text)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                )
                .opacity(featuresAppeared ? 1 : 0)
                .offset(x: featuresAppeared ? 0 : -20)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.07), value: featuresAppeared)
            }
        }
    }
    
    // MARK: - CTA
    
    private var ctaSection: some View {
        VStack(spacing: 14) {
            if subManager.isLoading && subManager.subscriptionProduct == nil {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.85)
                    Text("Loading pricing…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Button(action: {
                Task {
                    do {
                        try await subManager.purchase()
                        if subManager.isSubscribed { isPresented = false }
                    } catch SubscriptionError.userCancelled {
                        return
                    } catch {
                        showingError = true
                    }
                }
            }) {
                HStack(spacing: 10) {
                    if subManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                        Text("Processing…")
                    } else {
                        Image(systemName: "star.fill")
                        Text("START 7-DAY FREE TRIAL")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hue: 0.6, saturation: 0.75, brightness: 0.65), Color(hue: 0.38, saturation: 0.65, brightness: 0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: Color(hue: 0.6, saturation: 0.5, brightness: 0.5).opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .disabled(subManager.isLoading || subManager.subscriptionProduct == nil)
            .opacity((subManager.isLoading || subManager.subscriptionProduct == nil) ? 0.6 : 1.0)
            
            Text("7 days free, then auto-renews. Cancel anytime in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Legal
    
    private var legalSection: some View {
        HStack {
            Button("Privacy Policy") { showPrivacyPolicy = true }
            Spacer()
            Button("Terms of Use") { showTermsOfUse = true }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
