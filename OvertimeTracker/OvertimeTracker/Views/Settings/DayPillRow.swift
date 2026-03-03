import SwiftUI

struct DayPillRow: View {
    @Binding var selectedDays: [Int]
    let onChange: () -> Void

    private static let days = [
        (0, "Mo"), (1, "Di"), (2, "Mi"), (3, "Do"),
        (4, "Fr"), (5, "Sa"), (6, "So"),
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Self.days, id: \.0) { day, label in
                let isActive = selectedDays.contains(day)
                Button {
                    toggle(day: day)
                } label: {
                    Text(label)
                        .font(.caption.weight(.medium))
                        .frame(width: 34, height: 26)
                        .background(isActive ? Color.otBlue : .white.opacity(0.08))
                        .foregroundStyle(isActive ? .white : .secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(day: Int) {
        if selectedDays.contains(day) {
            // Keep at least 1 day active
            guard selectedDays.count > 1 else { return }
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
        }
        onChange()
    }
}
