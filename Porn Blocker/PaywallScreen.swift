import SwiftUI
import StoreKit

struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var showingError = false
    @State private var featuresAppeared = false
    @State private var selectedProduct: Product?

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.5)

    // Legal links open externally (Safari) rather than as in-app sheets,
    // so the App Store reviewer and users see canonical hosted documents.
    // Terms uses Apple's Standard EULA, which the in-app TermsView also
    // references as the controlling agreement.
    private let privacyPolicyURL = URL(string: "https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/")!
    private let termsOfUseURL    = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    private let features: [(icon: String, text: String, color: Color)] = [
        ("globe.badge.chevron.backward",        "Block millions of porn sites in Safari", Color(hue: 0.6,  saturation: 0.7, brightness: 0.75)),
        ("bubble.left.and.bubble.right.fill",   "Buddy chat — talk through urges 24/7",   Color(hue: 0.9,  saturation: 0.65, brightness: 0.75)),
        ("shield.fill",                         "Safe, private web browsing",             Color(hue: 0.38, saturation: 0.65, brightness: 0.5)),
        ("gear",                                "Fully customizable block list",          Color(hue: 0.08, saturation: 0.8,  brightness: 0.9)),
        ("textformat.abc",                      "Custom keywords & websites",             Color(hue: 0.7,  saturation: 0.65, brightness: 0.8)),
        ("arrow.triangle.2.circlepath",         "Automatic database updates",             Color(hue: 0.0,  saturation: 0.7,  brightness: 0.65)),
    ]

    /// The plan that will be purchased — the user's pick, defaulting to yearly.
    private var activeProduct: Product? {
        selectedProduct ?? subManager.yearlyProduct ?? subManager.products.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                featuresSection
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                planSelector
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                ctaSection
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

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
        .onAppear {
            if !subManager.hasLoadedProducts && !subManager.isLoading {
                Task { await subManager.loadProducts() }
            }
            withAnimation(.easeOut(duration: 0.5)) { featuresAppeared = true }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(hue: 0.6, saturation: 0.75, brightness: 0.45),
                    Color(hue: 0.38, saturation: 0.65, brightness: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 260)

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

                Text("Porn Blocker Premium")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Block adult content everywhere")
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

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 10) {
            if subManager.hasLoadedProducts {
                ForEach(subManager.products) { product in
                    planCard(product)
                }
            } else if subManager.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.85)
                    Text("Loading plans…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                Text("Pricing unavailable. Please check your connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = activeProduct?.id == product.id
        let isYearly = product.id == subManager.yearlyProduct?.id

        return Button {
            selectedProduct = product
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? accent : Color(.systemGray3))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.planName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if isYearly, let savings = subManager.yearlySavingsPercent {
                            Text("SAVE \(savings)%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(accent))
                        }
                    }
                    if let trial = product.freeTrialText {
                        Text("Includes \(trial.lowercased())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("per \(product.periodUnitText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accent : Color(.systemGray4),
                                    lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 14) {
            Button(action: purchaseSelectedPlan) {
                Group {
                    if subManager.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.85)
                            Text("Processing…")
                                .font(.headline)
                        }
                    } else {
                        VStack(spacing: 3) {
                            Text(ctaPrimaryTitle)
                                .font(.headline)
                            if let secondary = ctaSecondaryTitle {
                                Text(secondary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [Color(hue: 0.6, saturation: 0.75, brightness: 0.65), accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
                .shadow(color: accent.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .disabled(subManager.isLoading || activeProduct == nil)
            .opacity((subManager.isLoading || activeProduct == nil) ? 0.6 : 1.0)

            if let product = activeProduct {
                billingDisclosure(for: product)
            }
        }
    }

    /// CTA button title. When a free trial is available, the button must make
    /// clear that an auto-renewing subscription follows — Apple guideline
    /// 3.1.2(c). The post-trial price is rendered as a secondary line on the
    /// button itself so it's no less prominent than the trial mention.
    private var ctaPrimaryTitle: String {
        guard let product = activeProduct else { return "Subscribe Now" }
        if product.freeTrialText != nil {
            return "Start Free Trial & Subscribe"
        }
        return "Subscribe Now"
    }

    private var ctaSecondaryTitle: String? {
        guard let product = activeProduct, product.freeTrialText != nil else { return nil }
        return "Then \(product.displayPrice) per \(product.periodUnitText), auto-renews"
    }

    /// Below-button disclosure. The total billed amount is the largest, boldest
    /// element; trial duration and cancellation language are subordinate.
    @ViewBuilder
    private func billingDisclosure(for product: Product) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                if let trial = product.freeTrialText {
                    Text("per \(product.periodUnitText) after \(trial)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("per \(product.periodUnitText)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Text(product.freeTrialText != nil
                 ? "Your subscription begins automatically when the free trial ends. Auto-renews until cancelled — cancel anytime in Settings at least 24 hours before the renewal date."
                 : "Auto-renews until cancelled — cancel anytime in Settings at least 24 hours before the renewal date.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func purchaseSelectedPlan() {
        guard let product = activeProduct else { return }
        Task {
            do {
                try await subManager.purchase(product)
                if subManager.isSubscribed { isPresented = false }
            } catch SubscriptionError.userCancelled {
                return
            } catch {
                showingError = true
            }
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        HStack {
            Link("Privacy Policy", destination: privacyPolicyURL)
            Spacer()
            Link("Terms of Use", destination: termsOfUseURL)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}
