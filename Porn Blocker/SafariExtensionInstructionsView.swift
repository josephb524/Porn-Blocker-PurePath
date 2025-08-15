import SwiftUI

struct SafariExtensionInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showGuide = false
    @State private var showSettingsError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    quickStartCard
                    stepsCard
                    tipCard
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showGuide) { SafariExtensionGuideView() }
        .alert("Could not open Settings", isPresented: $showSettingsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please open the Settings app manually, then follow the steps in the guide.")
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "safari")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.blue)
                .padding(12)
                .background(Color.blue.opacity(0.1), in: Circle())
            Text("Enable Safari Extension")
                .font(.title2)
                .bold()
            Text("Turn on the Porn Blocker extension in Safari to start blocking adult content.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick start")
                .font(.headline)
            VStack(spacing: 12) {
                Button {
                    openRootSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button {
                    showGuide = true
                } label: {
                    Label("Step-by-step guide", systemImage: "list.bullet.rectangle.portrait")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What to do")
                .font(.headline)
            StepRow(number: 1, title: "Open Settings", description: "Open the iPhone Settings app.")
            StepRow(number: 2, title: "Apps → Safari", description: "Scroll down, tap 'Apps', then choose 'Safari'.")
            StepRow(number: 3, title: "Extensions", description: "Tap 'Extensions' in the General section.")
            StepRow(number: 4, title: "Porn Blocker", description: "Select 'Porn Blocker' from the list.")
            StepRow(number: 5, title: "Allow Extension", description: "Toggle ON 'Allow Extension'.")
            StepRow(number: 6, title: "Private Browsing (optional)", description: "Toggle ON 'Allow in Private Browsing' if desired.")
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.title3)
            Text("After enabling, fully quit and reopen Safari to make sure the content blocker reloads its rules.")
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Settings Deep Link (root Settings with fallbacks)
    private func openRootSettings() {
        // Try known variants to land on the first Settings page; fall back to app settings.
        let candidates: [String] = [
            "App-Prefs:",
            "App-prefs:",
            "App-Prefs:root=General",
            "App-prefs:root=General",
            UIApplication.openSettingsURLString // at least opens Settings, even if app-specific
        ]
        openURLIfPossible(candidates)
    }
    
    private func openURLIfPossible(_ strings: [String]) {
        guard let first = strings.first, let url = URL(string: first) else {
            showSettingsError = true
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if !success {
                openURLIfPossible(Array(strings.dropFirst()))
            }
        }
    }
}

// Helper row
private struct StepRow: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(String(number))
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SafariExtensionGuideView: View {
    private struct GuideStep: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let description: String
        let imageName: String
    }
    
    private var steps: [GuideStep] {
        [
            GuideStep(number: 1, title: "Open Settings", description: "Open the iPhone Settings app.", imageName: "1"),
            GuideStep(number: 2, title: "Go to Apps", description: "Scroll down and tap 'Apps'.", imageName: "2"),
            GuideStep(number: 3, title: "Select Safari", description: "In Apps, tap 'Safari'.", imageName: "3"),
            GuideStep(number: 4, title: "Open Extensions", description: "Scroll to the General section and tap 'Extensions'.", imageName: "4"),
            GuideStep(number: 5, title: "Choose Porn Blocker", description: "Tap 'Porn Blocker' from the list (it may show Off).", imageName: "5"),
            GuideStep(number: 6, title: "Enable Extension", description: "Toggle 'Allow Extension' to ON.", imageName: "6"),
            GuideStep(number: 7, title: "All Set", description: "Return to Safari and browse—adult content will now be blocked.", imageName: "7")
        ]
    }
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(steps) { step in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("Step \(step.number)")
                                    .font(.headline)
                                    .bold()
                                Text(step.title)
                                    .font(.headline)
                            }
                            Text(step.description)
                                .foregroundColor(.secondary)
                            
                            Image(step.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
//                                .overlay(
//                                    RoundedRectangle(cornerRadius: 12)
//                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
//                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Step-by-step guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 

