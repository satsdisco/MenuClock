import SwiftUI

@main
struct MenuClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var ticker = ClockTicker.shared
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var weatherManager = WeatherManager.shared

    var body: some Scene {
        MenuBarExtra {
            DropdownView()
                .environmentObject(settings)
                .environmentObject(ticker)
                .environmentObject(calendarManager)
                .environmentObject(weatherManager)
        } label: {
            MenuBarTitleView()
        }
        .menuBarExtraStyle(.window)

        Window("MenuClock Settings", id: "settings") {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(weatherManager)
                .environmentObject(ticker)
                .environmentObject(calendarManager)
        }
        .windowResizability(.contentSize)
    }
}
