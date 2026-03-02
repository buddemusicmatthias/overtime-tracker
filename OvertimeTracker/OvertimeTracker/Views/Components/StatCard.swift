import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String?
    var accentColor: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(accentColor ?? .white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
