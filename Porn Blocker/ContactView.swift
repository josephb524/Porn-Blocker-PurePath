//
//  ContactView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct ContactView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Contact Us")
                .font(.title)
                .bold()
            
            Text("If you have any questions or need support, please contact us:")
            
            Button("Email Support") {
                if let url = URL(string: "mailto:support@pornblocker.com") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
} 