import SwiftUI
import StoreKit

/// Which purchase a paywall sells.
enum PaywallOffer {
    /// Premium (monthly / yearly) plus the one-time Lifetime purchase.
    case premium
    /// The Buddy Chat add-on, for Lifetime owners — whose purchase doesn't
    /// include chat. Opened from the locked Buddy tab.
    case buddyChat

    /// The offer's auto-renewing plans, cheapest first.
    @MainActor func plans(from subManager: SubscriptionManager) -> [Product] {
        switch self {
        case .premium:   return subManager.premiumPlans
        case .buddyChat: return subManager.buddyPlans
        }
    }

    @MainActor func monthlyPlan(from subManager: SubscriptionManager) -> Product? {
        switch self {
        case .premium:   return subManager.monthlyProduct
        case .buddyChat: return subManager.buddyMonthlyProduct
        }
    }

    @MainActor func yearlyPlan(from subManager: SubscriptionManager) -> Product? {
        switch self {
        case .premium:   return subManager.yearlyProduct
        case .buddyChat: return subManager.buddyYearlyProduct
        }
    }

    /// The plan selected when the paywall opens: yearly, else the cheapest.
    @MainActor func defaultPlan(from subManager: SubscriptionManager) -> Product? {
        yearlyPlan(from: subManager) ?? plans(from: subManager).first
    }
}

/// The paywall, in the onboarding artwork's style (dark field, the brand
/// shield) and laid out after Cairn's house paywall: hero, emblem feature
/// rows, two side-by-side plan cards, a breathing CTA, billing disclosure,
/// legal links. The Premium offer adds a full-width Lifetime card under the
/// pair. Every 3.1.2(c) rule in CLAUDE.md still holds — see
/// "Paywall layout (App Store 3.1.2(c))" before changing anything here.
struct PaywallScreen: View {
    @StateObject private var subManager = SubscriptionManager.shared
    @Binding var isPresented: Bool
    var offer: PaywallOffer = .premium
    @State private var showingError = false
    /// Overrides the manager's error in the alert — set when a restore finds
    /// purchases, but not the one this paywall sells.
    @State private var restoreMessage: String?
    @State private var featuresAppeared = false
    @State private var selectedProduct: Product?
    @State private var ctaPulse = false

    private let accent = Color(hue: 0.38, saturation: 0.65, brightness: 0.62)

    /// Below this height (the paywall's container, bars included) it goes
    /// compact: no hero art or subtitle, the title just under the toolbar, and
    /// slightly tighter rows, cards and gaps — so the CTA and the whole billing
    /// disclosure still sit above the fold (3.1.2(c)). The full layout needs
    /// about this much. Compact: everywhere on the iPhone SE, the 12/13 mini
    /// and the iPhone Duo's outer display, plus the Safe Browse / Buddy sheets
    /// on 6.1–6.3-inch phones, where a sheet's ~60pt shortfall cut off the
    /// disclosure's last line (seen on an iPhone 16e). Full-screen paywalls
    /// on those phones keep the full layout. Fonts and the pricing hierarchy
    /// are the same in both.
    private static let compactBelowHeight: CGFloat = 840

    // Legal links open externally (Safari) rather than as in-app sheets,
    // so the App Store reviewer and users see canonical hosted documents.
    // Terms uses Apple's Standard EULA, which the in-app TermsView also
    // references as the controlling agreement.
    private let privacyPolicyURL = URL(string: "https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/")!
    private let termsOfUseURL    = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Paid features only — streaks are free, so they are not sold here.
    private var features: [(art: FeatureArtKind, text: LocalizedStringKey)] {
        switch offer {
        case .premium:
            return [
                (.safariBlocking, "Block millions of porn sites in Safari"),
                (.safeBrowser,    "Safe, private web browsing"),
                (.buddyChat,      "Buddy chat — talk through urges 24/7"),
                (.customList,     "Custom keywords & websites"),
            ]
        case .buddyChat:
            return [
                (.empathy,  "Empathetic, non-judgmental support"),
                (.anytime,  "Available whenever an urge hits"),
                (.onDevice, "Conversations stay on your device"),
            ]
        }
    }

