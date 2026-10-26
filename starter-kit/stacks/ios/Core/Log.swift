import OSLog

/// One logger per area. Read logs in Console.app or Xcode, filtered by subsystem/category.
/// Use privacy markers: values are hidden in release logs unless marked `.public`.
enum Log {
    static let api = Logger(subsystem: "app", category: "api")
    static let notes = Logger(subsystem: "app", category: "notes")
}
