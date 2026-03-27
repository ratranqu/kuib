/// Shared data models for Kubernetes resource representations.
///
/// These models provide a normalized, UI-friendly view of Kubernetes resources
/// that is independent of the SwiftkubeClient API types. This decoupling allows
/// pages and components to render without importing Kubernetes-specific libraries.
///
/// ## Topics
/// ### Resource Types
/// - ``PodInfo``
/// - ``ContainerInfo``
/// - ``DeploymentInfo``
/// - ``JobInfo``
/// - ``CronJobInfo``
/// - ``StatefulSetInfo``
/// - ``DaemonSetInfo``
/// - ``ServiceInfo``
/// - ``IngressInfo``
/// - ``NodeInfo``
/// - ``EventInfo``
/// - ``ConfigMapInfo``
/// - ``SecretInfo``
/// - ``PVCInfo``
/// ### Status Types
/// - ``PodPhase``
/// - ``ContainerState``
/// - ``DeploymentCondition``
/// - ``ResourceHealth``

import Foundation

// MARK: - Health

/// Overall health assessment for a resource, used for dashboard indicators.
public enum ResourceHealth: String, Sendable, Codable {
    case healthy
    case warning
    case error
    case unknown
}

// MARK: - Pods

/// Kubernetes pod phase.
public enum PodPhase: String, Sendable, Codable {
    case pending = "Pending"
    case running = "Running"
    case succeeded = "Succeeded"
    case failed = "Failed"
    case unknown = "Unknown"
}

/// State of an individual container within a pod.
public enum ContainerState: Sendable, Codable, Equatable {
    case waiting(reason: String?)
    case running(startedAt: Date?)
    case terminated(reason: String?, exitCode: Int32, finishedAt: Date?)
}

/// UI-friendly representation of a Kubernetes container.
public struct ContainerInfo: Sendable, Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let image: String
    public let state: ContainerState
    public let ready: Bool
    public let restartCount: Int32

    public init(name: String, image: String, state: ContainerState, ready: Bool, restartCount: Int32) {
        self.name = name
        self.image = image
        self.state = state
        self.ready = ready
        self.restartCount = restartCount
    }
}

/// UI-friendly representation of a Kubernetes pod.
public struct PodInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let phase: PodPhase
    public let containers: [ContainerInfo]
    public let nodeName: String?
    public let startTime: Date?
    public let labels: [String: String]
    public let health: ResourceHealth
    public let ownerKind: String?
    public let ownerName: String?

    public init(
        name: String, namespace: String, phase: PodPhase,
        containers: [ContainerInfo], nodeName: String?,
        startTime: Date?, labels: [String: String],
        health: ResourceHealth, ownerKind: String? = nil, ownerName: String? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.phase = phase
        self.containers = containers
        self.nodeName = nodeName
        self.startTime = startTime
        self.labels = labels
        self.health = health
        self.ownerKind = ownerKind
        self.ownerName = ownerName
    }
}

// MARK: - Deployments

/// Condition type for a deployment.
public enum DeploymentCondition: String, Sendable, Codable {
    case available = "Available"
    case progressing = "Progressing"
    case replicaFailure = "ReplicaFailure"
}

/// UI-friendly representation of a Kubernetes deployment.
public struct DeploymentInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let replicas: Int32
    public let readyReplicas: Int32
    public let updatedReplicas: Int32
    public let availableReplicas: Int32
    public let labels: [String: String]
    public let health: ResourceHealth
    public let creationTimestamp: Date?

    public init(
        name: String, namespace: String, replicas: Int32,
        readyReplicas: Int32, updatedReplicas: Int32,
        availableReplicas: Int32, labels: [String: String],
        health: ResourceHealth, creationTimestamp: Date? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.replicas = replicas
        self.readyReplicas = readyReplicas
        self.updatedReplicas = updatedReplicas
        self.availableReplicas = availableReplicas
        self.labels = labels
        self.health = health
        self.creationTimestamp = creationTimestamp
    }
}

// MARK: - Jobs

