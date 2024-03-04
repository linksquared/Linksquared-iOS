//
//  DebugLogger.swift
//
//  linksquared
//

import Foundation

/// An enumeration defining log levels.
public enum LogLevel: String {
    case info = "INFO"
    case error = "ERROR"
}

/// A singleton class for logging debug messages.
class DebugLogger {
    // MARK: - Singleton Instance

    /// The shared instance of DebugLogger.
    public static let shared = DebugLogger()

    // MARK: - Properties

    /// The log level threshold.
    public var logLevel: LogLevel = .error

    // MARK: - Private Initialization

    /// Private initializer to enforce singleton pattern.
    private init() {}

    // MARK: - Logging Function

    /// Logs a message with the specified log level.
    ///
    /// - Parameters:
    ///   - level: The log level of the message.
    ///   - message: The message to log.
    ///   - file: The file in which the log message is located.
    ///   - function: The function in which the log message is located.
    ///   - line: The line number at which the log message is located.
    public func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue == logLevel.rawValue else {
            return
        }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "LINKSQUARED [\(level.rawValue)] \(fileName) -> \(function) [Line \(line)]: \(message)"
        print(logMessage)
    }
}
