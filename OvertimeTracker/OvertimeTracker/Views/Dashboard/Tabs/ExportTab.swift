import SwiftUI
import UniformTypeIdentifiers

/// A single unpivoted row for the export preview
private struct ExportRow: Identifiable {
    let id = UUID()
    let date: String
    let appName: String
    let minutes: Int
    let category: String
}

struct ExportTab: View {
    var viewModel: DashboardViewModel
    @State private var exportStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var exportEnd: Date = Date()
    @State private var exportMessage: String?

    /// First 5 unpivoted rows for preview
    private var previewRows: [ExportRow] {
        var rows: [ExportRow] = []
        for row in viewModel.exportAppData {
            if row.regularMinutes > 0 {
                rows.append(ExportRow(date: row.date, appName: row.appName, minutes: Int(row.regularMinutes), category: "regular"))
            }
            if row.overtimeMinutes > 0 {
                rows.append(ExportRow(date: row.date, appName: row.appName, minutes: Int(row.overtimeMinutes), category: "overtime"))
            }
            if rows.count >= 5 { break }
        }
        return Array(rows.prefix(5))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                dateRangeSection
                actionButtons
                previewSection
            }
            .padding(24)
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        viewModel.exportStart = exportStart
        viewModel.exportEnd = exportEnd
        viewModel.loadExportData()
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zeitraum")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Von").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $exportStart, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bis").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $exportEnd, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.field)
                }

                Button("Laden") {
                    loadData()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                exportCSV()
            } label: {
                Label("CSV exportieren", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .tint(.otBlue)
            .disabled(viewModel.exportAppData.isEmpty)

            if let message = exportMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(viewModel.exportDayCount) Tage · \(viewModel.exportAppCount) Apps · \(viewModel.exportRowCount) Zeilen")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorschau")
                .font(.headline)

            if viewModel.exportAppData.isEmpty {
                Text("Keine Daten im gewählten Zeitraum")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                previewGrid
            }
        }
    }

    private var previewGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
            GridRow {
                Text("date").fontWeight(.semibold)
                Text("app").fontWeight(.semibold)
                Text("time").fontWeight(.semibold)
                Text("category").fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            ForEach(previewRows) { row in
                GridRow {
                    Text(Formatters.shortDate(row.date))
                    Text(row.appName)
                    Text("\(row.minutes)")
                        .foregroundStyle(Color.otBlue)
                    Text(row.category)
                        .foregroundStyle(row.category == "overtime" ? Color.otRed : Color.otBlue)
                }
                .font(.caption.monospaced())
            }

            if viewModel.exportRowCount > 5 {
                GridRow {
                    Text("…")
                        .foregroundStyle(.secondary)
                    Text("")
                    Text("")
                    Text("")
                }
                .font(.caption)
            }
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "overtime-\(fmt.string(from: exportStart))_\(fmt.string(from: exportEnd)).csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let csv = viewModel.generateCSV()
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "Exportiert nach \(url.lastPathComponent)"
        } catch {
            exportMessage = "Fehler: \(error.localizedDescription)"
        }
    }
}
