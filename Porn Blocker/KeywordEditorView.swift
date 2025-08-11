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
    @State private var showingSuccessMessage = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter keyword", text: $newKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            addKeyword()
                        }
                    Button("Add") {
                        addKeyword()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newKeyword.isEmpty)
                }
                .padding()
                
                if showingSuccessMessage {
                    Text("Keyword added successfully!")
                        .foregroundColor(.green)
                        .font(.caption)
                        .transition(.opacity)
                }
                
                List {
                    ForEach(blocklistManager.keywordBlocklist, id: \.self) { keyword in
                        Text(keyword)
                            .foregroundColor(.primary)
                    }
                    .onDelete(perform: deleteKeywords)
                }
                
                if !subscriptionManager.isSubscribed {
                    Text("Custom keywords will be blocked only with an active subscription")
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
        }
    }
    
    private func addKeyword() {
        guard !newKeyword.isEmpty else { return }
        let originalCount = blocklistManager.keywordBlocklist.count
        blocklistManager.addToKeywordBlocklist(newKeyword)
        
        if blocklistManager.keywordBlocklist.count > originalCount {
            newKeyword = ""
            withAnimation { showingSuccessMessage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showingSuccessMessage = false }
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
