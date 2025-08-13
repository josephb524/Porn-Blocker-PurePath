import SwiftUI

struct SafariExtensionInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showGuide = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Enable Safari Extension")
                        .font(.title)
                        .bold()
                    
                    Text("To start blocking websites, you need to enable the Porn Blocker extension in Safari:")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        InstructionStep(
                            number: "1",
                            title: "Open Safari Settings",
                            description: "Go to Safari app → Settings → Extensions"
                        )
                        
                        InstructionStep(
                            number: "2",
                            title: "Find Porn Blocker",
                            description: "Look for 'Porn Blocker' in the list of extensions"
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Enable Extension",
                            description: "Toggle ON the Porn Blocker extension"
                        )
                        
                        InstructionStep(
                            number: "4",
                            title: "Grant Permissions",
                            description: "Allow the extension to access all websites"
                        )
                    }
                    
                    Text("Once enabled, the extension will automatically block adult content websites and keywords while you browse.")
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Button("Open Safari Settings") {
                        if let url = URL(string: "App-prefs:SAFARI") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.top)
                    
                    Button {
                        showGuide = true
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle.portrait")
                            Text("Step-by-step guide")
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Setup Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            SafariExtensionGuideView()
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
            GuideStep(number: 3, title: "Select Safari", description: "In Apps, tap 'Safari'.", imageName: "4"),
            GuideStep(number: 4, title: "Open Extensions", description: "Scroll to the General section and tap 'Extensions'.", imageName: "6"),
            GuideStep(number: 5, title: "Choose Porn Blocker", description: "Tap 'Porn Blocker' from the list (it may show Off).", imageName: "7"),
            GuideStep(number: 6, title: "Enable Extension", description: "Toggle 'Allow Extension' to ON.", imageName: "9"),
//            GuideStep(number: 7, title: "Allow Private Browsing (optional)", description: "Toggle 'Allow in Private Browsing' if you want protection there too.", imageName: "8"),
//            GuideStep(number: 8, title: "Verify Permissions", description: "Ensure the permission note appears—this is expected for content blockers.", imageName: "9"),
//            GuideStep(number: 9, title: "All Set", description: "Return to Safari and browse—adult content will now be blocked.", imageName: "")
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
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

