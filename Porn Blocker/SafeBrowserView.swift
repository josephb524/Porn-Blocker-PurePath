import SwiftUI
import WebKit

// MARK: - Safe Browser View

struct SafeBrowserView: View {
    @StateObject private var viewModel = SafeBrowserViewModel()
    @StateObject private var subManager = SubscriptionManager.shared
    @State private var addressText = ""
    @State private var isEditingAddress = false
    @State private var showPaywall = false
    @FocusState private var addressFocused: Bool

    var body: some View {
        if subManager.isSubscribed {
            browserView
        } else {
            lockedView
        }
    }

    // MARK: - Locked Gate (non-subscribers)

    private var lockedView: some View {
        NavigationView {
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

                        Text("7-day free trial · Cancel anytime")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showPaywall) {
                NavigationView {
                    PaywallScreen(isPresented: $showPaywall)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Browser (subscribers only)

    private var browserView: some View {
        NavigationView {
            VStack(spacing: 0) {
                addressBar

                if viewModel.isLoading {
                    ProgressView(value: viewModel.estimatedProgress)
                        .progressViewStyle(.linear)
                        .tint(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))
                        .frame(height: 2)
                }

                ZStack {
                    SafeWebView(viewModel: viewModel)
                        .ignoresSafeArea(edges: .bottom)

                    if viewModel.isBlocked {
                        BlockedOverlayView(domain: viewModel.blockedDomain) {
                            viewModel.goBack()
                        }
                        .transition(.opacity)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { addressText = viewModel.currentURL }
            .onChange(of: viewModel.currentURL) { url in
                if !isEditingAddress { addressText = url }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Address Bar

    private var addressBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 15))
                .foregroundColor(Color(hue: 0.38, saturation: 0.65, brightness: 0.5))

            HStack {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Search or enter website", text: $addressText, onCommit: {
                    navigateTo(addressText)
                    isEditingAddress = false
                    addressFocused = false
                })
                .font(.system(size: 15))
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($addressFocused)
                .onTapGesture {
                    isEditingAddress = true
                    addressFocused = true
                }

                if !addressText.isEmpty && isEditingAddress {
                    Button(action: { addressText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            HStack(spacing: 16) {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.canGoBack ? .primary : .secondary)
                }
                .disabled(!viewModel.canGoBack)

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(viewModel.canGoForward ? .primary : .secondary)
                }
                .disabled(!viewModel.canGoForward)

                Button(action: {
                    viewModel.isLoading ? viewModel.stopLoading() : viewModel.reload()
                }) {
                    Image(systemName: viewModel.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
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

                    Text("This website has been blocked by PurePath because it contains adult content.")
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

// MARK: - WKWebView Representable

struct SafeWebView: UIViewRepresentable {
    @ObservedObject var viewModel: SafeBrowserViewModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Only inject the blur/protect script for subscribed users
        if SubscriptionManager.shared.isSubscribed {
            let script = WKUserScript(
                source: SafeBrowserViewModel.blurInjectionJS,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(script)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always

        viewModel.webView = webView

        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
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

            // Only block if the user has an active subscription
            guard SubscriptionManager.shared.isSubscribed else {
                decisionHandler(.allow)
                return
            }

            let allBlockedDomains = Set(manager.apiBlocklist + manager.customBlocklist)
            let allKeywords = manager.predefinedKeywords + manager.keywordBlocklist
            let whitelist = Set(manager.whitelist)

            if whitelist.contains(where: { host.contains($0) }) {
                decisionHandler(.allow)
                return
            }

            let urlString = url.absoluteString.lowercased()
            let isDomainBlocked = allBlockedDomains.contains(where: { host.contains($0) || $0.contains(host) })
            let isKeywordBlocked = allKeywords.contains(where: { urlString.contains($0.lowercased()) })

            if isDomainBlocked || isKeywordBlocked {
                DispatchQueue.main.async { self.viewModel.showBlock(for: host) }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.isLoading = true
                self.viewModel.isBlocked = false
                self.viewModel.estimatedProgress = 0.1
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.isLoading = false
                self.viewModel.estimatedProgress = 1.0
                self.viewModel.currentURL = webView.url?.absoluteString ?? ""
                self.viewModel.canGoBack = webView.canGoBack
                self.viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.viewModel.isLoading = false
                self.viewModel.estimatedProgress = 0
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.viewModel.estimatedProgress = 0.6
                self.viewModel.currentURL = webView.url?.absoluteString ?? ""
                self.viewModel.canGoBack = webView.canGoBack
                self.viewModel.canGoForward = webView.canGoForward
            }
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

    weak var webView: WKWebView?

    func navigate(to url: URL) {
        isBlocked = false
        webView?.load(URLRequest(url: url))
    }

    func goBack() {
        isBlocked = false
        webView?.goBack()
    }

    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }

    func stopLoading() {
        webView?.stopLoading()
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
