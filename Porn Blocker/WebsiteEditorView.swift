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
    @State private var showingSubscriptionAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter website URL", text: $newWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        addWebsite()
                    }
                }
                .padding()
                
                List {
                    ForEach(blocklistManager.customBlocklist, id: \.self) { website in
                        Text(website)
                    }
                    .onDelete(perform: deleteWebsites)
                }
                
                if !subscriptionManager.isSubscribed {
                    Text("Custom websites require a subscription")
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
            .alert("Subscription Required", isPresented: $showingSubscriptionAlert) {
                Button("OK") { }
            } message: {
                Text("A subscription is required to add custom websites.")
            }
        }
    }
    
    private func addWebsite() {
        if !newWebsite.isEmpty {
            if subscriptionManager.isSubscribed {
                let originalCount = blocklistManager.customBlocklist.count
                blocklistManager.addToCustomBlocklist(newWebsite)
                
                // Only clear the text field if the website was actually added
                if blocklistManager.customBlocklist.count > originalCount {
                    newWebsite = ""
                }
            } else {
                showingSubscriptionAlert = true
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