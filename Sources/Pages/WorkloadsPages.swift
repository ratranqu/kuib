/// StatefulSet, DaemonSet list pages.

import Components
import Elementary
import Models

// MARK: - StatefulSet List

/// Page listing all StatefulSets.
public struct StatefulSetListPage: HTML {
    let statefulSets: [StatefulSetInfo]
    let namespaces: [NamespaceInfo]
    let filter: ResourceFilter

    public init(statefulSets: [StatefulSetInfo], namespaces: [NamespaceInfo], filter: ResourceFilter = ResourceFilter()) {
        self.statefulSets = statefulSets
        self.namespaces = namespaces
        self.filter = filter
    }

    public var body: some HTML {
        BaseLayout(title: "StatefulSets", currentPath: "/statefulsets") {
            PageHeader(title: "StatefulSets", subtitle: "\(statefulSets.count) total")

            ResourceFilterBar(namespaces: namespaces, filter: filter, targetUrl: "/partials/statefulsets/list")
            div(.id("resource-list")) {
                if statefulSets.isEmpty {
                    EmptyState("No StatefulSets found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Health")
                        TableHeader("Ready")
                        TableHeader("Current")
                    } body: {
                        for ss in statefulSets {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { ss.name } }
                                TableCell { span(.class("text-gray-700")) { ss.namespace } }
                                TableCell { HealthBadge(ss.health) }
                                TableCell {
                                    span(.class(ss.readyReplicas == ss.replicas ? "text-green-600" : "text-yellow-600")) {
                                        "\(ss.readyReplicas)/\(ss.replicas)"
                                    }
                                }
                                TableCell { span { "\(ss.currentReplicas)" } }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DaemonSet List

/// Page listing all DaemonSets.
public struct DaemonSetListPage: HTML {
    let daemonSets: [DaemonSetInfo]
    let namespaces: [NamespaceInfo]
    let filter: ResourceFilter

    public init(daemonSets: [DaemonSetInfo], namespaces: [NamespaceInfo], filter: ResourceFilter = ResourceFilter()) {
        self.daemonSets = daemonSets
        self.namespaces = namespaces
        self.filter = filter
    }

    public var body: some HTML {
        BaseLayout(title: "DaemonSets", currentPath: "/daemonsets") {
            PageHeader(title: "DaemonSets", subtitle: "\(daemonSets.count) total")

            ResourceFilterBar(namespaces: namespaces, filter: filter, targetUrl: "/partials/daemonsets/list")
            div(.id("resource-list")) {
                if daemonSets.isEmpty {
                    EmptyState("No DaemonSets found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Health")
                        TableHeader("Desired")
                        TableHeader("Current")
                        TableHeader("Ready")
                        TableHeader("Available")
                    } body: {
                        for ds in daemonSets {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { ds.name } }
                                TableCell { span(.class("text-gray-700")) { ds.namespace } }
                                TableCell { HealthBadge(ds.health) }
                                TableCell { span { "\(ds.desiredNumberScheduled)" } }
                                TableCell { span { "\(ds.currentNumberScheduled)" } }
                                TableCell { span(.class(ds.numberReady == ds.desiredNumberScheduled ? "text-green-600" : "text-yellow-600")) { "\(ds.numberReady)" } }
                                TableCell { span { "\(ds.numberAvailable)" } }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Namespace List

/// Page listing all Namespaces.
public struct NamespaceListPage: HTML {
    let namespaces: [NamespaceInfo]

    public init(namespaces: [NamespaceInfo]) {
        self.namespaces = namespaces
    }

    public var body: some HTML {
        BaseLayout(title: "Namespaces", currentPath: "/namespaces") {
            PageHeader(title: "Namespaces", subtitle: "\(namespaces.count) total")

            if namespaces.isEmpty {
                EmptyState("No namespaces found")
            } else {
                ResourceTable {
                    TableHeader("Name")
                    TableHeader("Status")
                    TableHeader("Labels")
                } body: {
                    for ns in namespaces {
                        tr(.class("hover:bg-gray-50")) {
                            TableCell {
                                span(.class("font-medium text-gray-900")) { ns.name }
                            }
                            TableCell {
                                let badgeClass = ns.status == "Active" ? "badge-healthy" : "badge-warning"
                                span(.class("badge \(badgeClass)")) { ns.status }
                            }
                            TableCell { LabelsDisplay(ns.labels) }
                        }
                    }
                }
            }
        }
    }
}
