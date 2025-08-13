import SwiftUI

struct BlockerSettingsView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var showKeywordEditor = false
    @State private var showWebsiteEditor = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Custom Keywords Section
            VStack(spacing: 16) {
                HStack {
                    Text("Custom Keywords")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Edit") {
                        showKeywordEditor = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
                
                HStack {
                    Text("Total: \(blocklistManager.keywordBlocklist.count)")
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                .padding(.horizontal)
                
                Text("You can specify a keyword and the domains including this keyword will be blocked")
                    .foregroundColor(.primary)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            
            // Custom Websites Section
            VStack(spacing: 16) {
                HStack {
                    Text("Custom Websites")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Edit") {
                        showWebsiteEditor = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray5))
                .cornerRadius(12)
                
                HStack {
                    Text("Total: \(blocklistManager.customBlocklist.count)")
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .navigationTitle("Extension Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showKeywordEditor) {
            KeywordEditorView()
        }
        .sheet(isPresented: $showWebsiteEditor) {
            WebsiteEditorView()
        }
    }
} 

#Preview {
    BlockerSettingsView()
}
