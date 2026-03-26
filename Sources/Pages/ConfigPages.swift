/// ConfigMap, Secret, and PVC list pages.

import Components
import Elementary
import Models

// MARK: - ConfigMap List

/// Page listing all ConfigMaps.
public struct ConfigMapListPage: HTML {
    let configMaps: [ConfigMapInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(configMaps: [ConfigMapInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.configMaps = configMaps
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "ConfigMaps", currentPath: "/configmaps") {
            PageHeader(title: "ConfigMaps", subtitle: "\(configMaps.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/configmaps/list")
            }
            div(.id("resource-list")) {
                if configMaps.isEmpty {
                    EmptyState("No ConfigMaps found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Keys")
                        TableHeader("Created")
                    } body: {
                        for cm in configMaps {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { cm.name } }
                                TableCell { span(.class("text-gray-700")) { cm.namespace } }
                                TableCell {
                                    div(.class("flex flex-wrap gap-1")) {
                                        for key in cm.dataKeys.prefix(5) {
                                            span(.class("text-xs bg-gray-100 px-2 py-0.5 rounded font-mono")) { key }
                                        }
                                        if cm.dataKeys.count > 5 {
                                            span(.class("text-xs text-gray-500")) { "+\(cm.dataKeys.count - 5) more" }
                                        }
                                    }
                                }
                                TableCell { Timestamp(cm.creationTimestamp) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Secret List

/// Page listing all Secrets (metadata only).
public struct SecretListPage: HTML {
    let secrets: [SecretInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(secrets: [SecretInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.secrets = secrets
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "Secrets", currentPath: "/secrets") {
            PageHeader(title: "Secrets", subtitle: "\(secrets.count) total (metadata only)") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/secrets/list")
            }
            div(.id("resource-list")) {
                if secrets.isEmpty {
                    EmptyState("No secrets found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Type")
                        TableHeader("Keys")
                        TableHeader("Created")
                    } body: {
                        for secret in secrets {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { secret.name } }
                                TableCell { span(.class("text-gray-700")) { secret.namespace } }
                                TableCell { span(.class("badge badge-unknown")) { secret.type } }
                                TableCell { span(.class("text-gray-600")) { "\(secret.dataKeys.count) keys" } }
                                TableCell { Timestamp(secret.creationTimestamp) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - PVC List

/// Page listing all PersistentVolumeClaims.
public struct PVCListPage: HTML {
    let pvcs: [PVCInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(pvcs: [PVCInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.pvcs = pvcs
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "PVCs", currentPath: "/pvcs") {
            PageHeader(title: "Persistent Volume Claims", subtitle: "\(pvcs.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/pvcs/list")
            }
            div(.id("resource-list")) {
                if pvcs.isEmpty {
                    EmptyState("No PVCs found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Status")
                        TableHeader("Storage Class")
                        TableHeader("Capacity")
                        TableHeader("Access Modes")
                    } body: {
                        for pvc in pvcs {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell { span(.class("font-medium text-gray-900")) { pvc.name } }
                                TableCell { span(.class("text-gray-700")) { pvc.namespace } }
                                TableCell {
                                    let badgeClass = pvc.status == "Bound" ? "badge-healthy" : "badge-warning"
                                    span(.class("badge \(badgeClass)")) { pvc.status }
                                }
                                TableCell { span(.class("text-gray-600")) { pvc.storageClass ?? "-" } }
                                TableCell { span(.class("font-mono text-xs")) { pvc.capacity ?? "-" } }
                                TableCell {
                                    div(.class("flex gap-1")) {
                                        for mode in pvc.accessModes {
                                            span(.class("text-xs bg-gray-100 px-1 rounded")) { mode }
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
