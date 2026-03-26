/// Reusable HTML components for rendering Kubernetes resource information.
///
/// These components are used across multiple pages to provide consistent
/// rendering of status badges, health indicators, resource cards, and tables.

import Elementary
import Models

// MARK: - Health Badge

/// Renders a colored badge indicating resource health status.
public struct HealthBadge: HTML {
    let health: ResourceHealth
    let label: String?

    public init(_ health: ResourceHealth, label: String? = nil) {
        self.health = health
        self.label = label
    }

    public var content: some HTML {
        let badgeClass: String
        let text: String

        switch health {
        case .healthy:
            badgeClass = "badge-healthy"
            text = label ?? "Healthy"
        case .warning:
            badgeClass = "badge-warning"
            text = label ?? "Warning"
        case .error:
            badgeClass = "badge-error"
            text = label ?? "Error"
        case .unknown:
            badgeClass = "badge-unknown"
            text = label ?? "Unknown"
        }

        span(.class("badge \(badgeClass)")) { text }
    }
}

// MARK: - Pod Phase Badge

/// Renders a badge for a pod's phase.
public struct PodPhaseBadge: HTML {
    let phase: PodPhase

    public init(_ phase: PodPhase) {
        self.phase = phase
    }

    public var content: some HTML {
        let badgeClass: String
        switch phase {
        case .running: badgeClass = "badge-healthy"
        case .succeeded: badgeClass = "badge-info"
        case .pending: badgeClass = "badge-warning"
        case .failed: badgeClass = "badge-error"
        case .unknown: badgeClass = "badge-unknown"
        }
        span(.class("badge \(badgeClass)")) { phase.rawValue }
    }
}

// MARK: - Stat Card

/// A dashboard stat card showing a metric with label and optional trend.
public struct StatCard: HTML {
    let label: String
    let value: String
    let color: String
    let subtitle: String?

    public init(label: String, value: String, color: String = "blue", subtitle: String? = nil) {
        self.label = label
        self.value = value
        self.color = color
        self.subtitle = subtitle
    }

    public var content: some HTML {
        div(.class("bg-white rounded-lg shadow p-6")) {
            div(.class("flex items-center justify-between")) {
                div {
                    p(.class("text-sm font-medium text-gray-600")) { label }
                    p(.class("text-3xl font-bold text-gray-900 mt-1")) { value }
                    if let sub = subtitle {
                        p(.class("text-sm text-gray-500 mt-1")) { sub }
                    }
                }
                div(.class("w-12 h-12 rounded-full bg-\(color)-100 flex items-center justify-center")) {
                    span(.class("text-\(color)-600 text-xl font-bold")) {
                        String(label.prefix(1))
                    }
                }
            }
        }
    }
}

// MARK: - Resource Table

/// A styled table wrapper for resource listings.
public struct ResourceTable<Header: HTML, Body: HTML>: HTML {
    @HTMLBuilder let header: Header
    @HTMLBuilder let body: Body

    public init(@HTMLBuilder header: () -> Header, @HTMLBuilder body: () -> Body) {
        self.header = header()
        self.body = body()
    }

    public var content: some HTML {
        div(.class("bg-white shadow rounded-lg overflow-hidden")) {
            div(.class("overflow-x-auto")) {
                table(.class("min-w-full divide-y divide-gray-200")) {
                    thead(.class("bg-gray-50")) {
                        tr { header }
                    }
                    tbody(.class("bg-white divide-y divide-gray-200")) {
                        body
                    }
                }
            }
        }
    }
}

/// A table header cell.
public struct TableHeader: HTML {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var content: some HTML {
        th(.class("px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider")) {
            text
        }
    }
}

/// A table data cell.
public struct TableCell<Content: HTML>: HTML {
    @HTMLBuilder let inner: Content

    public init(@HTMLBuilder _ inner: () -> Content) {
        self.inner = inner()
    }

    public var content: some HTML {
        td(.class("px-6 py-4 whitespace-nowrap text-sm")) {
            inner
        }
    }
}

// MARK: - Page Header

/// A page header with title and optional actions.
public struct PageHeader<Actions: HTML>: HTML {
    let title: String
    let subtitle: String?
    @HTMLBuilder let actions: Actions

    public init(title: String, subtitle: String? = nil, @HTMLBuilder actions: () -> Actions = { EmptyHTML() }) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    public var content: some HTML {
        div(.class("mb-6 flex items-center justify-between")) {
            div {
                h1(.class("text-2xl font-bold text-gray-900")) { title }
                if let sub = subtitle {
                    p(.class("text-sm text-gray-500 mt-1")) { sub }
                }
            }
            div(.class("flex items-center space-x-3")) {
                actions
            }
        }
    }
}

// MARK: - Namespace Filter

/// A namespace filter dropdown for resource list pages.
public struct NamespaceFilter: HTML {
    let namespaces: [NamespaceInfo]
    let selected: String?
    let targetUrl: String

    public init(namespaces: [NamespaceInfo], selected: String?, targetUrl: String) {
        self.namespaces = namespaces
        self.selected = selected
        self.targetUrl = targetUrl
    }

    public var content: some HTML {
        select(
            .class("block w-48 rounded-md border-gray-300 shadow-sm text-sm"),
            .name("namespace"),
            .attribute("hx-get", value: targetUrl),
            .attribute("hx-target", value: "#resource-list"),
            .attribute("hx-trigger", value: "change"),
            .attribute("hx-include", value: "[name='namespace']")
        ) {
            option(.value("")) { "All Namespaces" }
            for ns in namespaces {
                if ns.name == selected {
                    option(.value(ns.name), .selected) { ns.name }
                } else {
                    option(.value(ns.name)) { ns.name }
                }
            }
        }
    }
}

// MARK: - Empty State

/// Shown when a resource list is empty.
public struct EmptyState: HTML {
    let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var content: some HTML {
        div(.class("text-center py-12")) {
            p(.class("text-gray-500 text-lg")) { message }
        }
    }
}

// MARK: - Timestamp

/// Renders a human-friendly timestamp.
public struct Timestamp: HTML {
    let date: Date?

    public init(_ date: Date?) {
        self.date = date
    }

    public var content: some HTML {
        if let date = date {
            let formatter = ISO8601DateFormatter()
            span(.class("text-gray-500")) { formatter.string(from: date) }
        } else {
            span(.class("text-gray-400")) { "-" }
        }
    }
}

// MARK: - Labels Display

/// Renders Kubernetes labels as a list of small badges.
public struct LabelsDisplay: HTML {
    let labels: [String: String]
    let maxDisplay: Int

    public init(_ labels: [String: String], maxDisplay: Int = 3) {
        self.labels = labels
        self.maxDisplay = maxDisplay
    }

    public var content: some HTML {
        div(.class("flex flex-wrap gap-1")) {
            let sortedLabels = labels.sorted { $0.key < $1.key }
            for (index, label) in sortedLabels.enumerated() {
                if index < maxDisplay {
                    span(.class("inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-700")) {
                        "\(label.key)=\(label.value)"
                    }
                }
            }
            if labels.count > maxDisplay {
                span(.class("inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-200 text-gray-600")) {
                    "+\(labels.count - maxDisplay) more"
                }
            }
        }
    }
}
