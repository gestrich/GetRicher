import SwiftUI

struct ContentView: View {
    @Environment(SettingsModel.self) var settingsModel
    @AppStorage("selectedTab") private var selectedTab: String = "dashboard"

    var body: some View {
        VStack(spacing: 0) {
            if settingsModel.isDemoMode {
                DemoModeBanner()
            }
            TabView(selection: $selectedTab) {
                Tab("Dashboard", systemImage: "chart.bar.fill", value: "dashboard") {
                    CombinedView()
                }
                Tab("Weekly Paydown", systemImage: "creditcard.fill", value: "paydown") {
                    WeeklyPaydownView()
                }
            }
        }
    }
}

struct DemoModeBanner: View {
    var body: some View {
        Text("Demo Mode")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.orange)
    }
}