    private var title: LocalizedStringKey {
        switch offer {
        case .premium:   return "Adult Blocker Premium"
        case .buddyChat: return "Buddy Chat"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch offer {
        case .premium:   return "Block adult content everywhere"
        case .buddyChat: return "Add chat support to your Lifetime plan"
        }
    }

    private var plans: [Product] { offer.plans(from: subManager) }

    /// The plan that will be purchased — the user's pick, defaulting to yearly.
    private var activeProduct: Product? {
        selectedProduct ?? offer.defaultPlan(from: subManager)
    }

    /// Trial text for the active plan, only if this Apple ID can take it.
    private var activeTrial: String? { subManager.trialText(for: activeProduct) }

    private var lifetimeSelected: Bool { activeProduct?.isLifetime == true }

    /// The Lifetime card's product — Premium offer only, and hidden once
    /// owned: an owner who reaches a paywall is here for something else.
    private var lifetimeOffer: Product? {
        guard offer == .premium, !subManager.ownsLifetime else { return nil }
        return subManager.lifetimeProduct
    }

    /// Whether what this paywall sells is now unlocked — closes it after a
    /// purchase or restore.
    private var offerUnlocked: Bool {
        switch offer {
        case .premium:   return subManager.isSubscribed
        case .buddyChat: return subManager.hasBuddyAccess
        }
    }

    var body: some View {
        GeometryReader { proxy in
            // The whole container — the window, or the sheet: the reader sits
            // inside the safe area, whose insets cover the navigation bar,
            // home indicator and any tab bar.
            let compact = proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                < Self.compactBelowHeight
            ScrollView {
                VStack(spacing: 0) {
                    headerSection(compact: compact)

                    VStack(spacing: compact ? 14 : 18) {
                        featuresSection(compact: compact)
                        planSelector(compact: compact)
                        ctaSection
                        legalSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            // Full layout: the art runs up under the toolbar. Compact: content
            // starts below it.
            .ignoresSafeArea(edges: compact ? [] : .top)
        }
        .background(PaywallBackground().ignoresSafeArea())
        .environment(\.colorScheme, .dark)
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
                        restoreMessage = nil
                        await subManager.restore()
                        if offerUnlocked {
                            isPresented = false
                        } else if subManager.errorMessage != nil {
                            showingError = true
                        } else {
                            // Restored something, but not what this paywall
                            // sells (e.g. Lifetime, on the Buddy Chat offer).
                            restoreMessage = String(localized: "No active subscription found")
                            showingError = true
                        }
                    }
                }
                .foregroundColor(.white)
                .disabled(subManager.isLoading)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(restoreMessage ?? subManager.errorMessage ?? String(localized: "An unexpected error occurred. Please try again."))
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

    private func headerSection(compact: Bool) -> some View {
        VStack(spacing: 8) {
            if !compact {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [heroGlow.opacity(0.4), .clear],
                                             center: .center, startRadius: 0, endRadius: 70))
                        .frame(width: 140, height: 140)
                    SparkShape().fill(ArtColor.pink).frame(width: 13, height: 13).offset(x: -52, y: -26)
                    SparkShape().fill(ArtColor.lavender).frame(width: 16, height: 16).offset(x: 50, y: -30)
                    SparkShape().fill(ArtColor.pink).frame(width: 10, height: 10).offset(x: 56, y: 22)
                    heroArt
                }
                .frame(height: 96)
                .accessibilityHidden(true)
            }

            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // The feature rows below say the same thing.
            if !compact {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        // Clears the toolbar: "Later" / "Restore" sit on this band, and the
        // German "Wiederherstellen" reaches well past the sparks otherwise.
        // Compact content already starts below the bar.
        .padding(.top, compact ? 8 : 100)
    }

    @ViewBuilder
    private var heroArt: some View {
        switch offer {
        case .premium:   BrandShield(size: 58)
        case .buddyChat: FeatureEmblem(kind: .buddyChat, size: 58)
        }
    }

    private var heroGlow: Color {
        switch offer {
        case .premium:   return ArtColor.shieldBottom
        case .buddyChat: return Color(red: 0.5, green: 0.3, blue: 0.9)
        }
    }

    // MARK: - Features

    private func featuresSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                // Lifetime leaves out the chat, so with it selected the chat
                // row is crossed out rather than silently still on offer.
                let excluded = lifetimeSelected && feature.art == .buddyChat
                HStack(spacing: 12) {
                    FeatureEmblem(kind: feature.art, size: compact ? 24 : 28)
                    Text(feature.text)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .strikethrough(excluded)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer(minLength: 0)
                }
                .opacity(featuresAppeared ? (excluded ? 0.4 : 1) : 0)
                .offset(x: featuresAppeared ? 0 : -20)
                .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.07), value: featuresAppeared)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Plan Selector

