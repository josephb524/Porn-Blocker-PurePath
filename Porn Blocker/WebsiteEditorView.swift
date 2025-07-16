//
//  WebsiteEditorView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct WebsiteEditorView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var newWebsite = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("Enter website URL", text: $newWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Add") {
                        if !newWebsite.isEmpty {
                            blocklistManager.addToCustomBlocklist(newWebsite)
                            newWebsite = ""
                        }
                    }
                }
                .padding()
                
                List {
                    ForEach(blocklistManager.customBlocklist, id: \.self) { website in
                        Text(website)
                    }
                    .onDelete(perform: deleteWebsites)
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
    
    private func deleteWebsites(offsets: IndexSet) {
        for index in offsets {
            let website = blocklistManager.customBlocklist[index]
            blocklistManager.removeFromCustomBlocklist(website)
        }
    }
} 