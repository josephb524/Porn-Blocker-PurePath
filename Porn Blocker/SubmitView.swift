import SwiftUI

struct SubmitView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Blacklist Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        Text("Blacklist")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Submit keywords and website that you want to Blacklist (which you feel are not blocked but should be). We will review these and once approved, you will be able to browse them online without any interference.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Whitelist Section
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                        Text("Whitelist")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    Text("Submit the keywords and website that you want to whitelist (which you feel is blocked accidentally or unintentionally). We will review these and once approved, you will be able to browse them online without any interference.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationTitle("Submit keywords & websites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
} 