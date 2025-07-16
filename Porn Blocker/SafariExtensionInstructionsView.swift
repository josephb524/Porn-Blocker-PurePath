import SwiftUI

struct SafariExtensionInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
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
    }
} 