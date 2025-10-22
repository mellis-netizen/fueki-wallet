import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WalletDashboardView()
                .tabItem {
                    Label("Wallet", systemImage: "wallet.pass.fill")
                }
                .tag(0)

            AssetsListView()
                .tabItem {
                    Label("Assets", systemImage: "chart.pie.fill")
                }
                .tag(1)

            ActivityView()
                .tabItem {
                    Label("Activity", systemImage: "clock.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppCoordinator())
            .environmentObject(WalletManager.shared)
    }
}
