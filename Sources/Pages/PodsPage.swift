/// Pod list and detail pages.
///
/// The pod list page shows all pods with health indicators, phase badges,
/// and namespace filtering. Live updates via HTMX SSE.
/// The pod detail page shows containers, conditions, events, and streaming logs.

import Components
import Elementary
import ElementaryHTMX
import ElementaryHTMXSSE
import Models

// MARK: - Pod List Page

/// Page listing all pods with filtering and live updates.
public struct PodListPage: HTML {
    let pods: [PodInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(pods: [PodInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.pods = pods
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "Pods", currentPath: "/pods") {
            PageHeader(title: "Pods", subtitle: "\(pods.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/pods/list")
            }

            div(.id("resource-list"),
                .attribute("hx-get", value: "/partials/pods/list\(selectedNamespace.map { "?namespace=\($0)" } ?? "")"),
                .attribute("hx-trigger", value: "every 5s"),
                .attribute("hx-swap", value: "innerHTML")
            ) {
                PodListPartial(pods: pods)
            }
        }
    }
}

/// Partial for the pod list table, used by HTMX updates.
public struct PodListPartial: HTML {
    let pods: [PodInfo]

    public var content: some HTML {
        if pods.isEmpty {
            EmptyState("No pods found")
        } else {
            ResourceTable {
                TableHeader("Name")
                TableHeader("Namespace")
                TableHeader("Status")
                TableHeader("Ready")
                TableHeader("Restarts")
                TableHeader("Node")
                TableHeader("Age")
            } body: {
                for pod in pods {
                    tr(.class("hover:bg-gray-50")) {
                        TableCell {
                            a(.href("/pods/\(pod.namespace)/\(pod.name)"),
                              .class("text-blue-600 hover:text-blue-800 font-medium")) {
                                pod.name
                            }
                        }
                        TableCell { span(.class("text-gray-700")) { pod.namespace } }
                        TableCell { PodPhaseBadge(pod.phase) }
                        TableCell {
                            let readyCount = pod.containers.filter { $0.ready }.count
                            span(.class(readyCount == pod.containers.count ? "text-green-600" : "text-yellow-600")) {
                                "\(readyCount)/\(pod.containers.count)"
                            }
                        }
                        TableCell {
                            let restarts = pod.containers.reduce(0) { $0 + $1.restartCount }
                            span(.class(restarts > 5 ? "text-red-600 font-medium" : "text-gray-600")) {
                                "\(restarts)"
                            }
                        }
                        TableCell { span(.class("text-gray-500")) { pod.nodeName ?? "-" } }
                        TableCell { Timestamp(pod.startTime) }
                    }
                }
            }
        }
    }
}

// MARK: - Pod Detail Page

/// Detailed view of a single pod with containers, events, and log streaming.
public struct PodDetailPage: HTML {
    let pod: PodInfo
    let events: [EventInfo]

    public init(pod: PodInfo, events: [EventInfo] = []) {
        self.pod = pod
        self.events = events
    }

