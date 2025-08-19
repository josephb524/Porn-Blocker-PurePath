//
//  PrivacyPolicyView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("📜 Privacy Policy for Porn Blocker: PurePath")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 8)
                    
                    Text("Effective Date: August 15, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                    
                    Text("Thank you for choosing Porn Blocker: PurePath (“the App”). Your privacy is very important to us. This Privacy Policy explains how our app handles information.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("Information We Do Not Collect")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("• Porn Blocker: PurePath does not collect, store, or share any personal data from users.")
                    Text("• We do not track your browsing activity or monitor your online behavior.")
                    Text("• All blocking functionality is performed locally on your device.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("In-App Purchases")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("• The App offers subscription plans through Apple’s In-App Purchase system.")
                    Text("• All payment processing and account management are handled directly by Apple.")
                    Text("• We do not have access to your payment information, Apple ID, or subscription details.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("Third-Party Services")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("• The App does not integrate third-party analytics, advertising, or tracking tools.")
                    Text("• The only third-party service involved is Apple App Store billing.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("Children’s Privacy")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("• Porn Blocker: PurePath is intended for users 4 years and older.")
                    Text("• We do not knowingly collect personal data from children.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("Changes to This Privacy Policy")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("• We may update this Privacy Policy from time to time.")
                    Text("• Updates will be posted within the App Store listing or inside the app.")
                    Text("• Your continued use of the app after updates indicates acceptance of the revised policy.")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                    
                    Text("Contact Us")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("If you have any questions or concerns about this Privacy Policy, you may contact us at:")
                    Text("📧 eltercerelias3@hotmail.com")
                        .padding(.bottom, 16)
                    
                    Text("⸻")
                        .padding(.vertical, 8)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
