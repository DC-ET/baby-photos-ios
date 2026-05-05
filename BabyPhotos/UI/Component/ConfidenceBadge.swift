import SwiftUI

struct ConfidenceBadge: View {
    let confidence: Int

    private var color: Color {
        switch confidence {
        case 80...: return Color(red: 0.31, green: 0.69, blue: 0.31) // #4CAF50
        case 50...: return Color(red: 1.0, green: 0.76, blue: 0.03)  // #FFC107
        default:    return Color(red: 0.96, green: 0.26, blue: 0.21)  // #F44336
        }
    }

    private var label: String {
        switch confidence {
        case 80...: return "高"
        case 50...: return "中"
        default:    return "低"
        }
    }

    var body: some View {
        Text("\(confidence)% \(label)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
