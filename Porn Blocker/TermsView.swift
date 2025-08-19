//
//  TermsView.swift
//  Porn Blocker
//
//  Created by Jose Pimentel on 6/5/23.
//

import SwiftUI

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Use (EULA) — Porn Blocker: PurePath")
                        .font(.title)
                        .bold()
                        .padding(.bottom, 8)
                    
                    Text("Effective date: August 15, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                    
                    Text("By downloading, installing, or using Porn Blocker: PurePath (the “App”), you agree to these Terms of Use (“Terms”). If you do not agree, do not use the App. These Terms supplement and incorporate Apple’s Licensed Application End User License Agreement (“Apple Standard EULA”). Where a conflict exists, these Terms control to the extent permitted by law.")
                        .padding(.bottom, 16)
                    
                    Text("Apple Standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                        .foregroundColor(.blue)
                        .padding(.bottom, 16)
                    
                    Text("1. License")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("We grant you a personal, limited, non‑transferable, non‑exclusive license to install and use the App on Apple devices you own or control, strictly as permitted by these Terms and the Apple Standard EULA.")
                    Text("All rights not expressly granted are reserved by the developer.")
                        .padding(.bottom, 16)
                    
                    Text("2. Intended Use; Important Limitations")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("The App is a Safari content‑blocking and parental‑control tool designed to help block access to adult websites and other URLs you configure.")
                    Text("The App does not inspect or analyze the content of pages beyond the capabilities provided by Safari content blocking. It does not guarantee that all unwanted material will be blocked in every circumstance.")
                    Text("The App is not medical, psychological, or therapeutic advice and is not a substitute for professional care. If you are seeking help with addiction or mental health, consult a qualified professional.")
                    Text("Parents/guardians are responsible for device settings, Screen Time restrictions, and supervising minors’ use of the device and the internet.")
                        .padding(.bottom, 16)
                    
                    Text("3. Account, Eligibility, and Family Sharing")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("You must be legally able to enter into this agreement to use the App.")
                    Text("If you enable Family Sharing or install for a minor, you represent that you are the parent/guardian and will supervise use.")
                        .padding(.bottom, 16)
                    
                    Text("4. Subscription; Billing; Auto‑Renewal")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("All blocking features require a paid subscription.")
                    Text("Pricing: $39.99 per year (or the local price shown in the App Store, determined by Apple’s currency matrix).")
                    Text("Payment is charged to your Apple ID at purchase. Subscriptions renew automatically unless auto‑renew is turned off at least 24 hours before the current period ends. Your account is charged for renewal within 24 hours prior to the end of the period.")
                    Text("Manage or cancel in iOS Settings → Apple ID → Subscriptions. The current period cannot be canceled once started. Any unused portion of a free trial (if offered) is forfeited upon purchase.")
                        .padding(.bottom, 16)
                    
                    Text("5. Privacy")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("Your use is subject to our Privacy Policy: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/")
                    Text("We follow platform best practices for data access and do not sell personal data. See the Privacy Policy for full details.")
                        .padding(.bottom, 16)
                    
                    Text("6. User Configuration and Content")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("You are responsible for any custom keywords, domains, or rules you add. Do not use the App to block content unlawfully or to infringe third‑party rights.")
                        .padding(.bottom, 16)
                    
                    Text("7. Prohibited Conduct")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("Do not:")
                    Text("Circumvent security or misuse the App.")
                    Text("Reverse engineer, modify, or redistribute the App except as allowed by law.")
                    Text("Use the App where prohibited by law or to monitor individuals without their knowledge or lawful authority.")
                        .padding(.bottom, 16)
                    
                    Text("8. Service Changes and Availability")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("Features may change or be discontinued. We may update block lists, rules, and the App from time to time. Some features require an active internet connection and compatible Safari/iOS versions.")
                        .padding(.bottom, 16)
                    
                    Text("9. Disclaimers")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("The App is provided “as is” and “as available,” without warranties of any kind, express or implied, including fitness for a particular purpose and non‑infringement.")
                    Text("We do not guarantee that all adult or unwanted content will be blocked in all cases, or that the App will be error‑free or uninterrupted.")
                        .padding(.bottom, 16)
                    
                    Text("10. Limitation of Liability")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("To the maximum extent permitted by law, we and our affiliates will not be liable for indirect, incidental, special, consequential, or punitive damages, or any loss of profits, data, reputation, or goodwill, arising from use of the App.")
                    Text("Our total liability for any claim will not exceed the amount you paid for the current subscription period.")
                        .padding(.bottom, 16)
                    
                    Text("11. Indemnification")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("You agree to indemnify and hold us harmless from claims, damages, liabilities, and expenses arising from your misuse of the App or violation of these Terms.")
                        .padding(.bottom, 16)
                    
                    Text("12. Termination")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("We may suspend or terminate access if you violate these Terms. You may stop using the App at any time; deletion does not automatically cancel your subscription—manage it in Apple ID settings.")
                        .padding(.bottom, 16)
                    
                    Text("13. Third‑Party Terms")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("Your use of Safari and iOS is subject to Apple’s terms. Network or device restrictions imposed by schools, workplaces, or ISPs may affect performance.")
                        .padding(.bottom, 16)
                    
                    Text("14. Governing Law and Dispute Resolution")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("These Terms are governed by the laws of the United States, without regard to conflict‑of‑law principles. Courts located in the United States will have exclusive jurisdiction, unless mandatory local law provides otherwise. If you are an EU/UK consumer, you may benefit from mandatory local consumer protections.")
                        .padding(.bottom, 16)
                    
                    Text("15. Changes to Terms")
                        .font(.headline)
                        .padding(.bottom, 4)
                    Text("We may update these Terms from time to time. Material changes will be communicated via the App or the App Store listing. Continued use after the effective date constitutes acceptance.")
                        .padding(.bottom, 16)
                    
                    Text("16. Contact")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Text("By using Porn Blocker: PurePath, you acknowledge that you have read and agree to these Terms, the Apple Standard EULA, and our Privacy Policy.")
                        .padding(.bottom, 16)
                }
                .padding()
            }
            .navigationTitle("Terms of Use")
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
