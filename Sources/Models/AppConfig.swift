/// Application configuration loaded from environment variables.
///
/// All configuration is read from environment variables with sensible defaults
/// for local development. In production, these are set via Kubernetes
/// environment variables in the deployment manifest.
///
/// ## Environment Variables
/// - `KUIB_HOST`: Server bind address (default: `0.0.0.0`)
/// - `KUIB_PORT`: Server bind port (default: `8080`)
/// - `KUIB_LOG_LEVEL`: Logging level (default: `info`)
/// - `KUIB_DB_HOST`: PostgreSQL host (default: `localhost`)
/// - `KUIB_DB_PORT`: PostgreSQL port (default: `5432`)
/// - `KUIB_DB_NAME`: Database name (default: `kuib`)
/// - `KUIB_DB_USER`: Database user (default: `kuib`)
/// - `KUIB_DB_PASSWORD`: Database password (default: `kuib`)
/// - `KUIB_LOG_RETENTION_DAYS`: Days to retain logs (default: `30`)
/// - `KUIB_EVENT_RETENTION_DAYS`: Days to retain events (default: `14`)

import Foundation

/// Application-wide configuration.
public struct AppConfig: Sendable {
    public let server: ServerConfig
    public let database: DatabaseConfig
    public let retention: RetentionConfig
    public let logLevel: String

    public init(
        server: ServerConfig = .fromEnvironment(),
        database: DatabaseConfig = .fromEnvironment(),
        retention: RetentionConfig = .fromEnvironment(),
        logLevel: String = env("KUIB_LOG_LEVEL", default: "info")
    ) {
        self.server = server
        self.database = database
        self.retention = retention
        self.logLevel = logLevel
    }

    /// Load full configuration from environment.
    public static func fromEnvironment() -> AppConfig {
        AppConfig()
    }
}

/// HTTP server configuration.
public struct ServerConfig: Sendable {
    public let host: String
    public let port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    public static func fromEnvironment() -> ServerConfig {
        ServerConfig(
            host: env("KUIB_HOST", default: "0.0.0.0"),
            port: envInt("KUIB_PORT", default: 8080)
        )
    }
}

/// PostgreSQL database configuration.
public struct DatabaseConfig: Sendable {
    public let host: String
    public let port: Int
    public let database: String
    public let username: String
    public let password: String

    public init(host: String, port: Int, database: String, username: String, password: String) {
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.password = password
    }

    public static func fromEnvironment() -> DatabaseConfig {
        DatabaseConfig(
            host: env("KUIB_DB_HOST", default: "localhost"),
            port: envInt("KUIB_DB_PORT", default: 5432),
            database: env("KUIB_DB_NAME", default: "kuib"),
            username: env("KUIB_DB_USER", default: "kuib"),
            password: env("KUIB_DB_PASSWORD", default: "kuib")
        )
    }
}

/// Data retention configuration.
public struct RetentionConfig: Sendable {
    public let logRetentionDays: Int
    public let eventRetentionDays: Int

    public init(logRetentionDays: Int, eventRetentionDays: Int) {
        self.logRetentionDays = logRetentionDays
        self.eventRetentionDays = eventRetentionDays
    }

    public static func fromEnvironment() -> RetentionConfig {
        RetentionConfig(
            logRetentionDays: envInt("KUIB_LOG_RETENTION_DAYS", default: 30),
            eventRetentionDays: envInt("KUIB_EVENT_RETENTION_DAYS", default: 14)
        )
    }
}

// MARK: - Environment Helpers

public func env(_ key: String, default defaultValue: String) -> String {
    ProcessInfo.processInfo.environment[key] ?? defaultValue
}

public func envInt(_ key: String, default defaultValue: Int) -> Int {
    if let value = ProcessInfo.processInfo.environment[key], let intValue = Int(value) {
        return intValue
    }
    return defaultValue
}
