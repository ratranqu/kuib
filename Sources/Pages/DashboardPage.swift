/// Dashboard page showing a cluster health overview.
///
/// Displays aggregate statistics, health indicators, and recent events
/// in a grid layout. Auto-refreshes via HTMX polling.

import Components
import Elementary
import ElementaryHTMX
import Models

/// Main dashboard page with cluster health overview.
public struct DashboardPage: HTMLDocument {
    public var title: String = "KUIB - Dashboard"

    let summary: ClusterSummary
    let recentEvents: [EventInfo]
    let unhealthyPods: [PodInfo]
    let unhealthyDeployments: [DeploymentInfo]

    public init(
        summary: ClusterSummary,
        recentEvents: [EventInfo] = [],
        unhealthyPods: [PodInfo] = [],
        unhealthyDeployments: [DeploymentInfo] = []
    ) {
        self.summary = summary
        self.recentEvents = recentEvents
        self.unhealthyPods = unhealthyPods
        self.unhealthyDeployments = unhealthyDeployments
    }

    public var head: some HTML {
        EmptyHTML()
    }

    public var body: some HTML {
        BaseLayout(title: "Dashboard", currentPath: "/") {
            // Page header
            PageHeader(title: "Cluster Dashboard", subtitle: "Real-time overview of your Kubernetes cluster")

            // Stats grid
            div(
                .class("grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8"),
                .attribute("hx-get", value: "/partials/dashboard/stats"),
                .attribute("hx-trigger", value: "every 5s"),
                .attribute("hx-swap", value: "innerHTML")
            ) {
                DashboardStats(summary: summary)
            }

            // Two-column layout for issues and events
            div(.class("grid grid-cols-1 lg:grid-cols-2 gap-6")) {
                // Unhealthy resources panel
                div(.class("bg-white rounded-lg shadow")) {
                    div(.class("px-6 py-4 border-b border-gray-200")) {
                        h2(.class("text-lg font-semibold text-gray-900")) { "Issues Requiring Attention" }
                    }
                    div(
                        .class("p-6"),
                        .attribute("hx-get", value: "/partials/dashboard/issues"),
                        .attribute("hx-trigger", value: "every 5s"),
                        .attribute("hx-swap", value: "innerHTML")
                    ) {
                        IssuesPanel(pods: unhealthyPods, deployments: unhealthyDeployments)
                    }
                }

                // Recent events panel
                div(.class("bg-white rounded-lg shadow")) {
                    div(.class("px-6 py-4 border-b border-gray-200")) {
                        h2(.class("text-lg font-semibold text-gray-900")) { "Recent Events" }
                    }
                    div(
                        .class("p-6 max-h-96 overflow-y-auto"),
                        .attribute("hx-get", value: "/partials/dashboard/events"),
                        .attribute("hx-trigger", value: "every 5s"),
                        .attribute("hx-swap", value: "innerHTML")
                    ) {
                        RecentEventsPanel(events: recentEvents)
                    }
                }
            }
        }
    }
}

// MARK: - Dashboard Partials

/// Stats cards partial for HTMX updates.
public struct DashboardStats: HTML {
    let summary: ClusterSummary

    public var content: some HTML {
        StatCard(
            label: "Pods",
            value: "\(summary.runningPods)/\(summary.totalPods)",
            color: summary.failedPods > 0 ? "red" : "green",
            subtitle: summary.failedPods > 0 ? "\(summary.failedPods) failed" : "All healthy"
        )
        StatCard(
            label: "Deployments",
            value: "\(summary.healthyDeployments)/\(summary.totalDeployments)",
            color: summary.healthyDeployments == summary.totalDeployments ? "green" : "yellow",
            subtitle: "\(summary.totalDeployments - summary.healthyDeployments) unhealthy"
        )
        StatCard(
            label: "Nodes",
            value: "\(summary.readyNodes)/\(summary.totalNodes)",
            color: summary.readyNodes == summary.totalNodes ? "green" : "red",
            subtitle: summary.readyNodes == summary.totalNodes ? "All ready" : "\(summary.totalNodes - summary.readyNodes) not ready"
        )
        StatCard(
            label: "Alerts",
            value: "\(summary.recentAlerts)",
            color: summary.recentAlerts > 0 ? "red" : "gray",
            subtitle: summary.recentAlerts > 0 ? "Active alerts" : "No active alerts"
        )
    }
}

/// Panel showing resources with issues.
public struct IssuesPanel: HTML {
    let pods: [PodInfo]
    let deployments: [DeploymentInfo]

    public var content: some HTML {
        if pods.isEmpty && deployments.isEmpty {
            div(.class("text-center py-8")) {
                p(.class("text-green-600 text-lg font-medium")) { "No issues detected" }
                p(.class("text-gray-500 text-sm mt-1")) { "All resources are healthy" }
            }
        } else {
            div(.class("space-y-3")) {
                for pod in pods.prefix(10) {
                    div(.class("flex items-center justify-between p-3 bg-red-50 rounded-lg")) {
                        div {
                            div(.class("flex items-center space-x-2")) {
                                HealthBadge(pod.health)
                                a(.href("/pods/\(pod.namespace)/\(pod.name)"), .class("text-sm font-medium text-gray-900 hover:text-blue-600")) {
                                    pod.name
                                }
                            }
                            p(.class("text-xs text-gray-500 mt-1")) { "Namespace: \(pod.namespace)" }
                        }
                        PodPhaseBadge(pod.phase)
                    }
                }
                for deployment in deployments.prefix(5) {
                    div(.class("flex items-center justify-between p-3 bg-yellow-50 rounded-lg")) {
                        div {
                            div(.class("flex items-center space-x-2")) {
                                HealthBadge(deployment.health)
                                a(.href("/deployments/\(deployment.namespace)/\(deployment.name)"), .class("text-sm font-medium text-gray-900 hover:text-blue-600")) {
                                    deployment.name
                                }
                            }
                            p(.class("text-xs text-gray-500 mt-1")) {
                                "\(deployment.readyReplicas)/\(deployment.replicas) replicas ready"
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Panel showing recent Kubernetes events.
public struct RecentEventsPanel: HTML {
    let events: [EventInfo]

    public var content: some HTML {
        if events.isEmpty {
            EmptyState("No recent events")
        } else {
            div(.class("space-y-2")) {
                for event in events.prefix(20) {
                    div(.class("flex items-start space-x-3 p-2 rounded hover:bg-gray-50")) {
                        let dotColor = event.type == "Warning" ? "bg-yellow-400" : "bg-green-400"
                        div(.class("w-2 h-2 rounded-full mt-2 \(dotColor)")) {}
                        div(.class("flex-1 min-w-0")) {
                            div(.class("flex items-center space-x-2")) {
                                span(.class("text-xs font-medium text-gray-700")) { event.reason }
                                span(.class("text-xs text-gray-400")) {
                                    "\(event.involvedObjectKind)/\(event.involvedObjectName)"
                                }
                            }
                            p(.class("text-xs text-gray-500 mt-0.5 truncate")) { event.message }
                        }
                        if event.count > 1 {
                            span(.class("badge badge-unknown")) { "x\(event.count)" }
                        }
                    }
                }
            }
        }
    }
}
