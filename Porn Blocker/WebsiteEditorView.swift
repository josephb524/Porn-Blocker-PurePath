//
//  WebsiteEditorView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct WebsiteEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var newWebsite = ""
    @State private var showingSuccessMessage = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter website URL", text: $newWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addWebsite()
                        }
                    Button("Add") {
                        addWebsite()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newWebsite.isEmpty)
                }
                .padding()
                
                if showingSuccessMessage {
                    Text("Website added successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                
                List {
                    ForEach(blocklistManager.customBlocklist, id: \.self) { website in
                        Text(website)
                    }
                    .onDelete(perform: deleteWebsites)
                }
                
                if !subscriptionManager.isSubscribed {
                    Text("Custom websites will be blocked only with an active subscription")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Custom Websites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addWebsite() {
        guard !newWebsite.isEmpty else { return }
        let originalCount = blocklistManager.customBlocklist.count
        blocklistManager.addToCustomBlocklist(newWebsite)
        
        if blocklistManager.customBlocklist.count > originalCount {
            newWebsite = ""
            withAnimation { showingSuccessMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showingSuccessMessage = false }
            }
        }
    }
    
    private func deleteWebsites(offsets: IndexSet) {
        for index in offsets {
            let website = blocklistManager.customBlocklist[index]
            blocklistManager.removeFromCustomBlocklist(website)
        }
    }
} 