import SwiftUI
import WebKit

// MARK: - Safe Browser View

struct SafeBrowserView: View {
    @StateObject private var viewModel = SafeBrowserViewModel()
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var addressText = ""
    @State private var isEditingAddress = false
    @State private var showPaywall = false
    @State private var showTabSwitcher = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        if subManager.isSubscribed {
            browserView
        } else {
            lockedView
        }
    }

    /// Caption under the "Unlock Safe Browser" button. Mirrors the paywall:
    /// if the default plan (yearly) has a free-trial offer, mention it;
    /// otherwise just say "Cancel anytime".
    private var trialTeaserText: String {
        if let trial = subManager.yearlyProduct?.freeTrialText {
            return "\(trial) · Cancel anytime"
        }
        return "Cancel anytime"
    }

    // MARK: - Locked Gate (non-subscribers)

    private var lockedView: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: 0.6, saturation: 0.5, brightness: 0.15),
                        Color(hue: 0.6, saturation: 0.6, brightness: 0.08)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(hue: 0.6, saturation: 0.6, brightness: 0.4).opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -80, y: -120)

                Circle()
                    .fill(Color(hue: 0.38, saturation: 0.6, brightness: 0.4).opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: 100, y: 200)

                VStack(spacing: 28) {
                    Spacer()

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 110, height: 110)
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 80, height: 80)
                        Image(systemName: "safari.fill")
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hue: 0.6, saturation: 0.3, brightness: 0.9)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    }

                    // Text
                    VStack(spacing: 10) {
                        Text("Safe Browser")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Browse with confidence — the Safe Browser actively blocks adult sites, blurs inappropriate images, and filters harmful content in real time.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    // Feature pills
                    VStack(spacing: 10) {
                        LockedFeaturePill(icon: "shield.fill",      text: "Real-time domain blocking")
                        LockedFeaturePill(icon: "eye.slash.fill",   text: "Automatic image blurring")
                        LockedFeaturePill(icon: "bolt.shield.fill", text: "Dynamic content filtering")
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // CTA
                    VStack(spacing: 12) {
                        Button(action: { showPaywall = true }) {
                            HStack(spacing: 10) {
                                Image(systemName: "lock.open.fill")
                                Text("Unlock Safe Browser")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(hue: 0.6, saturation: 0.7, brightness: 0.75),
                                        Color(hue: 0.38, saturation: 0.65, brightness: 0.5)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(
                                color: Color(hue: 0.6, saturation: 0.5, brightness: 0.5).opacity(0.4),
                                radius: 14, x: 0, y: 6
                            )
                        }
                        .padding(.horizontal, 24)

                        Text(trialTeaserText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                NavigationStack {
                    PaywallScreen(isPresented: $showPaywall)
                }
            }
        }    }

    // MARK: - Browser (subscribers only)

    private var browserView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                addressBar

                ZStack {
                    SafeWebView(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)

                    if viewModel.isBlocked {
                        BlockedOverlayView(domain: viewModel.blockedDomain) {
                            viewModel.goBack()
                        }
                        .transition(.opacity)
                    } else if let loadError = viewModel.loadError {
                        LoadErrorOverlayView(
                            message: loadError,
                            onRetry: { viewModel.reload() },
                            onGoBack: { viewModel.goBack() }
                        )
                        .transition(.opacity)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { addressText = viewModel.currentURL }
            .onChange(of: viewModel.currentURL) { url in
                if !isEditingAddress { addressText = url }
            }
            .onChange(of: addressFocused) { focused in
                // Tapping away without committing previously left the field in
                // "editing" mode forever, freezing the address display.
                if !focused {
                    isEditingAddress = false
                    addressText = viewModel.currentURL
                }
            }
            .sheet(isPresented: $showTabSwitcher) {
                TabSwitcherView(viewModel: viewModel)
            }
        }
    }

    // MARK: - Address Bar

    private var addressBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                addressPill

                Button(action: { showTabSwitcher = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.primary, lineWidth: 1.8)
                            .frame(width: 20, height: 20)
                        Text("\(viewModel.tabs.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                            .minimumScaleFactor(0.5)
                            .frame(width: 16)
                    }
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color(.systemGray6)))
                }
                .accessibilityLabel("Tabs")
                .accessibilityValue("\(viewModel.tabs.count) open")

                Button(action: { viewModel.newTab() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.blue))
                }
                .accessibilityLabel("New Tab")
            }

            HStack(spacing: 20) {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: viewModel.canGoBack ? .semibold : .medium))
                        .foregroundColor(viewModel.canGoBack ? .primary : Color(.systemGray3))
                        .frame(width: 32, height: 32)
                }
                .disabled(!viewModel.canGoBack)
                .accessibilityLabel("Go back")

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: viewModel.canGoForward ? .semibold : .medium))
                        .foregroundColor(viewModel.canGoForward ? .primary : Color(.systemGray3))
                        .frame(width: 32, height: 32)
                }
                .disabled(!viewModel.canGoForward)
                .accessibilityLabel("Go forward")

                Spacer()

                Text("Swipe the bar to switch tabs")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Menu {
                    if viewModel.isLoading {
                        Button {
                            viewModel.stopLoading()
                        } label: {
                            Label("Stop Loading", systemImage: "xmark")
                        }
                    } else {
                        Button {
                            viewModel.reload()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) {
                        if let id = viewModel.activeTabID { viewModel.closeTab(id) }
                    } label: {
                        Label("Close Tab", systemImage: "xmark.square")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("More options")
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    /// The pill: protection badge + styled URL (or the edit field) + spinner.
    /// Swiping it horizontally switches tabs.
    private var addressPill: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color(hue: 0.38, saturation: 0.55, brightness: 0.55))
                    .frame(width: 22, height: 22)
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

            if isEditingAddress {
                TextField("Search or enter website", text: $addressText, onCommit: {
                    navigateTo(addressText)
                    isEditingAddress = false
                    addressFocused = false
                })
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($addressFocused)

                if !addressText.isEmpty {
                    Button(action: { addressText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .accessibilityLabel("Clear address")
                }
            } else {
                Text(styledAddress)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        addressText = viewModel.currentURL
                        isEditingAddress = true
                        // The field mounts on this state change; focus lands
                        // on the next runloop once it exists.
                        DispatchQueue.main.async { addressFocused = true }
                    }
                    .accessibilityLabel("Address: \(viewModel.currentURL)")
                    .accessibilityHint("Tap to edit. Swipe left or right to switch tabs.")

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color(.systemGray6)))
        .highPriorityGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !isEditingAddress else { return }
                    if value.translation.width < -50 {
                        viewModel.activateAdjacentTab(1)
                    } else if value.translation.width > 50 {
                        viewModel.activateAdjacentTab(-1)
                    }
                },
            including: isEditingAddress ? .subviews : .all
        )
    }

    /// "google.com/search" style display: bold host, gray path.
    private var styledAddress: AttributedString {
        guard let url = URL(string: viewModel.currentURL), let host = url.host else {
            var placeholder = AttributedString(
                viewModel.currentURL.isEmpty ? "Search or enter website" : viewModel.currentURL
            )
            placeholder.font = .system(size: 16)
            placeholder.foregroundColor = .secondary
            return placeholder
        }
        var displayHost = host
        if displayHost.hasPrefix("www.") { displayHost = String(displayHost.dropFirst(4)) }
        var hostPart = AttributedString(displayHost)
        hostPart.font = .system(size: 16, weight: .semibold)
        hostPart.foregroundColor = .primary

        var path = url.path
        if path == "/" { path = "" }
        var pathPart = AttributedString(path)
        pathPart.font = .system(size: 16)
        pathPart.foregroundColor = .secondary
        return hostPart + pathPart
    }

    // MARK: - Navigation Helper

    private func navigateTo(_ input: String) {
        var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://\(urlString)"
            } else {
                let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                urlString = "https://www.google.com/search?q=\(encoded)"
            }
        }
        if let url = URL(string: urlString) {
            viewModel.navigate(to: url)
        }
    }
}

