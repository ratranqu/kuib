/// Models for the alerting subsystem.
///
/// Alerts are evaluated by the ``AlertEngine`` against incoming Kubernetes watch events.
/// When a rule matches, a ``FiredAlert`` is created and dispatched to configured
/// ``WebhookEndpoint``s by the ``WebhookDispatcher``.
///
/// ## Topics
/// ### Rules
/// - ``AlertRule``
/// - ``AlertRuleType``
/// - ``AlertSeverity``
/// ### Fired Alerts
/// - ``FiredAlert``
/// - ``AlertDeliveryStatus``
/// ### Webhooks
/// - ``WebhookEndpoint``

import Foundation

// MARK: - Alert Severity

/// Severity level of an alert.
public enum AlertSeverity: String, Sendable, Codable, CaseIterable {
    case info
    case warning
    case critical
}

// MARK: - Alert Rule Types

/// Built-in alert rule types that the engine can evaluate.
public enum AlertRuleType: String, Sendable, Codable, CaseIterable {
    case podCrashLoopBackOff
    case podOOMKilled
    case podImagePullBackOff
    case podFailed
    case deploymentRolloutFailed
    case deploymentReplicasMismatch
    case jobFailed
    case jobTimeout
    case nodeNotReady
    case nodeMemoryPressure
    case nodeDiskPressure
    case persistentVolumeClaimPending
    case custom
}

// MARK: - Alert Rule

/// Configuration for an alert rule.
public struct AlertRule: Sendable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let type: AlertRuleType
    public let severity: AlertSeverity
    public let enabled: Bool
    public let cooldownSeconds: Int
    public let namespaceFilter: String?
    public let labelSelector: [String: String]?
    public let webhookEndpointIds: [String]

    public init(
        id: String, name: String, type: AlertRuleType,
        severity: AlertSeverity, enabled: Bool = true,
        cooldownSeconds: Int = 300, namespaceFilter: String? = nil,
        labelSelector: [String: String]? = nil,
        webhookEndpointIds: [String] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.severity = severity
        self.enabled = enabled
        self.cooldownSeconds = cooldownSeconds
        self.namespaceFilter = namespaceFilter
        self.labelSelector = labelSelector
        self.webhookEndpointIds = webhookEndpointIds
    }
}

// MARK: - Fired Alert

/// Delivery status of a fired alert.
public enum AlertDeliveryStatus: String, Sendable, Codable {
    case pending
    case delivered
    case failed
    case cooldown
}

/// A fired alert instance, persisted to the database.
public struct FiredAlert: Sendable, Codable, Identifiable {
    public let id: String
    public let ruleId: String
    public let ruleName: String
    public let severity: AlertSeverity
    public let resourceKind: String
    public let resourceName: String
    public let namespace: String
    public let message: String
    public let firedAt: Date
    public var deliveryStatus: AlertDeliveryStatus
    public var deliveredAt: Date?

    public init(
        id: String, ruleId: String, ruleName: String,
        severity: AlertSeverity, resourceKind: String,
        resourceName: String, namespace: String, message: String,
        firedAt: Date, deliveryStatus: AlertDeliveryStatus = .pending,
        deliveredAt: Date? = nil
    ) {
        self.id = id
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.severity = severity
        self.resourceKind = resourceKind
        self.resourceName = resourceName
        self.namespace = namespace
        self.message = message
        self.firedAt = firedAt
        self.deliveryStatus = deliveryStatus
        self.deliveredAt = deliveredAt
    }
}

// MARK: - Webhook Endpoint

/// A configured webhook endpoint for alert delivery.
public struct WebhookEndpoint: Sendable, Codable, Identifiable {
    public let id: String
    public let name: String
    public let url: String
    public let headers: [String: String]
    public let enabled: Bool
    public let retryCount: Int
    public let timeoutSeconds: Int

    public init(
        id: String, name: String, url: String,
        headers: [String: String] = [:], enabled: Bool = true,
        retryCount: Int = 3, timeoutSeconds: Int = 10
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.headers = headers
        self.enabled = enabled
        self.retryCount = retryCount
        self.timeoutSeconds = timeoutSeconds
    }
}
