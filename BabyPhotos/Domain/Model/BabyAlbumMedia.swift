import Foundation

enum BabyAlbumMediaType: Sendable, Equatable {
    case image
    case video
}

struct BabyAlbumMedia: Identifiable, Equatable, Sendable {
    let id: String
    let mediaType: BabyAlbumMediaType
    let createdAt: Date
    /// PHAsset localIdentifier for loading thumbnails and full media.
    let loadKey: String

    var isVideo: Bool { mediaType == .video }
}

struct BabyAlbumDateSection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let items: [BabyAlbumMedia]
}

enum BabyAlbumDateGrouper {
    static func group(_ items: [BabyAlbumMedia], calendar: Calendar = .current) -> [BabyAlbumDateSection] {
        let sorted = items.sorted { $0.createdAt > $1.createdAt }
        var sections: [BabyAlbumDateSection] = []
        var currentDay: Date?
        var bucket: [BabyAlbumMedia] = []

        func flush() {
            guard !bucket.isEmpty, let day = currentDay else { return }
            sections.append(
                BabyAlbumDateSection(
                    id: day.timeIntervalSince1970.description,
                    title: sectionTitle(for: day, calendar: calendar),
                    items: bucket
                )
            )
            bucket = []
        }

        for item in sorted {
            let day = calendar.startOfDay(for: item.createdAt)
            if currentDay != day {
                flush()
                currentDay = day
            }
            bucket.append(item)
        }
        flush()
        return sections
    }

    private static func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: day)
    }
}
