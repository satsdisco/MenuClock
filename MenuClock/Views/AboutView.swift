import SwiftUI
import AppKit

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 16) {
            appIcon
                .padding(.top, 24)

            VStack(spacing: 4) {
                Text("MenuClock")
                    .font(.system(size: 22, weight: .semibold))
                Text("Version \(version) (\(build))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("World clocks, calendar events, and weather — right in your menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                linkRow("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right",
                        url: "https://github.com/satsdisco/MenuClock")
                linkRow("Report an Issue", systemImage: "exclamationmark.bubble",
                        url: "https://github.com/satsdisco/MenuClock/issues")
            }

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 4) {
                Text("Acknowledgments")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("City data © GeoNames · CC BY 4.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("Weather data © Open-Meteo · CC BY 4.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Text("SF Symbols by Apple")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text("MIT License · © 2026")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
        }
        .frame(width: 360, height: 460)
    }

    private var appIcon: some View {
        Group {
            if let nsImage = NSImage(named: "AppIcon") {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 96, height: 96)
            } else {
                Image(systemName: "clock.badge")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
            }
        }
    }

    private func linkRow(_ title: String, systemImage: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.08))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
    }
}
