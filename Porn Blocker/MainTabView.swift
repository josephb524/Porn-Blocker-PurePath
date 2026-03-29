import SwiftUI

struct MainTabView: View {
    @StateObject private var blocklistManager = BlocklistManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "shield.fill")
                    Text("Protection")
                }
                .tag(0)
            
            StatsView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Streaks")
                }
                .tag(1)
            
            SafeBrowserView()
                .tabItem {
                    Image(systemName: "safari.fill")
                    Text("Safe Browse")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
}
