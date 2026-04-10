import SwiftUI
import AppKit

/// Search-any-city picker. Backed by the bundled GeoNames cities5000 dataset.
struct TimeZonePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [City] = []

    let onPick: (City) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            searchField
                .padding(.horizontal, 16)
                .padding(.top, 4)

            Divider().padding(.top, 12)

            if results.isEmpty {
                emptyState
            } else {
                resultsList
            }

            attribution
        }
        .frame(width: 480, height: 560)
        .onAppear {
            results = CityDatabase.shared.search("", limit: 200)
        }
        .onChange(of: query) { newValue in
            results = CityDatabase.shared.search(newValue, limit: 300)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add a City")
                    .font(.headline)
                Text("Search any city worldwide")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("e.g. Cusco, Reykjavík, Chiang Mai…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.2))
        )
    }

    private var resultsList: some View {
        List(results) { city in
            Button {
                onPick(city)
                dismiss()
            } label: {
                HStack(spacing: 10) {
                    Text(flag(for: city.countryCode))
                        .font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(city.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(city.subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currentTime(for: city.timeZoneIdentifier))
                            .font(.system(size: 12, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text(offsetString(for: city.timeZoneIdentifier))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No cities found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Try a different spelling or the country name.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var attribution: some View {
        Text("City data © GeoNames · CC BY 4.0")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func currentTime(for identifier: String) -> String {
        let tz = TimeZone(identifier: identifier) ?? .current
        return TimeFormatting.timeString(for: Date(), in: tz)
    }

    private func offsetString(for identifier: String) -> String {
        guard let tz = TimeZone(identifier: identifier) else { return "" }
        let offsetSeconds = tz.secondsFromGMT()
        let sign = offsetSeconds >= 0 ? "+" : "−"
        let abs = Swift.abs(offsetSeconds)
        let hours = abs / 3600
        let minutes = (abs % 3600) / 60
        if minutes == 0 {
            return "GMT\(sign)\(hours)"
        }
        return String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }

    /// Turn an ISO country code into a regional indicator emoji flag.
    private func flag(for countryCode: String) -> String {
        let base: UInt32 = 127_397
        var s = ""
        for scalar in countryCode.uppercased().unicodeScalars {
            if let v = Unicode.Scalar(base + scalar.value) {
                s.unicodeScalars.append(v)
            }
        }
        return s.isEmpty ? "🌐" : s
    }
}
