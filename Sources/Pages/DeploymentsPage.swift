/// Deployment list and detail pages.

import Components
import Elementary
import Models

/// Page listing all deployments.
public struct DeploymentListPage: HTML {
    let deployments: [DeploymentInfo]
    let namespaces: [NamespaceInfo]
    let filter: ResourceFilter

    public init(deployments: [DeploymentInfo], namespaces: [NamespaceInfo], filter: ResourceFilter = ResourceFilter()) {
        self.deployments = deployments
        self.namespaces = namespaces
        self.filter = filter
    }

    public var body: some HTML {
        BaseLayout(title: "Deployments", currentPath: "/deployments") {
            PageHeader(title: "Deployments", subtitle: "\(deployments.count) total")

            ResourceFilterBar(namespaces: namespaces, filter: filter, targetUrl: "/partials/deployments/list")

            div(.id("resource-list"),
                .attribute("hx-get", value: "/partials/deployments/list\(filter.queryString)"),
                .attribute("hx-trigger", value: "every 10s"),
                .attribute("hx-swap", value: "innerHTML")
            ) {
                DeploymentListPartial(deployments: deployments)
            }
        }
    }
}

/// Partial for deployment list table.
public struct DeploymentListPartial: HTML {
    let deployments: [DeploymentInfo]

    public var body: some HTML {
        if deployments.isEmpty {
            EmptyState("No deployments found")
        } else {
            ResourceTable {
                TableHeader("Name")
                TableHeader("Namespace")
                TableHeader("Health")
                TableHeader("Ready")
                TableHeader("Up-to-date")
                TableHeader("Available")
                TableHeader("Age")
            } body: {
                for d in deployments {
                    tr(.class("hover:bg-gray-50")) {
                        TableCell {
                            a(.href("/deployments/\(d.namespace)/\(d.name)"),
                              .class("text-blue-600 hover:text-blue-800 font-medium")) { d.name }
                        }
                        TableCell { span(.class("text-gray-700")) { d.namespace } }
                        TableCell { HealthBadge(d.health) }
                        TableCell {
                            span(.class(d.readyReplicas == d.replicas ? "text-green-600" : "text-yellow-600")) {
                                "\(d.readyReplicas)/\(d.replicas)"
                            }
                        }
                        TableCell { span { "\(d.updatedReplicas)" } }
                        TableCell { span { "\(d.availableReplicas)" } }
                        TableCell { Timestamp(d.creationTimestamp) }
                    }
                }
            }
        }
    }
}

/// Detail page for a single deployment.
public struct DeploymentDetailPage: HTML {
    let deployment: DeploymentInfo
    let pods: [PodInfo]
    let events: [EventInfo]

    public init(deployment: DeploymentInfo, pods: [PodInfo] = [], events: [EventInfo] = []) {
        self.deployment = deployment
        self.pods = pods
        self.events = events
    }

    public var body: some HTML {
        BaseLayout(title: "Deployment: \(deployment.name)", currentPath: "/deployments") {
            nav(.class("flex items-center space-x-2 text-sm text-gray-500 mb-4")) {
                a(.href("/deployments"), .class("hover:text-blue-600")) { "Deployments" }
                span { "/" }
                span(.class("text-gray-900")) { deployment.name }
            }

            PageHeader(title: deployment.name, subtitle: "Namespace: \(deployment.namespace)") {
                HealthBadge(deployment.health)
            }

            // Replica stats
            div(.class("grid grid-cols-1 md:grid-cols-4 gap-6 mb-6")) {
                StatCard(label: "Desired", value: "\(deployment.replicas)", color: "blue")
                StatCard(label: "Ready", value: "\(deployment.readyReplicas)", color: deployment.readyReplicas == deployment.replicas ? "green" : "yellow")
                StatCard(label: "Updated", value: "\(deployment.updatedReplicas)", color: "blue")
                StatCard(label: "Available", value: "\(deployment.availableReplicas)", color: deployment.availableReplicas == deployment.replicas ? "green" : "red")
            }

            // Labels
            div(.class("bg-white rounded-lg shadow p-6 mb-6")) {
                h3(.class("text-sm font-semibold text-gray-700 mb-3")) { "Labels" }
                LabelsDisplay(deployment.labels, maxDisplay: 10)
            }

            // Managed pods
            div(.class("bg-white rounded-lg shadow mb-6")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Pods (\(pods.count))" }
                }
                div(.class("p-6")) {
                    if pods.isEmpty {
                        EmptyState("No pods found for this deployment")
                    } else {
                        PodListPartial(pods: pods)
                    }
                }
            }

            // Events
            div(.class("bg-white rounded-lg shadow")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Events" }
                }
                div(.class("p-6")) {
                    RecentEventsPanel(events: events)
                }
            }
        }
    }
}
