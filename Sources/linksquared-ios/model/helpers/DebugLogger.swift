//
//  DebugLogger.swift
//  test
//
//  Created by Dragos Dobrean on 28.02.2024.
//

import Foundation

public enum LogLevel: String {
    case info = "INFO"
    case error = "ERROR"
}

class DebugLogger {
    // Singleton instance
    public static let shared = DebugLogger()

    // Log level threshold
    public var logLevel: LogLevel = .error

    // Private initializer to enforce singleton pattern
    private init() {}

    // Log function
    public func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue == logLevel.rawValue else {
            return
        }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "LINKSQUARED [\(level.rawValue)] \(fileName) -> \(function) [Line \(line)]: \(message)"
        print(logMessage)
    }
}