// MARK: - Tab Switcher

struct TabSwitcherView: View {
    @ObservedObject var viewModel: SafeBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    /// Persisted layout preference — two-column card grid by default,
    /// switchable to list rows via the header toggle.
    @AppStorage("tabSwitcherGridLayout") private var useGrid = true
    @State private var searchText = ""
    @State private var showCloseAllConfirm = false

    private var filteredTabs: [BrowserTab] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return viewModel.tabs }
        return viewModel.tabs.filter {
            ($0.title ?? "").lowercased().contains(query)
                || $0.urlString.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField

            Divider()

            ScrollView {
                if filteredTabs.isEmpty {
                    Text("No tabs match")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 60)
                } else if useGrid {
                    gridLayout
                } else {
                    listLayout
                }
            }

            bottomBar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .confirmationDialog("Close all tabs?", isPresented: $showCloseAllConfirm, titleVisibility: .visible) {
            Button("Close All Tabs", role: .destructive) {
                viewModel.closeAllTabs()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header + search

    private var header: some View {
        ZStack {
            VStack(spacing: 1) {
                Text("Tabs")
                    .font(.headline)
                Text("\(viewModel.tabs.count) open")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.newTab()
                    dismiss()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                        )
                }
                .accessibilityLabel("New Tab")

                Spacer()

                Button {
                    useGrid.toggle()
                } label: {
                    Image(systemName: useGrid ? "list.bullet" : "square.grid.2x2")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                        )
                }
                .accessibilityLabel(useGrid ? "Show as list" : "Show as grid")

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                        )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search tabs", text: $searchText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: List layout

    private var listLayout: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredTabs) { tab in
                listRow(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func listRow(_ tab: BrowserTab) -> some View {
        let isActive = tab.id == viewModel.activeTabID
        return Button {
            viewModel.activateTab(tab.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                TabMonogram(host: host(of: tab), size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle(for: tab))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(tab.urlString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                closeButton(for: tab)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayTitle(for: tab))
        .accessibilityValue(isActive ? "Active tab" : "")
    }

    // MARK: Grid layout

    private var gridLayout: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())],
            spacing: 14
        ) {
            ForEach(filteredTabs) { tab in
                gridCard(tab)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func gridCard(_ tab: BrowserTab) -> some View {
        let isActive = tab.id == viewModel.activeTabID
        return Button {
            viewModel.activateTab(tab.id)
            dismiss()
        } label: {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    // Stylized page-preview placeholder.
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(width: 90, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(width: 110, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(width: 70, height: 8)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 8)
                    }
                    .padding(16)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 140, alignment: .top)

                    closeButton(for: tab)
                        .padding(8)
                }

                HStack(spacing: 8) {
                    TabMonogram(host: host(of: tab), size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(displayTitle(for: tab))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(host(of: tab))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(displayTitle(for: tab))
        .accessibilityValue(isActive ? "Active tab" : "")
    }

    // MARK: Shared pieces

    private func closeButton(for tab: BrowserTab) -> some View {
        Button {
            viewModel.closeTab(tab.id)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(.systemGray5)))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Close tab")
    }

    private var bottomBar: some View {
        HStack {
            Button {
                showCloseAllConfirm = true
            } label: {
                Text("Close All")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(.systemGray5)))
            }

            Spacer()

            Text(useGrid ? "Tap a card to switch" : "Tap a row to switch")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Button {
                viewModel.newTab()
                dismiss()
            } label: {
                Text("New Tab")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.blue))
            }
            .accessibilityLabel("New Tab")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func host(of tab: BrowserTab) -> String {
        var host = URL(string: tab.urlString)?.host ?? tab.urlString
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        return host
    }

    private func displayTitle(for tab: BrowserTab) -> String {
        if let title = tab.title, !title.isEmpty { return title }
        return host(of: tab)
    }
}

