/// PostgreSQL database manager for KUIB.
///
/// Manages the connection pool, runs migrations, and provides query methods
/// for persisting events, logs, job history, and alert data.
///
/// ## Topics
/// ### Connection
/// - ``init(config:logger:)``
/// - ``initialize()``
/// - ``shutdown()``
/// ### Migrations
/// - ``runMigrations()``
/// ### Queries
/// - ``saveEvent(_:)``
/// - ``savePodLog(_:)``
/// - ``saveJobRun(_:)``
/// - ``saveFiredAlert(_:)``

import Foundation
import Logging
import Models
import PostgresNIO

/// Manages PostgreSQL connections and provides data access methods.
public actor DatabaseManager {
    private let config: DatabaseConfig
    private let logger: Logger
    private var connection: PostgresConnection?

    public init(config: DatabaseConfig, logger: Logger = Logger(label: "kuib.db")) {
        self.config = config
        self.logger = logger
    }

    /// Initialize the database connection and run migrations.
    public func initialize() async throws {
        let pgConfig = PostgresConnection.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: .disable
        )

        connection = try await PostgresConnection.connect(
            configuration: pgConfig,
            id: 1,
            logger: logger
        )

        try await runMigrations()
        logger.info("Database initialized successfully")
    }

    /// Shut down the database connection.
    public func shutdown() async throws {
        try await connection?.close()
        logger.info("Database connection closed")
    }

    // MARK: - Migrations

    /// Run all database migrations in order.
    public func runMigrations() async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        // Create migrations tracking table
        try await conn.query("""
            CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """, logger: logger)

        let rows = try await conn.query("SELECT version FROM schema_migrations ORDER BY version", logger: logger)
        var appliedVersions: Set<Int> = []
        for try await row in rows {
            let version = try row.decode(Int.self, context: .default)
            appliedVersions.insert(version)
        }

        for migration in Self.migrations {
            if !appliedVersions.contains(migration.version) {
                logger.info("Applying migration \(migration.version): \(migration.name)")
                try await conn.query(PostgresQuery(stringLiteral: migration.sql), logger: logger)
                try await conn.query(
                    "INSERT INTO schema_migrations (version) VALUES (\(migration.version))",
                    logger: logger
                )
            }
        }
    }

    // MARK: - Events

    /// Persist a Kubernetes event to the database.
    public func saveEvent(_ event: EventInfo) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        try await conn.query("""
            INSERT INTO k8s_events (id, namespace, involved_object_kind, involved_object_name,
                reason, message, type, first_timestamp, last_timestamp, count)
            VALUES (\(event.id), \(event.namespace), \(event.involvedObjectKind),
                \(event.involvedObjectName), \(event.reason), \(event.message),
                \(event.type), \(event.firstTimestamp), \(event.lastTimestamp), \(event.count))
            ON CONFLICT (id) DO UPDATE SET
                last_timestamp = EXCLUDED.last_timestamp,
                count = EXCLUDED.count,
                message = EXCLUDED.message
            """, logger: logger)
    }

    /// Query persisted events with optional filtering.
    public func queryEvents(
        namespace: String? = nil,
        reason: String? = nil,
        objectKind: String? = nil,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [EventInfo] {
        guard let conn = connection else { throw DatabaseError.notConnected }

        // Build parameterized query to prevent SQL injection
        let query: PostgresQuery
        switch (namespace, reason, objectKind) {
        case let (ns?, r?, kind?):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE namespace = \(ns) AND reason = \(r) AND involved_object_kind = \(kind)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (ns?, r?, nil):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE namespace = \(ns) AND reason = \(r)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (ns?, nil, kind?):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE namespace = \(ns) AND involved_object_kind = \(kind)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (nil, r?, kind?):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE reason = \(r) AND involved_object_kind = \(kind)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (ns?, nil, nil):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE namespace = \(ns)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (nil, r?, nil):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE reason = \(r)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case let (nil, nil, kind?):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events WHERE involved_object_kind = \(kind)
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        case (nil, nil, nil):
            query = """
                SELECT id, namespace, involved_object_kind, involved_object_name, reason, message, type, first_timestamp, last_timestamp, count
                FROM k8s_events
                ORDER BY last_timestamp DESC LIMIT \(limit) OFFSET \(offset)
                """
        }

        let rows = try await conn.query(query, logger: logger)
        var events: [EventInfo] = []
        for try await row in rows {
            let (id, ns, kind, name, reason, message, type, first, last, count) =
                try row.decode((String, String, String, String, String, String, String, Date?, Date?, Int32).self, context: .default)
            events.append(EventInfo(
                id: id, namespace: ns, involvedObjectKind: kind,
                involvedObjectName: name, reason: reason, message: message,
                type: type, firstTimestamp: first, lastTimestamp: last, count: count
            ))
        }
        return events
    }

    // MARK: - Pod Logs

    /// Save a pod log snapshot to the database.
    public func savePodLog(namespace: String, podName: String, container: String, log: String) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        try await conn.query("""
            INSERT INTO pod_logs (id, namespace, pod_name, container_name, log_content, captured_at)
            VALUES (\(UUID().uuidString), \(namespace), \(podName), \(container), \(log), NOW())
            """, logger: logger)
    }

    /// Retrieve historical logs for a pod.
    public func getPodLogs(namespace: String, podName: String, limit: Int = 10) async throws -> [(container: String, log: String, capturedAt: Date)] {
        guard let conn = connection else { throw DatabaseError.notConnected }

        let rows = try await conn.query("""
            SELECT container_name, log_content, captured_at FROM pod_logs
            WHERE namespace = \(namespace) AND pod_name = \(podName)
            ORDER BY captured_at DESC LIMIT \(limit)
            """, logger: logger)

        var results: [(container: String, log: String, capturedAt: Date)] = []
        for try await row in rows {
            let (container, log, capturedAt) = try row.decode((String, String, Date).self, context: .default)
            results.append((container: container, log: log, capturedAt: capturedAt))
        }
        return results
    }

    // MARK: - Job History

    /// Record a job run completion for timeline history.
    public func saveJobRun(_ job: JobInfo) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        let status: String
        if job.succeeded > 0 { status = "succeeded" }
        else if job.failed > 0 { status = "failed" }
        else { status = "active" }

        try await conn.query("""
            INSERT INTO job_runs (id, namespace, job_name, owner_name, status,
                start_time, completion_time, duration_seconds)
            VALUES (\(UUID().uuidString), \(job.namespace), \(job.name),
                \(job.ownerName), \(status), \(job.startTime), \(job.completionTime),
                \(job.duration))
            ON CONFLICT (namespace, job_name) DO UPDATE SET
                status = EXCLUDED.status,
                completion_time = EXCLUDED.completion_time,
                duration_seconds = EXCLUDED.duration_seconds
            """, logger: logger)
    }

    /// Query job run history for timeline display.
    public func queryJobHistory(
        namespace: String? = nil,
        cronJobName: String? = nil,
        limit: Int = 50
    ) async throws -> [JobRunRecord] {
        guard let conn = connection else { throw DatabaseError.notConnected }

        // Use parameterized queries to prevent SQL injection
        let query: PostgresQuery
        switch (namespace, cronJobName) {
        case let (ns?, owner?):
            query = """
                SELECT id, namespace, job_name, owner_name, status, start_time, completion_time, duration_seconds
                FROM job_runs WHERE namespace = \(ns) AND owner_name = \(owner)
                ORDER BY start_time DESC LIMIT \(limit)
                """
        case let (ns?, nil):
            query = """
                SELECT id, namespace, job_name, owner_name, status, start_time, completion_time, duration_seconds
                FROM job_runs WHERE namespace = \(ns)
                ORDER BY start_time DESC LIMIT \(limit)
                """
        case let (nil, owner?):
            query = """
                SELECT id, namespace, job_name, owner_name, status, start_time, completion_time, duration_seconds
                FROM job_runs WHERE owner_name = \(owner)
                ORDER BY start_time DESC LIMIT \(limit)
                """
        case (nil, nil):
            query = """
                SELECT id, namespace, job_name, owner_name, status, start_time, completion_time, duration_seconds
                FROM job_runs
                ORDER BY start_time DESC LIMIT \(limit)
                """
        }

        let rows = try await conn.query(query, logger: logger)
        var results: [JobRunRecord] = []
        for try await row in rows {
            let (id, ns, name, owner, status, start, completion, duration) =
                try row.decode((String, String, String, String?, String, Date?, Date?, Double?).self, context: .default)
            results.append(JobRunRecord(
                id: id, namespace: ns, jobName: name, ownerName: owner,
                status: status, startTime: start, completionTime: completion,
                durationSeconds: duration
            ))
        }
        return results
    }

    // MARK: - Alerts

    /// Save a fired alert to the database.
    public func saveFiredAlert(_ alert: FiredAlert) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        try await conn.query("""
            INSERT INTO fired_alerts (id, rule_id, rule_name, severity, resource_kind,
                resource_name, namespace, message, fired_at, delivery_status, delivered_at)
            VALUES (\(alert.id), \(alert.ruleId), \(alert.ruleName),
                \(alert.severity.rawValue), \(alert.resourceKind),
                \(alert.resourceName), \(alert.namespace), \(alert.message),
                \(alert.firedAt), \(alert.deliveryStatus.rawValue), \(alert.deliveredAt))
            """, logger: logger)
    }

    /// Update the delivery status of a fired alert.
    public func updateAlertDelivery(id: String, status: AlertDeliveryStatus, deliveredAt: Date?) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        try await conn.query("""
            UPDATE fired_alerts SET delivery_status = \(status.rawValue),
                delivered_at = \(deliveredAt) WHERE id = \(id)
            """, logger: logger)
    }

    /// Query alert history.
    public func queryAlerts(
        severity: AlertSeverity? = nil,
        namespace: String? = nil,
        limit: Int = 50
    ) async throws -> [FiredAlert] {
        guard let conn = connection else { throw DatabaseError.notConnected }

        var sql = "SELECT id, rule_id, rule_name, severity, resource_kind, resource_name, namespace, message, fired_at, delivery_status, delivered_at FROM fired_alerts WHERE 1=1"
        if let sev = severity { sql += " AND severity = '\(sev.rawValue)'" }
        if let ns = namespace { sql += " AND namespace = '\(ns)'" }
        sql += " ORDER BY fired_at DESC LIMIT \(limit)"

        let rows = try await conn.query(PostgresQuery(stringLiteral: sql), logger: logger)
        var results: [FiredAlert] = []
        for try await row in rows {
            let (id, ruleId, ruleName, severity, kind, name, ns, message, firedAt, status, deliveredAt) =
                try row.decode((String, String, String, String, String, String, String, String, Date, String, Date?).self, context: .default)
            results.append(FiredAlert(
                id: id, ruleId: ruleId, ruleName: ruleName,
                severity: AlertSeverity(rawValue: severity) ?? .warning,
                resourceKind: kind, resourceName: name, namespace: ns,
                message: message, firedAt: firedAt,
                deliveryStatus: AlertDeliveryStatus(rawValue: status) ?? .pending,
                deliveredAt: deliveredAt
            ))
        }
        return results
    }

    /// Clean up old data based on retention settings.
    public func cleanupOldData(logRetentionDays: Int, eventRetentionDays: Int) async throws {
        guard let conn = connection else { throw DatabaseError.notConnected }

        try await conn.query("""
            DELETE FROM pod_logs WHERE captured_at < NOW() - INTERVAL '\(unescaped: String(logRetentionDays)) days'
            """, logger: logger)

        try await conn.query("""
            DELETE FROM k8s_events WHERE last_timestamp < NOW() - INTERVAL '\(unescaped: String(eventRetentionDays)) days'
            """, logger: logger)

        logger.info("Cleaned up old data", metadata: [
            "log_retention_days": "\(logRetentionDays)",
            "event_retention_days": "\(eventRetentionDays)",
        ])
    }

    // MARK: - Migrations List

    private static let migrations: [(version: Int, name: String, sql: String)] = [
        (
            version: 1,
            name: "Create events table",
            sql: """
                CREATE TABLE IF NOT EXISTS k8s_events (
                    id TEXT PRIMARY KEY,
                    namespace TEXT NOT NULL,
                    involved_object_kind TEXT NOT NULL,
                    involved_object_name TEXT NOT NULL,
                    reason TEXT NOT NULL,
                    message TEXT NOT NULL,
                    type TEXT NOT NULL,
                    first_timestamp TIMESTAMPTZ,
                    last_timestamp TIMESTAMPTZ,
                    count INTEGER DEFAULT 1,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                CREATE INDEX IF NOT EXISTS idx_events_namespace ON k8s_events(namespace);
                CREATE INDEX IF NOT EXISTS idx_events_reason ON k8s_events(reason);
                CREATE INDEX IF NOT EXISTS idx_events_last_timestamp ON k8s_events(last_timestamp);
                """
        ),
        (
            version: 2,
            name: "Create pod logs table",
            sql: """
                CREATE TABLE IF NOT EXISTS pod_logs (
                    id TEXT PRIMARY KEY,
                    namespace TEXT NOT NULL,
                    pod_name TEXT NOT NULL,
                    container_name TEXT NOT NULL,
                    log_content TEXT NOT NULL,
                    captured_at TIMESTAMPTZ NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                CREATE INDEX IF NOT EXISTS idx_pod_logs_lookup ON pod_logs(namespace, pod_name);
                CREATE INDEX IF NOT EXISTS idx_pod_logs_captured ON pod_logs(captured_at);
                """
        ),
        (
            version: 3,
            name: "Create job runs table",
            sql: """
                CREATE TABLE IF NOT EXISTS job_runs (
                    id TEXT PRIMARY KEY,
                    namespace TEXT NOT NULL,
                    job_name TEXT NOT NULL,
                    owner_name TEXT,
                    status TEXT NOT NULL,
                    start_time TIMESTAMPTZ,
                    completion_time TIMESTAMPTZ,
                    duration_seconds DOUBLE PRECISION,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    UNIQUE(namespace, job_name)
                );
                CREATE INDEX IF NOT EXISTS idx_job_runs_namespace ON job_runs(namespace);
                CREATE INDEX IF NOT EXISTS idx_job_runs_owner ON job_runs(owner_name);
                CREATE INDEX IF NOT EXISTS idx_job_runs_start ON job_runs(start_time);
                """
        ),
        (
            version: 4,
            name: "Create fired alerts table",
            sql: """
                CREATE TABLE IF NOT EXISTS fired_alerts (
                    id TEXT PRIMARY KEY,
                    rule_id TEXT NOT NULL,
                    rule_name TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    resource_kind TEXT NOT NULL,
                    resource_name TEXT NOT NULL,
                    namespace TEXT NOT NULL,
                    message TEXT NOT NULL,
                    fired_at TIMESTAMPTZ NOT NULL,
                    delivery_status TEXT NOT NULL DEFAULT 'pending',
                    delivered_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                CREATE INDEX IF NOT EXISTS idx_alerts_severity ON fired_alerts(severity);
                CREATE INDEX IF NOT EXISTS idx_alerts_namespace ON fired_alerts(namespace);
                CREATE INDEX IF NOT EXISTS idx_alerts_fired_at ON fired_alerts(fired_at);
                """
        ),
        (
            version: 5,
            name: "Create webhook endpoints table",
            sql: """
                CREATE TABLE IF NOT EXISTS webhook_endpoints (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    url TEXT NOT NULL,
                    headers JSONB NOT NULL DEFAULT '{}',
                    enabled BOOLEAN NOT NULL DEFAULT true,
                    retry_count INTEGER NOT NULL DEFAULT 3,
                    timeout_seconds INTEGER NOT NULL DEFAULT 10,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                """
        ),
        (
            version: 6,
            name: "Create alert rules table",
            sql: """
                CREATE TABLE IF NOT EXISTS alert_rules (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    type TEXT NOT NULL,
                    severity TEXT NOT NULL DEFAULT 'warning',
                    enabled BOOLEAN NOT NULL DEFAULT true,
                    cooldown_seconds INTEGER NOT NULL DEFAULT 300,
                    namespace_filter TEXT,
                    label_selector JSONB,
                    webhook_endpoint_ids JSONB NOT NULL DEFAULT '[]',
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );
                """
        ),
    ]
}

// MARK: - Supporting Types

/// Record of a historical job run, persisted in PostgreSQL.
public struct JobRunRecord: Sendable, Codable {
    public let id: String
    public let namespace: String
    public let jobName: String
    public let ownerName: String?
    public let status: String
    public let startTime: Date?
    public let completionTime: Date?
    public let durationSeconds: Double?
}

/// Errors from database operations.
public enum DatabaseError: Error, Sendable {
    case notConnected
    case migrationFailed(String)
    case queryFailed(String)
}
