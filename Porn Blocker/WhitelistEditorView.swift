import SwiftUI

struct WhitelistEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var newSite = ""
    @State private var showAddField = false
    
    var body: some View {
        NavigationView {
            List {
                if showAddField {
                    Section {
                        HStack {
                            TextField("e.g. example.com", text: $newSite)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                            Button("Add") {
                                let trimmed = newSite.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    blocklistManager.addToWhitelist(trimmed)
                                    newSite = ""
                                    showAddField = false
                                }
                            }
                            .disabled(newSite.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                
                Section {
                    if blocklistManager.whitelist.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No allowed sites yet")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                                Text("Sites you add here will never be blocked.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 24)
                            Spacer()
                        }
                    } else {
                        ForEach(blocklistManager.whitelist, id: \.self) { site in
                            Label(site, systemImage: "globe")
                                .font(.body)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                blocklistManager.removeFromWhitelist(blocklistManager.whitelist[index])
                            }
                        }
                    }
                } header: {
                    Text("Allowed Sites")
                } footer: {
                    Text("These sites will always load, even if they match a blocked keyword or domain.")
                }
            }
            .navigationTitle("Allowed Sites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { withAnimation { showAddField.toggle() } }) {
                        Image(systemName: showAddField ? "minus.circle.fill" : "plus.circle.fill")
                    }
                }
            }
        }
    }
}

#Preview {
    WhitelistEditorView()
}