/// Colored first-letter "favicon" square, deterministic per host so a site
/// keeps its color across launches (Swift's `hashValue` is seeded per run,
/// so the hash here is hand-rolled).
private struct TabMonogram: View {
    let host: String
    let size: CGFloat

    private static let palette: [Color] = [
        Color(white: 0.15),                                        // near-black
        Color(hue: 0.38, saturation: 0.55, brightness: 0.55),      // green
        Color(hue: 0.07, saturation: 0.80, brightness: 0.80),      // orange
        Color(hue: 0.60, saturation: 0.75, brightness: 0.85),      // blue
        Color(hue: 0.75, saturation: 0.60, brightness: 0.80),      // purple
        Color(white: 0.45),                                        // gray
        Color(hue: 0.50, saturation: 0.65, brightness: 0.65),      // teal
        Color(hue: 0.95, saturation: 0.65, brightness: 0.75)       // pink-red
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundColor(.white)
            )
            .accessibilityHidden(true)
    }

    private var letter: String {
        host.first.map { String($0).uppercased() } ?? "•"
    }

    private var color: Color {
        let hash = host.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return Self.palette[abs(hash) % Self.palette.count]
    }
}

// MARK: - Locked Feature Pill

struct LockedFeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hue: 0.6, saturation: 0.4, brightness: 0.85))
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Blocked Overlay

