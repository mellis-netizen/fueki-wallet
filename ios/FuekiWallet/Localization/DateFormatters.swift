//
//  DateFormatters.swift
//  FuekiWallet
//
//  Date and time formatting with localization
//

import Foundation

extension DateFormatter {

    // MARK: - Transaction Date Formatters

    /// Full date and time (Jan 15, 2025 at 3:45 PM)
    static let transactionFull: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.doesRelativeDateFormatting = false
        return formatter
    }()

    /// Short date and time (1/15/25, 3:45 PM)
    static let transactionShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Relative date formatting (Today at 3:45 PM, Yesterday at 10:00 AM)
    static let transactionRelative: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    // MARK: - Display Formatters

    /// Date only (January 15, 2025)
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Time only (3:45 PM)
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Month and year (January 2025)
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Short month and day (Jan 15)
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    // MARK: - ISO Formatters

    /// ISO 8601 formatter (2025-01-15T15:45:00Z)
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 date only (2025-01-15)
    static let iso8601Date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    // MARK: - Custom Formatters

    /// Chart date formatter (Jan 15, 3:45 PM)
    static let chartDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Chart time only (3:45 PM)
    static let chartTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    // MARK: - Helper Methods

    /// Update all formatters with new locale
    static func updateLocale(_ locale: Locale) {
        transactionFull.locale = locale
        transactionShort.locale = locale
        transactionRelative.locale = locale
        dateOnly.locale = locale
        timeOnly.locale = locale
        monthYear.locale = locale
        monthDay.locale = locale
        chartDate.locale = locale
        chartTime.locale = locale
    }
}

// MARK: - Date Extensions

extension Date {

    /// Format as full transaction date
    var asTransactionFull: String {
        DateFormatter.transactionFull.string(from: self)
    }

    /// Format as short transaction date
    var asTransactionShort: String {
        DateFormatter.transactionShort.string(from: self)
    }

    /// Format as relative transaction date
    var asTransactionRelative: String {
        DateFormatter.transactionRelative.string(from: self)
    }

    /// Format as date only
    var asDateOnly: String {
        DateFormatter.dateOnly.string(from: self)
    }

    /// Format as time only
    var asTimeOnly: String {
        DateFormatter.timeOnly.string(from: self)
    }

    /// Format as ISO 8601
    var asISO8601: String {
        DateFormatter.iso8601.string(from: self)
    }

    /// Get relative time string (Just now, 5 minutes ago, etc.)
    var relativeTime: String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(self)

        if timeInterval < 60 {
            return "time.just_now".localized
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "time.minutes_ago".localized(with: minutes)
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "time.hours_ago".localized(with: hours)
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "time.days_ago".localized(with: days)
        } else if timeInterval < 2592000 {
            let weeks = Int(timeInterval / 604800)
            return "time.weeks_ago".localized(with: weeks)
        } else if timeInterval < 31536000 {
            let months = Int(timeInterval / 2592000)
            return "time.months_ago".localized(with: months)
        } else {
            let years = Int(timeInterval / 31536000)
            return "time.years_ago".localized(with: years)
        }
    }

    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Check if date is this week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// Check if date is this month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }

    /// Check if date is this year
    var isThisYear: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }

    /// Get smart formatted date (relative for recent, absolute for old)
    var smartFormatted: String {
        if isToday {
            return "time.just_now".localized + " • " + asTimeOnly
        } else if isYesterday {
            return "Yesterday • " + asTimeOnly
        } else if isThisWeek {
            return asTransactionRelative
        } else {
            return asTransactionShort
        }
    }
}

// MARK: - String Date Parsing

extension String {

    /// Parse ISO 8601 date string
    var parseISO8601: Date? {
        DateFormatter.iso8601.date(from: self)
    }

    /// Parse date with custom formatter
    func parseDate(format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.date(from: self)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {

    /// Format duration in human readable format
    var asDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}
