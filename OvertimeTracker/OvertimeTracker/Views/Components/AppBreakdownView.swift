import SwiftUI

/// Uniform item for the breakdown view
struct AppBreakdownItem: Identifiable {
    var id: String { appName }
    let appName: String
    let activeMinutes: Double
    let regularMinutes: Double
    let overtimeMinutes: Double
}

enum AppBreakdownFilter: String, CaseIterable {
    case all = "Alle"
    case regular = "Regulär"
    case overtime = "Overtime"
}

struct AppBreakdownView: View {
    let title: String
    let items: [AppBreakdownItem]
    @State private var filter: AppBreakdownFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Picker("Filter", selection: $filter) {
                    ForEach(AppBreakdownFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            if items.isEmpty {
                Text("Keine App-Daten vorhanden")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                let maxValue = items.map { valueFor($0) }.max() ?? 1

                ForEach(items) { item in
                    let value = valueFor(item)
                    if value > 0 {
                        appRow(item: item, value: value, maxValue: maxValue)
                    }
                }
            }
        }
    }

    private func valueFor(_ item: AppBreakdownItem) -> Double {
        switch filter {
        case .all: item.activeMinutes
        case .regular: item.regularMinutes
        case .overtime: item.overtimeMinutes
        }
    }

    private func barColor(for item: AppBreakdownItem) -> Color {
        switch filter {
        case .all: .otBlue
        case .regular: .otBlue
        case .overtime: .otRed
        }
    }

    private func appRow(item: AppBreakdownItem, value: Double, maxValue: Double) -> some View {
        HStack(spacing: 10) {
            Text(item.appName)
                .font(.caption)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            GeometryReader { geo in
                let width = max(geo.size.width * (value / max(maxValue, 1)), 2)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor(for: item))
                    .frame(width: width)
            }
            .frame(height: 14)

            Text(Formatters.formatHoursMinutes(value))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}
