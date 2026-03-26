/// Services and Ingresses list pages.

import Components
import Elementary
import Models

// MARK: - Service List

/// Page listing all Services.
public struct ServiceListPage: HTML {
    let services: [ServiceInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(services: [ServiceInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.services = services
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "Services", currentPath: "/services") {
            PageHeader(title: "Services", subtitle: "\(services.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/services/list")
            }
            div(.id("resource-list")) {
                if services.isEmpty {
                    EmptyState("No services found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Type")
                        TableHeader("Cluster IP")
                        TableHeader("Ports")
                    } body: {
                        for svc in services {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { svc.name } }
                                TableCell { span(.class("text-gray-700")) { svc.namespace } }
                                TableCell {
                                    span(.class("badge badge-info")) { svc.type }
                                }
                                TableCell { span(.class("text-gray-600 font-mono text-xs")) { svc.clusterIP ?? "-" } }
                                TableCell {
                                    div(.class("flex flex-wrap gap-1")) {
                                        for port in svc.ports {
                                            span(.class("text-xs bg-gray-100 px-2 py-0.5 rounded font-mono")) {
                                                "\(port.port)/\(port.protocol_)"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Ingress List

/// Page listing all Ingresses.
public struct IngressListPage: HTML {
    let ingresses: [IngressInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(ingresses: [IngressInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.ingresses = ingresses
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "Ingresses", currentPath: "/ingresses") {
            PageHeader(title: "Ingresses", subtitle: "\(ingresses.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/ingresses/list")
            }
            div(.id("resource-list")) {
                if ingresses.isEmpty {
                    EmptyState("No ingresses found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Class")
                        TableHeader("Hosts")
                    } body: {
                        for ing in ingresses {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { ing.name } }
                                TableCell { span(.class("text-gray-700")) { ing.namespace } }
                                TableCell { span(.class("text-gray-600")) { ing.ingressClassName ?? "-" } }
                                TableCell {
                                    div(.class("flex flex-wrap gap-1")) {
                                        for host in ing.hosts {
                                            span(.class("text-xs bg-blue-50 text-blue-700 px-2 py-0.5 rounded")) { host }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
