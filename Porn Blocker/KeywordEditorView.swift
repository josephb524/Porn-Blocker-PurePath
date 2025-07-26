//
//  KeywordEditorView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct KeywordEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var newKeyword = ""
    @State private var showingSubscriptionAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter keyword", text: $newKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        addKeyword()
                    }
                }
                .padding()
                
                List {
                    ForEach(blocklistManager.keywordBlocklist, id: \.self) { keyword in
                        Text(keyword)
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteKeywords)
                }
                
                if !subscriptionManager.isSubscribed {
                    Text("Custom keywords require a subscription")
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .padding()
                }
            }
            .navigationTitle("Custom Keywords")
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
                Text("A subscription is required to add custom keywords.")
            }
        }
    }
    
    private func addKeyword() {
        if !newKeyword.isEmpty {
            if subscriptionManager.isSubscribed {
                let originalCount = blocklistManager.keywordBlocklist.count
                blocklistManager.addToKeywordBlocklist(newKeyword)
                
                // Only clear the text field if the keyword was actually added
                if blocklistManager.keywordBlocklist.count > originalCount {
                    newKeyword = ""
                }
            } else {
                showingSubscriptionAlert = true
            }
        }
    }
    
    private func deleteKeywords(offsets: IndexSet) {
        for index in offsets {
            let keyword = blocklistManager.keywordBlocklist[index]
            blocklistManager.removeFromKeywordBlocklist(keyword)
        }
    }
} 

#Preview {
    KeywordEditorView()
}
