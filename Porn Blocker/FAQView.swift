//
//  FAQView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct FAQView: View {
    var body: some View {
        List {
            Text("Frequently Asked Questions")
                .font(.title2)
                .bold()
            
            Text("How does the app work?")
                .font(.headline)
            Text("The app uses Safari's content blocking feature to block adult content websites.")
            
            Text("Can I customize the blocklist?")
                .font(.headline)
            Text("Yes, you can add custom keywords and websites to block, as well as whitelist trusted sites.")
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
} 