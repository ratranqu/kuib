/// Node list and Events stream pages.

import Components
import Elementary
import ElementaryHTMX
import Models

// MARK: - Node List

/// Page listing all Nodes.
public struct NodeListPage: HTML {
    let nodes: [NodeInfo]

    public init(nodes: [NodeInfo]) {
        self.nodes = nodes
    }

    public var body: some HTML {
        BaseLayout(title: "Nodes", currentPath: "/nodes") {
            PageHeader(title: "Nodes", subtitle: "\(nodes.count) total")

            if nodes.isEmpty {
                EmptyState("No nodes found")
            } else {
                ResourceTable {
                    TableHeader("Name")
                    TableHeader("Status")
                    TableHeader("Roles")
                    TableHeader("Version")
                    TableHeader("OS")
                    TableHeader("CPU")
                    TableHeader("Memory")
                } body: {
                    for node in nodes {
                        tr(.class("hover:bg-gray-50")) {
                            TableCell {
                                a(.href("/nodes/\(node.name)"),
                                  .class("text-blue-600 hover:text-blue-800 font-medium")) { node.name }
                            }
                            TableCell { HealthBadge(node.health, label: node.ready ? "Ready" : "NotReady") }
                            TableCell {
                                div(.class("flex flex-wrap gap-1")) {
                                    for role in node.roles {
                                        span(.class("badge badge-info")) { role }
                                    }
                                }
                            }
                            TableCell { span(.class("text-gray-600 text-xs")) { node.kubeletVersion } }
                            TableCell { span(.class("text-gray-500 text-xs")) { node.osImage } }
                            TableCell { span(.class("font-mono text-xs")) { node.allocatableCPU } }
                            TableCell { span(.class("font-mono text-xs")) { node.allocatableMemory } }
                        }
                    }
                }
            }
        }
    }
}

/// Detail page for a single Node.
public struct NodeDetailPage: HTML {
    let node: NodeInfo
    let pods: [PodInfo]

    public init(node: NodeInfo, pods: [PodInfo] = []) {
        self.node = node
        self.pods = pods
    }

    public var body: some HTML {
        BaseLayout(title: "Node: \(node.name)", currentPath: "/nodes") {
            nav(.class("flex items-center space-x-2 text-sm text-gray-500 mb-4")) {
                a(.href("/nodes"), .class("hover:text-blue-600")) { "Nodes" }
                span { "/" }
                span(.class("text-gray-900")) { node.name }
            }

            PageHeader(title: node.name) {
                HealthBadge(node.health, label: node.ready ? "Ready" : "NotReady")
            }

            // Node info
            div(.class("grid grid-cols-1 md:grid-cols-3 gap-6 mb-6")) {
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Info" }
                    dl(.class("space-y-2")) {
                        DetailRow(label: "Roles", value: node.roles.joined(separator: ", "))
                        DetailRow(label: "Kubelet", value: node.kubeletVersion)
                        DetailRow(label: "OS", value: node.osImage)
                    }
                }
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Resources" }
                    dl(.class("space-y-2")) {
                        DetailRow(label: "CPU", value: node.allocatableCPU)
                        DetailRow(label: "Memory", value: node.allocatableMemory)
                    }
                }
                div(.class("bg-white rounded-lg shadow p-6")) {
                    h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Conditions" }
                    div(.class("space-y-2")) {
                        for condition in node.conditions {
                            div(.class("flex justify-between text-sm")) {
                                span(.class("text-gray-500")) { condition.type }
                                span(.class(condition.status == "True" && condition.type == "Ready" ? "text-green-600" : condition.status == "True" ? "text-red-600" : "text-green-600")) {
                                    condition.status
                                }
                            }
                        }
                    }
                }
            }

            // Pods on this node
            div(.class("bg-white rounded-lg shadow")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Pods on this Node (\(pods.count))" }
                }
                div(.class("p-6")) {
                    PodListPartial(pods: pods)
                }
            }
        }
    }
}

// MARK: - Events Page

/// Page showing cluster-wide event stream with search and filtering.
public struct EventsPage: HTML {
    let events: [EventInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?
    let filterReason: String?

    public init(events: [EventInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil, filterReason: String? = nil) {
        self.events = events
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
        self.filterReason = filterReason
    }

    public var body: some HTML {
        BaseLayout(title: "Events", currentPath: "/events") {
            PageHeader(title: "Events", subtitle: "\(events.count) events") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/events/list")
            }

            // Filters
            div(.class("bg-white rounded-lg shadow p-4 mb-6 flex items-center space-x-4")) {
                input(
                    .type(.text),
                    .class("rounded-md border-gray-300 shadow-sm text-sm flex-1"),
                    .name("search"),
                    .attribute("placeholder", value: "Search events..."),
                    .attribute("hx-get", value: "/partials/events/list"),
                    .attribute("hx-target", value: "#events-list"),
                    .attribute("hx-trigger", value: "keyup changed delay:300ms"),
                    .attribute("hx-include", value: "[name='namespace'], [name='type']")
                )
                select(
                    .class("rounded-md border-gray-300 shadow-sm text-sm"),
                    .name("type"),
                    .attribute("hx-get", value: "/partials/events/list"),
                    .attribute("hx-target", value: "#events-list"),
                    .attribute("hx-trigger", value: "change"),
                    .attribute("hx-include", value: "[name='namespace'], [name='search']")
                ) {
                    option(.value("")) { "All Types" }
                    option(.value("Normal")) { "Normal" }
                    option(.value("Warning")) { "Warning" }
                }
            }

            div(
                .id("events-list"),
                .attribute("hx-get", value: "/partials/events/list"),
                .attribute("hx-trigger", value: "every 5s"),
                .attribute("hx-swap", value: "innerHTML")
            ) {
                EventsListPartial(events: events)
            }
        }
    }
}

/// Partial for events table.
public struct EventsListPartial: HTML {
    let events: [EventInfo]

    public var body: some HTML {
        if events.isEmpty {
            EmptyState("No events found")
        } else {
            ResourceTable {
                TableHeader("Type")
                TableHeader("Reason")
                TableHeader("Object")
                TableHeader("Message")
                TableHeader("Count")
                TableHeader("Last Seen")
            } body: {
                for event in events {
                    tr(.class("hover:bg-gray-50")) {
                        TableCell {
                            let badgeClass = event.type == "Warning" ? "badge-warning" : "badge-healthy"
                            span(.class("badge \(badgeClass)")) { event.type }
                        }
                        TableCell { span(.class("font-medium text-gray-700")) { event.reason } }
                        TableCell {
                            span(.class("text-gray-600 text-xs")) {
                                "\(event.involvedObjectKind)/\(event.involvedObjectName)"
                            }
                        }
                        TableCell {
                            span(.class("text-gray-600 text-xs truncate max-w-md block")) { event.message }
                        }
                        TableCell { span(.class("text-gray-500")) { "\(event.count)" } }
                        TableCell { Timestamp(event.lastTimestamp) }
                    }
                }
            }
        }
    }
}
