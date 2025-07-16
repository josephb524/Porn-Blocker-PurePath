//
//  TermsView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct TermsView: View {
    var body: some View {
        ScrollView {
            Text("Terms of Use")
                .font(.title)
                .bold()
                .padding()
            
            Text("By using this app, you agree to the following terms...")
                .padding()
            
            Spacer()
        }
        .navigationTitle("Terms of Use")
        .navigationBarTitleDisplayMode(.inline)
    }
} 