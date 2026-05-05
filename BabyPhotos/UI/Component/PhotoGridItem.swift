import SwiftUI

struct PhotoGridItem<Content: View>: View {
    let confidence: Int
    let reason: String
    let content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            ConfidenceBadge(confidence: confidence)
                .padding(4)
        }
        .frame(width: 120, height: 120)
    }
}