struct BlockedOverlayView: View {
    let domain: String
    let onGoBack: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                }

                VStack(spacing: 8) {
                    Text("Site Blocked")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(domain)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("This website has been blocked by Porn Blocker because it contains adult content.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                Button(action: onGoBack) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Go Back")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
            }
        }
    }
}

// MARK: - Load Error Overlay

/// Shown when a page fails to load for a genuine network reason (offline,
/// DNS failure, bad TLS) — previously these left the progress bar spinning
/// forever with no feedback.
struct LoadErrorOverlayView: View {
    let message: String
    let onRetry: () -> Void
    let onGoBack: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                }

                VStack(spacing: 8) {
                    Text("Couldn't Load Page")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                HStack(spacing: 12) {
                    Button(action: onGoBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Go Back")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .cornerRadius(14)
                    }

                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                }
            }
        }
    }
}

// MARK: - WKWebView Representable

@MainActor
struct SafeWebView: UIViewRepresentable {
    @ObservedObject var viewModel: SafeBrowserViewModel

    /// A plain container; `updateUIView` swaps the active tab's webview in.
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let tabID = viewModel.activeTabID else { return }
        let webView = viewModel.webView(for: tabID, coordinator: context.coordinator)
        guard webView.superview !== container else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    /// Shared navigation/UI delegate for every tab's webview. Pushes of
    /// visible state are identity-guarded against `activeWebView` so a
    /// background tab's events can't clobber the visible UI.
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let viewModel: SafeBrowserViewModel

