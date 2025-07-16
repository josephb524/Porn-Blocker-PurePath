//
//  PrivacyPolicyView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text("Privacy Policy")
                .font(.title)
                .bold()
                .padding()
            
            Text("Your privacy is important to us. This app does not collect any personal information...")
                .padding()
            
            Spacer()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
} 