/// UI-friendly representation of a Kubernetes Job.
public struct JobInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let active: Int32
    public let succeeded: Int32
    public let failed: Int32
    public let startTime: Date?
    public let completionTime: Date?
    public let labels: [String: String]
    public let health: ResourceHealth
    public let ownerName: String?

    public init(
        name: String, namespace: String, active: Int32,
        succeeded: Int32, failed: Int32, startTime: Date?,
        completionTime: Date?, labels: [String: String],
        health: ResourceHealth, ownerName: String? = nil
    ) {
        self.name = name
        self.namespace = namespace
        self.active = active
        self.succeeded = succeeded
        self.failed = failed
        self.startTime = startTime
        self.completionTime = completionTime
        self.labels = labels
        self.health = health
        self.ownerName = ownerName
    }

    /// Duration of the job run, if available.
    public var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = completionTime ?? Date()
        return end.timeIntervalSince(start)
    }
}

/// UI-friendly representation of a Kubernetes CronJob.
public struct CronJobInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let schedule: String
    public let suspend: Bool
    public let activeJobs: Int
    public let lastScheduleTime: Date?
    public let lastSuccessfulTime: Date?
    public let labels: [String: String]
    public let health: ResourceHealth

    public init(
        name: String, namespace: String, schedule: String,
        suspend: Bool, activeJobs: Int, lastScheduleTime: Date?,
        lastSuccessfulTime: Date?, labels: [String: String],
        health: ResourceHealth
    ) {
        self.name = name
        self.namespace = namespace
        self.schedule = schedule
        self.suspend = suspend
        self.activeJobs = activeJobs
        self.lastScheduleTime = lastScheduleTime
        self.lastSuccessfulTime = lastSuccessfulTime
        self.labels = labels
        self.health = health
    }
}

// MARK: - StatefulSets & DaemonSets

/// UI-friendly representation of a Kubernetes StatefulSet.
public struct StatefulSetInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let replicas: Int32
    public let readyReplicas: Int32
    public let currentReplicas: Int32
    public let labels: [String: String]
    public let health: ResourceHealth

    public init(
        name: String, namespace: String, replicas: Int32,
        readyReplicas: Int32, currentReplicas: Int32,
        labels: [String: String], health: ResourceHealth
    ) {
        self.name = name
        self.namespace = namespace
        self.replicas = replicas
        self.readyReplicas = readyReplicas
        self.currentReplicas = currentReplicas
        self.labels = labels
        self.health = health
    }
}

/// UI-friendly representation of a Kubernetes DaemonSet.
public struct DaemonSetInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let desiredNumberScheduled: Int32
    public let currentNumberScheduled: Int32
    public let numberReady: Int32
    public let numberAvailable: Int32
    public let labels: [String: String]
    public let health: ResourceHealth

    public init(
        name: String, namespace: String, desiredNumberScheduled: Int32,
        currentNumberScheduled: Int32, numberReady: Int32,
        numberAvailable: Int32, labels: [String: String],
        health: ResourceHealth
    ) {
        self.name = name
        self.namespace = namespace
        self.desiredNumberScheduled = desiredNumberScheduled
        self.currentNumberScheduled = currentNumberScheduled
        self.numberReady = numberReady
        self.numberAvailable = numberAvailable
        self.labels = labels
        self.health = health
    }
}

// MARK: - Services & Ingresses

/// UI-friendly representation of a Kubernetes Service.
public struct ServiceInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let type: String
    public let clusterIP: String?
    public let externalIPs: [String]
    public let ports: [ServicePort]
    public let labels: [String: String]

    public init(
        name: String, namespace: String, type: String,
        clusterIP: String?, externalIPs: [String],
        ports: [ServicePort], labels: [String: String]
    ) {
        self.name = name
        self.namespace = namespace
        self.type = type
        self.clusterIP = clusterIP
        self.externalIPs = externalIPs
        self.ports = ports
        self.labels = labels
    }
}

/// A port exposed by a Kubernetes Service.
public struct ServicePort: Sendable, Codable {
    public let name: String?
    public let port: Int32
    public let targetPort: String
    public let protocol_: String

    public init(name: String?, port: Int32, targetPort: String, protocol_: String) {
        self.name = name
        self.port = port
        self.targetPort = targetPort
        self.protocol_ = protocol_
    }
}

/// UI-friendly representation of a Kubernetes Ingress.
public struct IngressInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let hosts: [String]
    public let ingressClassName: String?
    public let labels: [String: String]

    public init(
        name: String, namespace: String, hosts: [String],
        ingressClassName: String?, labels: [String: String]
    ) {
        self.name = name
        self.namespace = namespace
        self.hosts = hosts
        self.ingressClassName = ingressClassName
        self.labels = labels
    }
}

// MARK: - Nodes

