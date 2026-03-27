/// Reusable HTML components for rendering Kubernetes resource information.
///
/// These components are used across multiple pages to provide consistent
/// rendering of status badges, health indicators, resource cards, and tables.

import Elementary
import Foundation
import Models

// MARK: - Custom Attribute Helper

extension HTMLAttribute where Tag: HTMLTrait.Attributes.Global {
    /// Creates a custom HTML attribute with the given name and value.
    public static func attribute(_ name: String, value: String) -> Self {
        .init(name: name, value: value)
    }
}

// MARK: - Health Badge

/// Renders a colored badge indicating resource health status.
public struct HealthBadge: HTML {
    let health: ResourceHealth
    let label: String?

    public init(_ health: ResourceHealth, label: String? = nil) {
        self.health = health
        self.label = label
    }

    public var body: some HTML {
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

        return span(.class("badge \(badgeClass)")) { text }
    }
}

// MARK: - Pod Phase Badge

/// Renders a badge for a pod's phase.
public struct PodPhaseBadge: HTML {
    let phase: PodPhase

    public init(_ phase: PodPhase) {
        self.phase = phase
    }

    public var body: some HTML {
        let badgeClass: String
        switch phase {
        case .running: badgeClass = "badge-healthy"
        case .succeeded: badgeClass = "badge-info"
        case .pending: badgeClass = "badge-warning"
        case .failed: badgeClass = "badge-error"
        case .unknown: badgeClass = "badge-unknown"
        }
        return span(.class("badge \(badgeClass)")) { phase.rawValue }
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

    public var body: some HTML {
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
public struct ResourceTable<Header: HTML, TableBody: HTML>: HTML {
    @HTMLBuilder public let header: Header
    @HTMLBuilder public let tableBody: TableBody

    public init(@HTMLBuilder header: () -> Header, @HTMLBuilder body: () -> TableBody) {
        self.header = header()
        self.tableBody = body()
    }

    public var body: some HTML {
        div(.class("bg-white shadow rounded-lg overflow-hidden")) {
            div(.class("overflow-x-auto")) {
                table(.class("min-w-full divide-y divide-gray-200")) {
                    thead(.class("bg-gray-50")) {
                        tr { header }
                    }
                    tbody(.class("bg-white divide-y divide-gray-200")) {
                        tableBody
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

    public var body: some HTML {
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

    public var body: some HTML {
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

    public var body: some HTML {
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

    public var body: some HTML {
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

// MARK: - Resource Filter Bar

/// A comprehensive filter bar combining namespace, label selectors, health, and name search.
///
/// All filter inputs use HTMX to dynamically update the resource list without full page reloads.
/// Filters are combined with AND logic — a resource must match all active criteria.
public struct ResourceFilterBar: HTML {
    let namespaces: [NamespaceInfo]
    let filter: ResourceFilter
    let targetUrl: String
    let showHealthFilter: Bool

    public init(
        namespaces: [NamespaceInfo],
        filter: ResourceFilter,
        targetUrl: String,
        showHealthFilter: Bool = true
    ) {
        self.namespaces = namespaces
        self.filter = filter
        self.targetUrl = targetUrl
        self.showHealthFilter = showHealthFilter
    }

    /// Names of all filter inputs for hx-include.
    private var includeSelector: String {
        "[name='namespace'],[name='labels'],[name='search']\(showHealthFilter ? ",[name='health']" : "")"
    }

    public var body: some HTML {
        div(.class("flex flex-wrap items-center gap-3 mb-6 p-4 bg-white rounded-lg shadow")) {
            // Namespace dropdown
            select(
                .class("block w-48 rounded-md border-gray-300 shadow-sm text-sm"),
                .name("namespace"),
                .attribute("hx-get", value: targetUrl),
                .attribute("hx-target", value: "#resource-list"),
                .attribute("hx-trigger", value: "change"),
                .attribute("hx-include", value: includeSelector)
            ) {
                option(.value("")) { "All Namespaces" }
                for ns in namespaces {
                    if ns.name == filter.namespace {
                        option(.value(ns.name), .selected) { ns.name }
                    } else {
                        option(.value(ns.name)) { ns.name }
                    }
                }
            }

            // Label selector input
            div(.class("relative")) {
                input(
                    .class("block w-56 rounded-md border-gray-300 shadow-sm text-sm pl-8"),
                    .type(.text),
                    .name("labels"),
                    .value(filter.labelSelectors.map { "\($0.key)=\($0.value)" }.joined(separator: ",")),
                    .attribute("placeholder", value: "Labels: app=nginx,env=prod"),
                    .attribute("hx-get", value: targetUrl),
                    .attribute("hx-target", value: "#resource-list"),
                    .attribute("hx-trigger", value: "keyup changed delay:400ms"),
                    .attribute("hx-include", value: includeSelector)
                )
                div(.class("absolute inset-y-0 left-0 flex items-center pl-2 pointer-events-none")) {
                    span(.class("text-gray-400 text-xs")) { "L" }
                }
            }

            // Name search input
            div(.class("relative")) {
                input(
                    .class("block w-48 rounded-md border-gray-300 shadow-sm text-sm pl-8"),
                    .type(.text),
                    .name("search"),
                    .value(filter.nameContains ?? ""),
                    .attribute("placeholder", value: "Search by name..."),
                    .attribute("hx-get", value: targetUrl),
                    .attribute("hx-target", value: "#resource-list"),
                    .attribute("hx-trigger", value: "keyup changed delay:300ms"),
                    .attribute("hx-include", value: includeSelector)
                )
                div(.class("absolute inset-y-0 left-0 flex items-center pl-2 pointer-events-none")) {
                    span(.class("text-gray-400 text-xs")) { "S" }
                }
            }

            // Health filter dropdown (only for resources that have health)
            if showHealthFilter {
                select(
                    .class("block w-36 rounded-md border-gray-300 shadow-sm text-sm"),
                    .name("health"),
                    .attribute("hx-get", value: targetUrl),
                    .attribute("hx-target", value: "#resource-list"),
                    .attribute("hx-trigger", value: "change"),
                    .attribute("hx-include", value: includeSelector)
                ) {
                    option(.value("")) { "All Status" }
                    if filter.health == .healthy {
                        option(.value("healthy"), .selected) { "Healthy" }
                    } else {
                        option(.value("healthy")) { "Healthy" }
                    }
                    if filter.health == .warning {
                        option(.value("warning"), .selected) { "Warning" }
                    } else {
                        option(.value("warning")) { "Warning" }
                    }
                    if filter.health == .error {
                        option(.value("error"), .selected) { "Error" }
                    } else {
                        option(.value("error")) { "Error" }
                    }
                    if filter.health == .unknown {
                        option(.value("unknown"), .selected) { "Unknown" }
                    } else {
                        option(.value("unknown")) { "Unknown" }
                    }
                }
            }

            // Active filter count badge
            if !filter.isEmpty {
                let activeCount = (filter.namespace != nil ? 1 : 0)
                    + (filter.labelSelectors.isEmpty ? 0 : 1)
                    + (filter.health != nil ? 1 : 0)
                    + (filter.nameContains != nil && !filter.nameContains!.isEmpty ? 1 : 0)
                span(.class("inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-700")) {
                    "\(activeCount) active filter\(activeCount == 1 ? "" : "s")"
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

    public var body: some HTML {
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

    private var formattedDate: String? {
        date.map { ISO8601DateFormatter().string(from: $0) }
    }

    public var body: some HTML {
        if let formatted = formattedDate {
            span(.class("text-gray-500")) { formatted }
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

    public var body: some HTML {
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
