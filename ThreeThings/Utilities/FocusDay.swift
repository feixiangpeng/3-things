import Foundation

enum FocusDay {
    static let boundaryHour = 2

    static func id(for date: Date = Date(), calendar baseCalendar: Calendar = .autoupdatingCurrent) -> String {
        var calendar = baseCalendar
        calendar.timeZone = .autoupdatingCurrent

        let focusDate = focusDate(for: date, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day], from: focusDate)

        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func trailingIDs(count: Int, endingAt date: Date = Date(), calendar baseCalendar: Calendar = .autoupdatingCurrent) -> [String] {
        guard count > 0 else { return [] }

        var calendar = baseCalendar
        calendar.timeZone = .autoupdatingCurrent

        let focusDate = focusDate(for: date, calendar: calendar)
        let startOfFocusDate = calendar.startOfDay(for: focusDate)

        return (0..<count).reversed().compactMap { offset in
            guard let candidateDate = calendar.date(byAdding: .day, value: -offset, to: startOfFocusDate) else {
                return nil
            }
            return id(fromFocusDate: candidateDate, calendar: calendar)
        }
    }

    static func date(from id: String, calendar baseCalendar: Calendar = .autoupdatingCurrent) -> Date? {
        let pieces = id.split(separator: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2]) else {
            return nil
        }

        var calendar = baseCalendar
        calendar.timeZone = .autoupdatingCurrent

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    private static func focusDate(for date: Date, calendar: Calendar) -> Date {
        let startOfCalendarDay = calendar.startOfDay(for: date)
        let boundary = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: startOfCalendarDay) ?? startOfCalendarDay

        if date < boundary {
            return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return date
    }

    private static func id(fromFocusDate date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