/// UI-friendly representation of a Kubernetes Node.
public struct NodeInfo: Sendable, Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let ready: Bool
    public let roles: [String]
    public let kubeletVersion: String
    public let osImage: String
    public let allocatableCPU: String
    public let allocatableMemory: String
    public let conditions: [NodeCondition]
    public let health: ResourceHealth

    public init(
        name: String, ready: Bool, roles: [String],
        kubeletVersion: String, osImage: String,
        allocatableCPU: String, allocatableMemory: String,
        conditions: [NodeCondition], health: ResourceHealth
    ) {
        self.name = name
        self.ready = ready
        self.roles = roles
        self.kubeletVersion = kubeletVersion
        self.osImage = osImage
        self.allocatableCPU = allocatableCPU
        self.allocatableMemory = allocatableMemory
        self.conditions = conditions
        self.health = health
    }
}

/// A condition reported by a Kubernetes Node.
public struct NodeCondition: Sendable, Codable {
    public let type: String
    public let status: String
    public let reason: String?
    public let message: String?

    public init(type: String, status: String, reason: String?, message: String?) {
        self.type = type
        self.status = status
        self.reason = reason
        self.message = message
    }
}

// MARK: - Events

/// UI-friendly representation of a Kubernetes Event.
public struct EventInfo: Sendable, Codable, Identifiable {
    public let id: String
    public let namespace: String
    public let involvedObjectKind: String
    public let involvedObjectName: String
    public let reason: String
    public let message: String
    public let type: String
    public let firstTimestamp: Date?
    public let lastTimestamp: Date?
    public let count: Int32

    public init(
        id: String, namespace: String, involvedObjectKind: String,
        involvedObjectName: String, reason: String, message: String,
        type: String, firstTimestamp: Date?, lastTimestamp: Date?,
        count: Int32
    ) {
        self.id = id
        self.namespace = namespace
        self.involvedObjectKind = involvedObjectKind
        self.involvedObjectName = involvedObjectName
        self.reason = reason
        self.message = message
        self.type = type
        self.firstTimestamp = firstTimestamp
        self.lastTimestamp = lastTimestamp
        self.count = count
    }
}

// MARK: - Config Resources

/// UI-friendly representation of a Kubernetes ConfigMap (metadata only).
public struct ConfigMapInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let dataKeys: [String]
    public let creationTimestamp: Date?

    public init(name: String, namespace: String, dataKeys: [String], creationTimestamp: Date?) {
        self.name = name
        self.namespace = namespace
        self.dataKeys = dataKeys
        self.creationTimestamp = creationTimestamp
    }
}

/// UI-friendly representation of a Kubernetes Secret (metadata only, no data exposed).
public struct SecretInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let type: String
    public let dataKeys: [String]
    public let creationTimestamp: Date?

    public init(name: String, namespace: String, type: String, dataKeys: [String], creationTimestamp: Date?) {
        self.name = name
        self.namespace = namespace
        self.type = type
        self.dataKeys = dataKeys
        self.creationTimestamp = creationTimestamp
    }
}

/// UI-friendly representation of a Kubernetes PersistentVolumeClaim.
public struct PVCInfo: Sendable, Codable, Identifiable {
    public var id: String { "\(namespace)/\(name)" }
    public let name: String
    public let namespace: String
    public let status: String
    public let storageClass: String?
    public let capacity: String?
    public let accessModes: [String]

    public init(
        name: String, namespace: String, status: String,
        storageClass: String?, capacity: String?, accessModes: [String]
    ) {
        self.name = name
        self.namespace = namespace
        self.status = status
        self.storageClass = storageClass
        self.capacity = capacity
        self.accessModes = accessModes
    }
}

// MARK: - Namespace

/// UI-friendly representation of a Kubernetes Namespace.
public struct NamespaceInfo: Sendable, Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let status: String
    public let labels: [String: String]

    public init(name: String, status: String, labels: [String: String]) {
        self.name = name
        self.status = status
        self.labels = labels
    }
}

// MARK: - Cluster Summary

/// Aggregate cluster health summary for the dashboard.
public struct ClusterSummary: Sendable, Codable {
    public var totalPods: Int
    public var runningPods: Int
    public var pendingPods: Int
    public var failedPods: Int
    public var totalDeployments: Int
    public var healthyDeployments: Int
    public var totalJobs: Int
    public var failedJobs: Int
    public var totalNodes: Int
    public var readyNodes: Int
    public var recentAlerts: Int
    public var namespaces: Int

