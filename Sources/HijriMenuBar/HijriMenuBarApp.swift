import SwiftUI

@main
struct HijriMenuBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            CalendarView()
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabelView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(HijriDateUtils.menuBarString(for: now))
            .onReceive(timer) { now = $0 }
    }
}
