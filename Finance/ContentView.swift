import SwiftUI

struct ContentView: View {
    var body: some View {
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
