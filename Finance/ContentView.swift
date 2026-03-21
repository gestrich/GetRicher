import SwiftUI

struct ContentView: View {
    @Environment(SettingsModel.self) var settingsModel

    var body: some View {
        VStack(spacing: 0) {
            if settingsModel.isDemoMode {
                DemoModeBanner()
            }
            TabView {
                Tab("Dashboard", systemImage: "chart.bar.fill") {
                    CombinedView()
                }
                Tab("Weekly Paydown", systemImage: "creditcard.fill") {
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
