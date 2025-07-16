import SwiftUI

struct StatisticCard: View {
    let title: String
    let count: Int
    let subtitle: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.title)
                .bold()
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
} 