        init(viewModel: SafeBrowserViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            guard let url = navigationAction.request.url,
                  let host = url.host?.lowercased() else {
                decisionHandler(.allow)
                return
            }

            let manager = BlocklistManager.shared
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false

            // Only block if the user has an active subscription
            guard SubscriptionManager.shared.isSubscribed else {
                decisionHandler(.allow)
                return
            }

            // 1. Whitelist Check (Highest Priority)
            if manager.hostMatches(host, anyDomainIn: manager.whitelistSet) {
                decisionHandler(.allow)
                return
            }

            // 2. Safe-search enforcement. Search engines are exempt from
            // keyword blocking, so forcing their own strict mode is the only
            // guard against explicit results. The amended URL is compliant,
            // so the reload passes straight through on re-entry.
            if isMainFrame,
               (navigationAction.request.httpMethod ?? "GET") == "GET",
               let enforced = Coordinator.safeSearchEnforcedURL(for: url) {
                Log.debug("[SafeBrowser] enforcing safe search on \(host)")
                decisionHandler(.cancel)
                DispatchQueue.main.async { webView.load(URLRequest(url: enforced)) }
                return
            }

            // 3. Search Engine Immunity (Never keyword-block search engines)
            let isSearchEngine = manager.isSearchEngine(host)

            let urlString = url.absoluteString.lowercased()

            // 4. Domain Blocking (Check if the entire domain is restricted)
            let isDomainBlocked = manager.hostMatches(host, anyDomainIn: manager.apiBlocklistSet)
                || (manager.customWebsitesEnabled
                    && manager.hostMatches(host, anyDomainIn: manager.customBlocklistSet))

            // 5. Keyword Blocking (Only if not a search engine)
            // Shared with the Safari content blocker via KeywordMatcher so both
            // engines block identically.
            var isKeywordBlocked = false
            if !isSearchEngine {
                isKeywordBlocked = KeywordMatcher.isBlocked(
                    url: urlString,
                    customKeywords: manager.customKeywordsEnabled ? manager.keywordBlocklist : []
                )
            }

            if isDomainBlocked || isKeywordBlocked {
                Log.debug("🚫 [SafeBrowser] BLOCKED: \(host) | Reason: \(isDomainBlocked ? "Domain" : "Keyword") | MainFrame: \(isMainFrame)")

                if isMainFrame {
                    // Only count and overlay main-page blocks — subframe blocks
                    // would inflate the count by dozens per page. The count is
                    // NOT identity-guarded (a background tab's block is still
                    // a real block); the overlay is.
                    manager.recordBlockedAttempt()
                    DispatchQueue.main.async {
                        guard webView === self.viewModel.activeWebView else { return }
                        self.viewModel.showBlock(for: host)
                    }
                }

                // Always cancel the restricted request
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        /// Returns `url` with the search engine's strict safe-search parameter
        /// applied, or nil when the URL already complies or isn't a search
        /// results page. Nil on the amended URL's re-entry is the loop guard.
        static func safeSearchEnforcedURL(for url: URL) -> URL? {
            guard let host = url.host?.lowercased(),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }
            let path = components.path.lowercased()
            var items = components.queryItems ?? []

            func value(of name: String) -> String? {
                items.first(where: { $0.name == name })?.value
            }
            func matches(_ domain: String) -> Bool {
                host == domain || host.hasSuffix(".\(domain)")
            }
            func enforce(_ name: String, _ required: String) -> URL? {
                guard value(of: name) != required else { return nil }
                items.removeAll { $0.name == name }
                items.append(URLQueryItem(name: name, value: required))
                components.queryItems = items
                return components.url
            }

            if matches("google.com"), path.hasPrefix("/search"), value(of: "q") != nil {
                return enforce("safe", "active")
            }
            if matches("bing.com"),
               path.hasPrefix("/search") || path.hasPrefix("/images/search") || path.hasPrefix("/videos/search"),
               value(of: "q") != nil {
                return enforce("adlt", "strict")
            }
            if matches("duckduckgo.com"), value(of: "q") != nil {
                return enforce("kp", "1")
            }
            if host.hasSuffix("search.yahoo.com"), value(of: "p") != nil {
                return enforce("vm", "r")
            }
            if matches("ecosia.org"), path.hasPrefix("/search"), value(of: "q") != nil {
                return enforce("safesearch", "2")
            }
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                guard webView === self.viewModel.activeWebView else { return }
                self.viewModel.isBlocked = false
                self.viewModel.loadError = nil
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleLoadError(webView, error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadError(webView, error)
        }

        /// With multiple live webviews, iOS reclaims background WebContent
        /// processes under memory pressure — without this, switching back to
        /// a reclaimed tab would show a permanently blank page.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Log.debug("[SafeBrowser] WebContent process terminated — reloading")
            webView.reload()
        }

        /// Surfaces genuine load failures (offline, DNS, bad TLS). Our own
        /// `decidePolicyFor` cancels also land here — as NSURLErrorCancelled
        /// or WebKit error 102 (frame load interrupted) — and must be ignored
        /// or every block would show a network-error overlay.
        private func handleLoadError(_ webView: WKWebView, _ error: Error) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
            let message = nsError.localizedDescription
            DispatchQueue.main.async {
                guard webView === self.viewModel.activeWebView else { return }
                self.viewModel.isLoading = false
                self.viewModel.loadError = message
            }
        }

        // MARK: WKUIDelegate

