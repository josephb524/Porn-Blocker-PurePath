import SwiftUI
import StoreKit

/// The paywall, in the onboarding artwork's style (dark field, the brand
/// shield) and laid out after Cairn's house paywall: hero, emblem feature
/// rows, two side-by-side plan cards, a breathing CTA, billing disclosure,
/// legal links. Every 3.1.2(c) rule in CLAUDE.md still holds — see
/// "Paywall layout (App Store 3.1.2(c))" before changing anything here.
struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    @State private var showingError = false
    @State private var featuresAppeared = false
    @State private var selectedProduct: Product?
    @State private var ctaPulse = false

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.62)

    // Legal links open externally (Safari) rather than as in-app sheets,
    // so the App Store reviewer and users see canonical hosted documents.
    // Terms uses Apple's Standard EULA, which the in-app TermsView also
    // references as the controlling agreement.
    private let privacyPolicyURL = URL(string: "https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/")!
    private let termsOfUseURL    = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Paid features only — streaks are free, so they are not sold here.
    private let features: [(art: FeatureArtKind, text: LocalizedStringKey)] = [
        (.safariBlocking, "Block millions of porn sites in Safari"),
        (.safeBrowser,    "Safe, private web browsing"),
        (.buddyChat,      "Buddy chat — talk through urges 24/7"),
        (.customList,     "Custom keywords & websites"),
    ]

    /// The plan that will be purchased — the user's pick, defaulting to yearly.
    private var activeProduct: Product? {
        selectedProduct ?? subManager.yearlyProduct ?? subManager.products.first
    }

    /// Trial text for the active plan, only if this Apple ID can take it.
    private var activeTrial: String? { subManager.trialText(for: activeProduct) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection

                VStack(spacing: 18) {
                    featuresSection
                    planSelector
                    ctaSection
                    legalSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .background(PaywallBackground().ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // The toolbar sits over the dark header. Without declaring the color
        // scheme, iOS 26's glass toolbar buttons pick a dark label that's
        // illegible here — `.foregroundColor(.white)` alone is ignored.
        .toolbarColorScheme(.dark, for: .navigationBar)
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
            Text(subManager.errorMessage ?? String(localized: "An unexpected error occurred. Please try again."))
        }
        .onAppear {
            if !subManager.hasLoadedProducts && !subManager.isLoading {
                Task { await subManager.loadProducts() }
            }
            withAnimation(.easeOut(duration: 0.5)) { featuresAppeared = true }
            // The CTA breathes — the one moving thing on the screen, so the
            // eye returns to it while the reader weighs the plans.
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                ctaPulse = true
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [ArtColor.shieldBottom.opacity(0.4), .clear],
                                         center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                SparkShape().fill(ArtColor.pink).frame(width: 13, height: 13).offset(x: -52, y: -26)
                SparkShape().fill(ArtColor.lavender).frame(width: 16, height: 16).offset(x: 50, y: -30)
                SparkShape().fill(ArtColor.pink).frame(width: 10, height: 10).offset(x: 56, y: 22)
                BrandShield(size: 58)
            }
            .frame(height: 96)
            .accessibilityHidden(true)

            Text("Adult Blocker Premium")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Block adult content everywhere")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        // Clears the toolbar: "Later" / "Restore" sit on this band, and the
        // German "Wiederherstellen" reaches well past the sparks otherwise.
        .padding(.top, 100)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                HStack(spacing: 12) {
                    FeatureEmblem(kind: feature.art, size: 28)
                    Text(feature.text)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer(minLength: 0)
                }
                .opacity(featuresAppeared ? 1 : 0)
                .offset(x: featuresAppeared ? 0 : -20)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.07), value: featuresAppeared)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Plan Selector

    @ViewBuilder
    private var planSelector: some View {
        if subManager.hasLoadedProducts {
            HStack(spacing: 10) {
                ForEach(subManager.products) { product in
                    planCard(product)
                }
            }
            .padding(.top, 8)
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

    /// Side-by-side plan card. The billed price is the headline — the most
    /// prominent pricing element (3.1.2(c)); the savings ribbon and the trial
    /// line are smaller and subordinate, and the trial stays muted.
    private func planCard(_ product: Product) -> some View {
        let isSelected = activeProduct?.id == product.id
        let isYearly = product.id == subManager.yearlyProduct?.id

        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedProduct = product
            }
        } label: {
            VStack(spacing: 4) {
                Text(product.planName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? accent : .secondary)

                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)

                Text("per \(product.periodUnitText)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let trial = subManager.trialText(for: product) {
                    Text("Includes \(trial)", comment: "Plan card caption, e.g. \"Includes 3-day free trial\"")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            // minHeight keeps the pair matched: the trial line exists on one
            // card only, and unequal cards read as a mistake, not a choice.
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.16) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.white.opacity(0.14),
                                  lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .top) {
                if isYearly, let savings = subManager.yearlySavingsPercent {
                    Text("SAVE \(savings)%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent))
                        .offset(y: -10)
                }
            }
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
                        Text(ctaPrimaryTitle)
                            .font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(
                    LinearGradient(
                        colors: [Color(hue: 0.6, saturation: 0.7, brightness: 0.75),
                                 Color(hue: 0.38, saturation: 0.65, brightness: 0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(18)
            }
            .disabled(subManager.isLoading || activeProduct == nil)
            .opacity((subManager.isLoading || activeProduct == nil) ? 0.6 : 1.0)
            // Breathing, not bouncing: a slow swell with the shadow rising and
            // falling. Scale, never frame (CLAUDE.md "Pulse animations").
            .scaleEffect(ctaPulse ? 1.025 : 1.0)
            .shadow(color: accent.opacity(ctaPulse ? 0.5 : 0.25),
                    radius: ctaPulse ? 16 : 8, x: 0, y: 6)

            if let product = activeProduct {
                billingDisclosure(for: product)
            }
        }
    }

    /// CTA button title — one line, as on Cairn: "Start Free Trial" when this
    /// Apple ID can take the trial, else "Subscribe Now". The paid,
    /// auto-renewing subscription that follows is stated directly under the
    /// button (`billingDisclosure`: bold billed price, then the full terms).
    /// Owner's call 2026-09-27, knowing the first submission was rejected
    /// under 3.1.2(c) with the terms off the button — if App Review objects
    /// again, restore the second line on the button ("Then $X per year,
    /// auto-renews"; see git history).
    private var ctaPrimaryTitle: String {
        if activeTrial != nil {
            return String(localized: "Start Free Trial")
        }
        return String(localized: "Subscribe Now")
    }

    /// Below-button disclosure. The total billed amount is the largest, boldest
    /// element; trial duration and cancellation language are subordinate.
    @ViewBuilder
    private func billingDisclosure(for product: Product) -> some View {
        let trial = subManager.trialText(for: product)
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                if let trial {
                    Text("per \(product.periodUnitText) after \(trial)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("per \(product.periodUnitText)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Text(trial != nil
                 ? String(localized: "Your subscription begins automatically when the free trial ends. Auto-renews until cancelled — cancel anytime in Settings at least 24 hours before the renewal date.", comment: "Legal billing disclosure (App Store 3.1.2(c)) — translate every clause faithfully")
                 : String(localized: "Auto-renews until cancelled — cancel anytime in Settings at least 24 hours before the renewal date.", comment: "Legal billing disclosure (App Store 3.1.2(c)) — translate every clause faithfully"))
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
        HStack(spacing: 14) {
            Link("Terms of Use", destination: termsOfUseURL)
            Text("·").foregroundColor(.secondary)
            Link("Privacy Policy", destination: privacyPolicyURL)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.7))
        .frame(maxWidth: .infinity)
    }
}

/// The onboarding field: deep navy with a faint blue and green glow.
private struct PaywallBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.6, saturation: 0.5, brightness: 0.15),
                         Color(hue: 0.6, saturation: 0.6, brightness: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            Circle()
                .fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.4).opacity(0.15))
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: -140, y: -260)
            Circle()
                .fill(Color(hue: 0.38, saturation: 0.6, brightness: 0.4).opacity(0.12))
                .frame(width: 300)
                .blur(radius: 60)
                .offset(x: 150, y: 260)
        }
    }
}