    public init(
        totalPods: Int = 0, runningPods: Int = 0, pendingPods: Int = 0,
        failedPods: Int = 0, totalDeployments: Int = 0, healthyDeployments: Int = 0,
        totalJobs: Int = 0, failedJobs: Int = 0, totalNodes: Int = 0,
        readyNodes: Int = 0, recentAlerts: Int = 0, namespaces: Int = 0
    ) {
        self.totalPods = totalPods
        self.runningPods = runningPods
        self.pendingPods = pendingPods
        self.failedPods = failedPods
        self.totalDeployments = totalDeployments
        self.healthyDeployments = healthyDeployments
        self.totalJobs = totalJobs
        self.failedJobs = failedJobs
        self.totalNodes = totalNodes
        self.readyNodes = readyNodes
        self.recentAlerts = recentAlerts
        self.namespaces = namespaces
    }
}

// MARK: - Resource Filter

/// A collection of selectors for filtering Kubernetes resources.
///
/// Combines namespace, label selectors, health status, and name search
/// into a single filter that can be applied to any resource list.
public struct ResourceFilter: Sendable, Codable {
    /// Filter by namespace. Nil means all namespaces.
    public let namespace: String?

    /// Label selectors as key=value pairs. All must match (AND logic).
    public let labelSelectors: [String: String]

    /// Filter by health status. Nil means all statuses.
    public let health: ResourceHealth?

    /// Substring search on resource name (case-insensitive). Nil means no name filter.
    public let nameContains: String?

    public init(
        namespace: String? = nil,
        labelSelectors: [String: String] = [:],
        health: ResourceHealth? = nil,
        nameContains: String? = nil
    ) {
        self.namespace = namespace
        self.labelSelectors = labelSelectors
        self.health = health
        self.nameContains = nameContains
    }

    /// True when no filter criteria are set.
    public var isEmpty: Bool {
        namespace == nil && labelSelectors.isEmpty && health == nil && nameContains == nil
    }

    /// Parse label selectors from a comma-separated string of key=value pairs.
    /// Example: "app=nginx,env=prod"
    public static func parseLabels(_ raw: String?) -> [String: String] {
        guard let raw, !raw.isEmpty else { return [:] }
        var result: [String: String] = [:]
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }

    /// Build a query string representation for HTMX URL parameters.
    public var queryString: String {
        var parts: [String] = []
        if let ns = namespace { parts.append("namespace=\(ns)") }
        if !labelSelectors.isEmpty {
            let encoded = labelSelectors.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
            parts.append("labels=\(encoded)")
        }
        if let h = health { parts.append("health=\(h.rawValue)") }
        if let n = nameContains { parts.append("search=\(n)") }
        return parts.isEmpty ? "" : "?\(parts.joined(separator: "&"))"
    }
}

/// Protocol for resources that can be filtered by ``ResourceFilter``.
public protocol Filterable {
    var name: String { get }
    var namespace: String { get }
    var labels: [String: String] { get }
    var filterHealth: ResourceHealth? { get }
}

extension Filterable {
    /// Returns true if this resource matches all criteria in the filter.
    public func matches(_ filter: ResourceFilter) -> Bool {
        if let ns = filter.namespace, namespace != ns { return false }
        if let search = filter.nameContains, !search.isEmpty {
            if !name.localizedCaseInsensitiveContains(search) { return false }
        }
        if let h = filter.health, filterHealth != h { return false }
        for (key, value) in filter.labelSelectors {
            if labels[key] != value { return false }
        }
        return true
    }
}

// MARK: - Filterable Conformances

extension PodInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension DeploymentInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension JobInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension CronJobInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension StatefulSetInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension DaemonSetInfo: Filterable {
    public var filterHealth: ResourceHealth? { health }
}

extension ServiceInfo: Filterable {
    public var filterHealth: ResourceHealth? { nil }
}

extension IngressInfo: Filterable {
    public var filterHealth: ResourceHealth? { nil }
}

extension ConfigMapInfo: Filterable {
    public var labels: [String: String] { [:] }
    public var filterHealth: ResourceHealth? { nil }
}

extension SecretInfo: Filterable {
    public var labels: [String: String] { [:] }
    public var filterHealth: ResourceHealth? { nil }
}

extension PVCInfo: Filterable {
    public var labels: [String: String] { [:] }
    public var filterHealth: ResourceHealth? { nil }
}