        /// `window.open` / `target="_blank"` links previously did nothing.
        /// Load them in the same webview — the load re-enters
        /// `decidePolicyFor`, so blocking still applies to popups.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - ViewModel

@MainActor
class SafeBrowserViewModel: ObservableObject {
    @Published var currentURL = ""
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var estimatedProgress: Double = 0
    @Published var isBlocked = false
    @Published var blockedDomain = ""
    /// Human-readable description of the last load failure; nil when none.
    @Published var loadError: String?

    // MARK: - Tabs

    @Published var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID?

    /// Live webviews, one per *activated* tab. Restored-but-untouched tabs
    /// hold only their serialized `interactionState` and cost nothing.
    private var liveWebViews: [UUID: WKWebView] = [:]
    private var observations: [UUID: [NSKeyValueObservation]] = [:]
    /// Least-recently-activated order, for the live-webview cap.
    private var activationOrder: [UUID] = []
    /// Guards saves until the restore task has published the session —
    /// otherwise a fast background at launch would wipe the saved tabs.
    private var hasRestored = false
    private var saveTask: Task<Void, Never>?
    private let store = BrowserTabStore()
    private var resignActiveObserver: NSObjectProtocol?

    /// Max live webviews kept in memory; least-recently-used background tabs
    /// are serialized back into their model and dropped.
    private let maxLiveWebViews = 4

    var activeWebView: WKWebView? {
        guard let id = activeTabID else { return nil }
        return liveWebViews[id]
    }