    public var content: some HTML {
        BaseLayout(title: "Pod: \(pod.name)", currentPath: "/pods") {
            // Breadcrumb
            nav(.class("flex items-center space-x-2 text-sm text-gray-500 mb-4")) {
                a(.href("/pods"), .class("hover:text-blue-600")) { "Pods" }
                span { "/" }
                span(.class("text-gray-900")) { pod.name }
            }

            PageHeader(title: pod.name, subtitle: "Namespace: \(pod.namespace)") {
                PodPhaseBadge(pod.phase)
                HealthBadge(pod.health)
            }

            // Pod info grid
            div(.class("grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6")) {
                // Metadata card
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Metadata" }
                    dl(.class("space-y-2")) {
                        DetailRow(label: "Namespace", value: pod.namespace)
                        DetailRow(label: "Node", value: pod.nodeName ?? "-")
                        if let ownerKind = pod.ownerKind, let ownerName = pod.ownerName {
                            DetailRow(label: "Owner", value: "\(ownerKind)/\(ownerName)")
                        }
                        DetailRow(label: "Started", value: pod.startTime.map { ISO8601DateFormatter().string(from: $0) } ?? "-")
                    }
                }

                // Labels card
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Labels" }
                    LabelsDisplay(pod.labels, maxDisplay: 10)
                }

                // Status card
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Status" }
                    dl(.class("space-y-2")) {
                        DetailRow(label: "Phase", value: pod.phase.rawValue)
                        DetailRow(label: "Containers", value: "\(pod.containers.count)")
                        DetailRow(label: "Ready", value: "\(pod.containers.filter { $0.ready }.count)/\(pod.containers.count)")
                        DetailRow(label: "Total Restarts", value: "\(pod.containers.reduce(0) { $0 + $1.restartCount })")
                    }
                }
            }

            // Containers section
            div(.class("bg-white rounded-lg shadow mb-6")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Containers" }
                }
                div(.class("divide-y divide-gray-200")) {
                    for container in pod.containers {
                        ContainerRow(container: container, podNamespace: pod.namespace, podName: pod.name)
                    }
                }
            }

            // Log viewer section
            div(.class("bg-white rounded-lg shadow mb-6")) {
                div(.class("px-6 py-4 border-b border-gray-200 flex items-center justify-between")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Logs" }
                    div(.class("flex items-center space-x-2")) {
                        if !pod.containers.isEmpty {
                            select(
                                .class("rounded-md border-gray-300 text-sm"),
                                .id("log-container-select")
                            ) {
                                for container in pod.containers {
                                    option(.value(container.name)) { container.name }
                                }
                            }
                        }
                        button(
                            .class("px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700"),
                            .attribute("hx-get", value: "/api/pods/\(pod.namespace)/\(pod.name)/logs?tailLines=200"),
                            .attribute("hx-target", value: "#log-output"),
                            .attribute("hx-swap", value: "innerHTML"),
                            .attribute("hx-include", value: "#log-container-select")
                        ) { "Load Logs" }
                    }
                }
                div(.class("log-viewer"), .id("log-output")) {
                    p(.class("text-gray-400")) { "Click 'Load Logs' to view container logs" }
                }
            }

            // Events section
            div(.class("bg-white rounded-lg shadow")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Events" }
                }
                div(.class("p-6")) {
                    if events.isEmpty {
                        EmptyState("No events for this pod")
                    } else {
                        RecentEventsPanel(events: events)
                    }
                }
            }
        }
    }
}

// MARK: - Container Row

/// A row displaying information about a single container.
public struct ContainerRow: HTML {
    let container: ContainerInfo
    let podNamespace: String
    let podName: String

    public var content: some HTML {
        div(.class("px-6 py-4")) {
            div(.class("flex items-center justify-between")) {
                div(.class("flex items-center space-x-3")) {
                    div(.class("w-3 h-3 rounded-full \(container.ready ? "bg-green-400" : "bg-red-400")")) {}
                    div {
                        p(.class("text-sm font-medium text-gray-900")) { container.name }
                        p(.class("text-xs text-gray-500")) { container.image }
                    }
                }
                div(.class("flex items-center space-x-4")) {
                    ContainerStateBadge(state: container.state)
                    if container.restartCount > 0 {
                        span(.class("text-xs text-gray-500")) { "\(container.restartCount) restarts" }
                    }
                }
            }
        }
    }
}

/// Badge showing container state.
public struct ContainerStateBadge: HTML {
    let state: ContainerState

    public var content: some HTML {
        switch state {
        case .running:
            span(.class("badge badge-healthy")) { "Running" }
        case .waiting(let reason):
            span(.class("badge badge-warning")) { reason ?? "Waiting" }
        case .terminated(let reason, let exitCode, _):
            span(.class("badge \(exitCode == 0 ? "badge-info" : "badge-error")")) {
                reason ?? "Terminated(\(exitCode))"
            }
        }
    }
}

// MARK: - Detail Row

/// A key-value row for detail cards.
public struct DetailRow: HTML {
    let label: String
    let value: String

    public var content: some HTML {
        div(.class("flex justify-between")) {
            dt(.class("text-sm text-gray-500")) { label }
            dd(.class("text-sm text-gray-900")) { value }
        }
    }
}
