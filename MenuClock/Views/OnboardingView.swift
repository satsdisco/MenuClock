import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var calendarManager: CalendarManager
    @EnvironmentObject var weatherManager: WeatherManager

    let onComplete: () -> Void

    @State private var step: Int = 0
    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 32)
                .padding(.top, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.secondary.opacity(0.06))
        }
        .frame(width: 480, height: 540)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomePane
        case 1: calendarPane
        case 2: weatherPane
        default: welcomePane
        }
    }

    // MARK: - Panes

    private var welcomePane: some View {
        VStack(spacing: 18) {
            Image(systemName: "clock.badge")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 12)

            Text("Welcome to MenuClock")
                .font(.system(size: 22, weight: .semibold))

            Text("World clocks, upcoming calendar events, and current weather — right in your menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                bullet("globe", "Search any of 68,000+ cities worldwide")
                bullet("calendar", "See your next 5 events from any calendar")
                bullet("location.fill", "Local time + weather, automatic")
                bullet("lock.shield", "100% local — no telemetry, no accounts")
            }
            .padding(.top, 6)

            Spacer()
        }
    }

    private var calendarPane: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Show Calendar Events")
                .font(.system(size: 20, weight: .semibold))

            Text("MenuClock can show your next 5 upcoming events in the dropdown. Read-only — it never modifies anything in Calendar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                if calendarManager.isAuthorized {
                    Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                } else {
                    Button {
                        Task { await calendarManager.requestAccessIfNeeded() }
                    } label: {
                        Label("Grant Calendar Access", systemImage: "calendar.badge.plus")
                            .frame(minWidth: 200)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }

                Text("You can change this later in Settings → Calendar Events.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)

            Spacer()
        }
    }

    private var weatherPane: some View {
        VStack(spacing: 18) {
            Image(systemName: "cloud.sun.fill")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 48))

            Text("Show Weather (Optional)")
                .font(.system(size: 20, weight: .semibold))

            Text("Show current temperature next to each world clock. Uses Open-Meteo — free, no account, no tracking, only the city's coordinates are sent.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.weatherEnabled) {
                    Text("Enable weather")
                        .font(.callout)
                }
                .toggleStyle(.switch)

                if settings.weatherEnabled {
                    HStack {
                        Text("Temperature unit:")
                            .font(.callout)
                        Picker("", selection: $settings.temperatureUnit) {
                            ForEach(TemperatureUnit.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )

            Text("Network access required. You can disable weather later.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                if step < totalSteps - 1 {
                    Button(step == 0 ? "Get Started" : "Continue") {
                        step += 1
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") {
                        settings.hasCompletedOnboarding = true
                        if settings.weatherEnabled {
                            Task { await weatherManager.refreshAll(force: true) }
                        }
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func bullet(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.tint)
            Text(text)
                .font(.system(size: 12))
            Spacer()
        }
    }
}