    init() {
        // SafeBrowserView may not be the visible tab when the app backgrounds,
        // so the session save hangs off the app lifecycle, not scenePhase.
        resignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.saveNow() }
        }
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.store.load()
            self.applyRestoredSession(snapshot)
        }
    }

    deinit {
        if let resignActiveObserver {
            NotificationCenter.default.removeObserver(resignActiveObserver)
        }
    }

    private func applyRestoredSession(_ snapshot: TabSessionSnapshot?) {
        if let snapshot, !snapshot.tabs.isEmpty {
            tabs = snapshot.tabs
            if let active = snapshot.activeTabID, tabs.contains(where: { $0.id == active }) {
                activeTabID = active
            } else {
                activeTabID = tabs.first?.id
            }
            currentURL = tabs.first(where: { $0.id == activeTabID })?.urlString ?? ""
        } else {
            let tab = BrowserTab()
            tabs = [tab]
            activeTabID = tab.id
            currentURL = tab.urlString
        }
        hasRestored = true
        Log.debug("SafeBrowser: session ready — \(tabs.count) tabs")
    }

    // MARK: Webview lifecycle

    /// Returns the live webview for a tab, creating and hydrating it on first
    /// activation. Called from `updateUIView` during a SwiftUI render pass —
    /// it must not mutate any `@Published` state synchronously.
    func webView(for tabID: UUID, coordinator: SafeWebView.Coordinator) -> WKWebView {
        if let existing = liveWebViews[tabID] { return existing }

        let config = WKWebViewConfiguration()
        // Only inject the blur/protect script for subscribed users.
        if SubscriptionManager.shared.isSubscribed {
            let script = WKUserScript(
                source: SafeBrowserViewModel.blurInjectionJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(script)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always

        liveWebViews[tabID] = webView
        observations[tabID] = makeObservations(for: webView, tabID: tabID)
        activationOrder.removeAll { $0 == tabID }
        activationOrder.append(tabID)
        evictIfNeeded(keeping: tabID)

        // Hydrate. A persisted blob restores the full back/forward history;
        // its restore is asynchronous and issues its own navigation, so a
        // simultaneous load() would race it.
        let tab = tabs.first { $0.id == tabID }
        if let state = tab?.interactionState {
            webView.interactionState = state
            let fallback = tab?.urlString
            DispatchQueue.main.async { [weak webView] in
                // Rejected/corrupt blob — fall back to a plain load.
                if let webView, webView.url == nil,
                   let url = URL(string: fallback ?? "https://www.google.com") {
                    webView.load(URLRequest(url: url))
                }
            }
        } else if let url = URL(string: tab?.urlString ?? "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    private func makeObservations(for webView: WKWebView, tabID: UUID) -> [NSKeyValueObservation] {
        // Background tabs keep navigating (JS timers, redirects), so pushes of
        // *visible* state are identity-guarded; per-tab data (url/title on the
        // tab model) always updates. All closures [weak self] — a strong
        // capture would cycle viewModel → token → closure → viewModel.
        [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                let value = wv.estimatedProgress
                DispatchQueue.main.async {
                    guard let self, wv === self.activeWebView else { return }
                    self.estimatedProgress = value
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                let value = wv.isLoading
                DispatchQueue.main.async {
                    guard let self, wv === self.activeWebView else { return }
                    self.isLoading = value
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                let value = wv.canGoBack
                DispatchQueue.main.async {
                    guard let self, wv === self.activeWebView else { return }
                    self.canGoBack = value
                }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                let value = wv.canGoForward
                DispatchQueue.main.async {
                    guard let self, wv === self.activeWebView else { return }
                    self.canGoForward = value
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                let value = wv.url?.absoluteString ?? ""
                DispatchQueue.main.async {
                    guard let self else { return }
                    if !value.isEmpty, let idx = self.tabs.firstIndex(where: { $0.id == tabID }) {
                        self.tabs[idx].urlString = value
                    }
                    if wv === self.activeWebView { self.currentURL = value }
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                let value = wv.title
                DispatchQueue.main.async {
                    guard let self, let value, !value.isEmpty,
                          let idx = self.tabs.firstIndex(where: { $0.id == tabID }) else { return }
                    self.tabs[idx].title = value
                }
            }
        ]
    }

    /// Drops the least-recently-activated background webview once the live
    /// count exceeds the cap, banking its session state into the tab model.
    private func evictIfNeeded(keeping keptID: UUID) {
        guard liveWebViews.count > maxLiveWebViews else { return }
        let candidates = activationOrder.filter { $0 != keptID && $0 != activeTabID }
        guard let victim = candidates.first, let webView = liveWebViews[victim] else { return }

        let state = webView.interactionState as? Data
        observations[victim]?.forEach { $0.invalidate() }
        observations[victim] = nil
        liveWebViews[victim] = nil
        activationOrder.removeAll { $0 == victim }
        // Deferred: this runs from `webView(for:)` inside a render pass, and
        // `tabs` is @Published.
        DispatchQueue.main.async { [weak self] in
            guard let self, let state,
                  let idx = self.tabs.firstIndex(where: { $0.id == victim }) else { return }
            self.tabs[idx].interactionState = state
        }
        Log.debug("SafeBrowser: evicted webview for background tab")
    }

    // MARK: Tab operations

    func activateTab(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }), id != activeTabID else { return }
        // Bank the outgoing tab's session state while its webview is alive.
        captureInteractionState(for: activeTabID)
        activeTabID = id
        activationOrder.removeAll { $0 == id }
        activationOrder.append(id)

        // Overlays are transient feedback about the visible tab's latest
        // navigation — blocked navigations were cancelled, so the page
        // underneath is intact.
        isBlocked = false
        loadError = nil

        if let webView = liveWebViews[id] {
            currentURL = webView.url?.absoluteString
                ?? tabs.first(where: { $0.id == id })?.urlString ?? ""
            isLoading = webView.isLoading
            canGoBack = webView.canGoBack
            canGoForward = webView.canGoForward
            estimatedProgress = webView.estimatedProgress
        } else {
            // Not hydrated yet — `updateUIView` will build it on next render.
            currentURL = tabs.first(where: { $0.id == id })?.urlString ?? ""
            isLoading = false
            canGoBack = false
            canGoForward = false
            estimatedProgress = 0
        }
        scheduleSave()
    }

    func newTab() {
        let tab = BrowserTab()
        tabs.append(tab)
        activateTab(tab.id)
    }

    /// Activates the neighbor tab (`+1` next, `-1` previous); clamps at the
    /// ends. Drives the swipe-on-address-bar gesture.
    func activateAdjacentTab(_ delta: Int) {
        guard let current = activeTabID,
              let idx = tabs.firstIndex(where: { $0.id == current }) else { return }
        let target = idx + delta
        guard tabs.indices.contains(target) else { return }
        activateTab(tabs[target].id)
    }

    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        observations[id]?.forEach { $0.invalidate() }
        observations[id] = nil
        liveWebViews[id] = nil
        activationOrder.removeAll { $0 == id }
        tabs.remove(at: idx)

        if tabs.isEmpty {
            newTab()
        } else if activeTabID == id {
            activateTab(tabs[min(max(idx - 1, 0), tabs.count - 1)].id)
        }
        scheduleSave()
    }

    /// Closes every tab and starts over with a single fresh one.
    func closeAllTabs() {
        for id in tabs.map(\.id) {
            observations[id]?.forEach { $0.invalidate() }
            observations[id] = nil
            liveWebViews[id] = nil
        }
        activationOrder.removeAll()
        tabs.removeAll()
        newTab()
    }

    // MARK: Persistence

    private func captureInteractionState(for id: UUID?) {
        guard let id, let webView = liveWebViews[id],
              let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        if let state = webView.interactionState as? Data {
            tabs[idx].interactionState = state
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        guard hasRestored else { return }
        for id in liveWebViews.keys { captureInteractionState(for: id) }
        let snapshot = TabSessionSnapshot(activeTabID: activeTabID, tabs: tabs)
        Task { [store] in await store.save(snapshot) }
    }

    // MARK: Navigation (active tab)

    func navigate(to url: URL) {
        isBlocked = false
        loadError = nil
        activeWebView?.load(URLRequest(url: url))
    }

    func goBack() {
        isBlocked = false
        loadError = nil
        activeWebView?.goBack()
    }

    func goForward() {
        isBlocked = false
        loadError = nil
        activeWebView?.goForward()
    }

    func reload() {
        loadError = nil
        activeWebView?.reload()
    }

    func stopLoading() {
        activeWebView?.stopLoading()
        isLoading = false
    }

    func showBlock(for domain: String) {
        isBlocked = true
        blockedDomain = domain
        isLoading = false
    }

    // MARK: - JavaScript Injection

    static let blurInjectionJS: String = """
    (function() {
        'use strict';

        const ADULT_PATTERNS = [
            /porn/i, /xxx/i, /xvideos/i, /xnxx/i, /xhamster/i,
            /pornhub/i, /redtube/i, /youporn/i, /tube8/i,
            /spankbang/i, /chaturbate/i, /onlyfans/i, /brazzers/i,
            /hentai/i, /erotic/i, /nude/i, /naked/i, /sex\\.com/i,
            /adult/i, /fetish/i, /bdsm/i
        ];

        const ADULT_CLASS_PATTERNS = [
            'thumb', 'preview', 'gallery-item', 'video-thumb',
            'adult', 'porn', 'xxx', 'nude', 'nsfw'
        ];

        const currentURL = window.location.href;
        const isAdultPage = ADULT_PATTERNS.some(p => p.test(currentURL));

        if (!isAdultPage) return;

        const style = document.createElement('style');
        style.id = 'purepath-protection';
        style.textContent = `
            img, video, picture, canvas, embed, object {
                filter: blur(20px) !important;
                pointer-events: none !important;
            }
            ${ADULT_CLASS_PATTERNS.map(c => `[class*="${c}"]`).join(', ')} {
                display: none !important;
            }
            iframe { display: none !important; }
        `;

        const insertStyles = () => {
            const head = document.head || document.documentElement;
            if (head && !document.getElementById('purepath-protection')) {
                head.insertBefore(style, head.firstChild);
            }
        };

        insertStyles();

        const observer = new MutationObserver((mutations) => {
            insertStyles();
            mutations.forEach(m => {
                m.addedNodes.forEach(node => {
                    if (node.nodeType === 1) {
                        const el = node;
                        if (el.tagName === 'IMG' || el.tagName === 'VIDEO') {
                            el.style.cssText += 'filter: blur(20px) !important; pointer-events: none !important;';
                        }
                    }
                });
            });
        });

        observer.observe(document.documentElement, { childList: true, subtree: true });

    })();
    """
}

#Preview {
    SafeBrowserView()
}