    @ViewBuilder
    private func planSelector(compact: Bool) -> some View {
        if !plans.isEmpty || lifetimeOffer != nil {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(plans) { product in
                        planCard(product, compact: compact)
                    }
                }
                if let lifetime = lifetimeOffer {
                    lifetimeCard(lifetime)
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
    private func planCard(_ product: Product, compact: Bool) -> some View {
        let isSelected = activeProduct?.id == product.id
        let isYearly = product.id == offer.yearlyPlan(from: subManager)?.id

        return Button {
            select(product)
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
            // 92 still clears the yearly card's four lines (84 at default size).
            .frame(maxWidth: .infinity, minHeight: compact ? 92 : 104)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(planCardChrome(isSelected: isSelected))
            .overlay(alignment: .top) {
                if isYearly, let savings = subManager.yearlySavingsPercent(
                    monthly: offer.monthlyPlan(from: subManager),
                    yearly: offer.yearlyPlan(from: subManager)
                ) {
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

    /// Full-width card under the subscription pair. As on the plan cards, the
    /// one-time price is the headline; what Lifetime leaves out is stated on
    /// the card itself, not left to the crossed-out feature row.
    private func lifetimeCard(_ product: Product) -> some View {
        let isSelected = activeProduct?.id == product.id

        return Button {
            select(product)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lifetime")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? accent : .secondary)
                    Text("Everything except Buddy chat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(.primary)
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    Text("one-time", comment: "Lifetime plan card, under the price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(planCardChrome(isSelected: isSelected))
        }
        .buttonStyle(.plain)
    }

    /// The selection chrome every plan card shares.
    private func planCardChrome(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? accent.opacity(0.16) : Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? accent : Color.white.opacity(0.14),
                                  lineWidth: isSelected ? 2 : 1)
            )
    }

    private func select(_ product: Product) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedProduct = product
        }
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

    /// CTA button title — one line, as on Cairn: "Buy Lifetime Access" for the
    /// one-time purchase; for a subscription, "Start Free Trial" when this
    /// Apple ID can take the trial, else "Subscribe Now". The paid,
    /// auto-renewing subscription that follows is stated directly under the
    /// button (`billingDisclosure`: bold billed price, then the full terms).
    /// Owner's call 2026-09-27, knowing the first submission was rejected
    /// under 3.1.2(c) with the terms off the button — if App Review objects
    /// again, restore the second line on the button ("Then $X per year,
    /// auto-renews"; see git history).
    private var ctaPrimaryTitle: String {
        if lifetimeSelected {
            return String(localized: "Buy Lifetime Access")
        }
        if activeTrial != nil {
            return String(localized: "Start Free Trial")
        }
        return String(localized: "Subscribe Now")
    }

    /// Below-button disclosure. The total billed amount is the largest, boldest
    /// element; trial duration and cancellation language are subordinate.
    @ViewBuilder
    private func billingDisclosure(for product: Product) -> some View {
        if product.isLifetime {
            lifetimeDisclosure(for: product)
        } else {
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
    }

    /// The Lifetime counterpart, in the same hierarchy (billed price largest):
    /// it says plainly that nothing renews and that Buddy chat isn't included.
    private func lifetimeDisclosure(for product: Product) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("one-time purchase")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Text("Pay once — no subscription, nothing renews. Includes every protection feature; Buddy chat is not included.", comment: "Lifetime billing disclosure — translate every clause faithfully")
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
                if offerUnlocked { isPresented = false }
            } catch SubscriptionError.userCancelled {
                return
            } catch {
                restoreMessage = nil
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
