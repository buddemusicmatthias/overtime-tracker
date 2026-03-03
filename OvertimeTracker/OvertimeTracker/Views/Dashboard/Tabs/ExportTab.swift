import SwiftUI
import UniformTypeIdentifiers

struct ExportTab: View {
    var viewModel: DashboardViewModel
    @State private var exportStart: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var exportEnd: Date = Date()
    @State private var exportMessage: String?

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
            .disabled(viewModel.exportSummaries.isEmpty)

            if let message = exportMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(viewModel.exportSummaries.count) Tage")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorschau")
                .font(.headline)

            if viewModel.exportSummaries.isEmpty {
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
                Text("Datum").fontWeight(.semibold)
                Text("Tag").fontWeight(.semibold)
                Text("Aktiv").fontWeight(.semibold)
                Text("Overtime").fontWeight(.semibold)
                Text("Kategorie").fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            ForEach(Array(viewModel.exportSummaries.enumerated()), id: \.offset) { _, s in
                previewRow(s)
            }
        }
    }

    private func previewRow(_ s: DailySummary) -> some View {
        let dayNames = ["", "So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        return GridRow {
            Text(Formatters.shortDate(s.date))
            Text(s.dayOfWeek >= 1 && s.dayOfWeek <= 7 ? dayNames[s.dayOfWeek] : "?")
            Text(Formatters.formatMinutes(s.totalActiveMinutes))
                .foregroundStyle(Color.otBlue)
            Text(Formatters.formatMinutes(s.overtimeMinutes))
                .foregroundStyle(Color.otRed)
            Text(s.workCategory)
        }
        .font(.caption.monospaced())
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
