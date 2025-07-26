//
//  KeywordEditorView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct KeywordEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var newKeyword = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter keyword", text: $newKeyword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !newKeyword.isEmpty {
                            blocklistManager.addToKeywordBlocklist(newKeyword)
                            newKeyword = ""
                        }
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
