/// Alert history, rules, and webhook configuration pages.

import Components
import Elementary
import Models

// MARK: - Alert History

/// Page showing fired alert history.
public struct AlertHistoryPage: HTML {
    let alerts: [FiredAlert]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(alerts: [FiredAlert], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.alerts = alerts
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var body: some HTML {
        BaseLayout(title: "Alerts", currentPath: "/alerts") {
            PageHeader(title: "Alert History", subtitle: "\(alerts.count) alerts") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/alerts/list")
            }

            div(.id("resource-list")) {
                if alerts.isEmpty {
                    div(.class("text-center py-12")) {
                        p(.class("text-green-600 text-lg font-medium")) { "No alerts fired" }
                        p(.class("text-gray-500 text-sm mt-1")) { "Your cluster is running smoothly" }
                    }
                } else {
                    ResourceTable {
                        TableHeader("Severity")
                        TableHeader("Rule")
                        TableHeader("Resource")
                        TableHeader("Namespace")
                        TableHeader("Message")
                        TableHeader("Fired At")
                        TableHeader("Status")
                    } body: {
                        for alert in alerts {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { SeverityBadge(alert.severity) }
                                TableCell { span(.class("font-medium text-gray-700")) { alert.ruleName } }
                                TableCell {
                                    span(.class("text-gray-600 text-xs")) {
                                        "\(alert.resourceKind)/\(alert.resourceName)"
                                    }
                                }
                                TableCell { span(.class("text-gray-700")) { alert.namespace } }
                                TableCell {
                                    span(.class("text-gray-600 text-xs truncate max-w-xs block")) { alert.message }
                                }
                                TableCell { Timestamp(alert.firedAt) }
                                TableCell { DeliveryStatusBadge(alert.deliveryStatus) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Alert Rules Page

/// Page listing configured alert rules.
public struct AlertRulesPage: HTML {
    let rules: [AlertRule]

    public init(rules: [AlertRule]) {
        self.rules = rules
    }

    public var body: some HTML {
        BaseLayout(title: "Alert Rules", currentPath: "/alerts/rules") {
            PageHeader(title: "Alert Rules", subtitle: "\(rules.count) rules configured")

            if rules.isEmpty {
                EmptyState("No alert rules configured")
            } else {
                ResourceTable {
                    TableHeader("Name")
                    TableHeader("Type")
                    TableHeader("Severity")
                    TableHeader("Enabled")
                    TableHeader("Cooldown")
                    TableHeader("Namespace Filter")
                } body: {
                    for rule in rules {
                        tr(.class("hover:bg-gray-50")) {
                            TableCell { span(.class("font-medium text-gray-900")) { rule.name } }
                            TableCell {
                                code(.class("text-xs bg-gray-100 px-2 py-1 rounded")) { rule.type.rawValue }
                            }
                            TableCell { SeverityBadge(rule.severity) }
                            TableCell {
                                if rule.enabled {
                                    span(.class("badge badge-healthy")) { "Enabled" }
                                } else {
                                    span(.class("badge badge-unknown")) { "Disabled" }
                                }
                            }
                            TableCell { span(.class("text-gray-600")) { "\(rule.cooldownSeconds)s" } }
                            TableCell { span(.class("text-gray-500")) { rule.namespaceFilter ?? "All" } }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Webhooks Page

/// Page listing configured webhook endpoints.
public struct WebhooksPage: HTML {
    let endpoints: [WebhookEndpoint]

    public init(endpoints: [WebhookEndpoint]) {
        self.endpoints = endpoints
    }

    public var body: some HTML {
        BaseLayout(title: "Webhooks", currentPath: "/alerts/webhooks") {
            PageHeader(title: "Webhook Endpoints", subtitle: "\(endpoints.count) configured")

            if endpoints.isEmpty {
                EmptyState("No webhook endpoints configured")
            } else {
                ResourceTable {
                    TableHeader("Name")
                    TableHeader("URL")
                    TableHeader("Enabled")
                    TableHeader("Retries")
                    TableHeader("Timeout")
                } body: {
                    for endpoint in endpoints {
                        tr(.class("hover:bg-gray-50")) {
                            TableCell { span(.class("font-medium text-gray-900")) { endpoint.name } }
                            TableCell {
                                code(.class("text-xs bg-gray-100 px-2 py-1 rounded break-all")) { endpoint.url }
                            }
                            TableCell {
                                if endpoint.enabled {
                                    span(.class("badge badge-healthy")) { "Active" }
                                } else {
                                    span(.class("badge badge-unknown")) { "Disabled" }
                                }
                            }
                            TableCell { span(.class("text-gray-600")) { "\(endpoint.retryCount)" } }
                            TableCell { span(.class("text-gray-600")) { "\(endpoint.timeoutSeconds)s" } }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Alert Component Helpers

/// Badge for alert severity.
public struct SeverityBadge: HTML {
    let severity: AlertSeverity

    public init(_ severity: AlertSeverity) {
        self.severity = severity
    }

    public var body: some HTML {
        switch severity {
        case .info:
            span(.class("badge badge-info")) { "Info" }
        case .warning:
            span(.class("badge badge-warning")) { "Warning" }
        case .critical:
            span(.class("badge badge-error")) { "Critical" }
        }
    }
}

/// Badge for alert delivery status.
public struct DeliveryStatusBadge: HTML {
    let status: AlertDeliveryStatus

    public init(_ status: AlertDeliveryStatus) {
        self.status = status
    }

    public var body: some HTML {
        switch status {
        case .pending:
            span(.class("badge badge-warning")) { "Pending" }
        case .delivered:
            span(.class("badge badge-healthy")) { "Delivered" }
        case .failed:
            span(.class("badge badge-error")) { "Failed" }
        case .cooldown:
            span(.class("badge badge-unknown")) { "Cooldown" }
        }
    }
}
