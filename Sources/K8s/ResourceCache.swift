/// Thread-safe in-memory cache for Kubernetes resource state.
///
/// The ``ResourceCache`` is the central data store for the application. It holds
/// the latest known state of all watched Kubernetes resources and is updated
/// by ``ResourceWatcher`` instances. Pages read from the cache instead of
/// hitting the Kubernetes API server directly.
///
/// The cache is implemented as an actor for safe concurrent access from
/// multiple HTTP request handlers and background watchers.
///
/// ## Topics
/// ### Reading State
/// - ``pods(namespace:)``
/// - ``deployments(namespace:)``
/// - ``clusterSummary()``
/// ### Updating State
/// - ``updatePods(_:)``
/// - ``updateDeployments(_:)``
/// ### Subscriptions
/// - ``subscribe()``
/// - ``CacheEvent``

import Foundation
import Models

/// Events emitted when the cache is updated.
public enum CacheEvent: Sendable, Equatable {
    case podsUpdated
    case deploymentsUpdated
    case jobsUpdated
    case cronJobsUpdated
    case statefulSetsUpdated
    case daemonSetsUpdated
    case servicesUpdated
    case ingressesUpdated
    case nodesUpdated
    case eventsUpdated
    case namespacesUpdated
    case configMapsUpdated
    case secretsUpdated
    case pvcsUpdated
}

/// Thread-safe cache for all Kubernetes resource state.
public actor ResourceCache {
    // Resource stores
    private var allPods: [PodInfo] = []
    private var allDeployments: [DeploymentInfo] = []
    private var allJobs: [JobInfo] = []
    private var allCronJobs: [CronJobInfo] = []
    private var allStatefulSets: [StatefulSetInfo] = []
    private var allDaemonSets: [DaemonSetInfo] = []
    private var allServices: [ServiceInfo] = []
    private var allIngresses: [IngressInfo] = []
    private var allNodes: [NodeInfo] = []
    private var allEvents: [EventInfo] = []
    private var allNamespaces: [NamespaceInfo] = []
    private var allConfigMaps: [ConfigMapInfo] = []
    private var allSecrets: [SecretInfo] = []
    private var allPVCs: [PVCInfo] = []

    // Subscribers for live updates
    private var subscribers: [UUID: AsyncStream<CacheEvent>.Continuation] = [:]

    public init() {}

    // MARK: - Read

    /// Returns pods, optionally filtered by namespace.
    public func pods(namespace: String? = nil) -> [PodInfo] {
        guard let ns = namespace else { return allPods }
        return allPods.filter { $0.namespace == ns }
    }

    /// Returns a single pod by namespace and name.
    public func pod(namespace: String, name: String) -> PodInfo? {
        allPods.first { $0.namespace == namespace && $0.name == name }
    }

    /// Returns deployments, optionally filtered by namespace.
    public func deployments(namespace: String? = nil) -> [DeploymentInfo] {
        guard let ns = namespace else { return allDeployments }
        return allDeployments.filter { $0.namespace == ns }
    }

    /// Returns a single deployment by namespace and name.
    public func deployment(namespace: String, name: String) -> DeploymentInfo? {
        allDeployments.first { $0.namespace == namespace && $0.name == name }
    }

    public func jobs(namespace: String? = nil) -> [JobInfo] {
        guard let ns = namespace else { return allJobs }
        return allJobs.filter { $0.namespace == ns }
    }

    public func job(namespace: String, name: String) -> JobInfo? {
        allJobs.first { $0.namespace == namespace && $0.name == name }
    }

    public func cronJobs(namespace: String? = nil) -> [CronJobInfo] {
        guard let ns = namespace else { return allCronJobs }
        return allCronJobs.filter { $0.namespace == ns }
    }

    public func statefulSets(namespace: String? = nil) -> [StatefulSetInfo] {
        guard let ns = namespace else { return allStatefulSets }
        return allStatefulSets.filter { $0.namespace == ns }
    }

    public func daemonSets(namespace: String? = nil) -> [DaemonSetInfo] {
        guard let ns = namespace else { return allDaemonSets }
        return allDaemonSets.filter { $0.namespace == ns }
    }

    public func services(namespace: String? = nil) -> [ServiceInfo] {
        guard let ns = namespace else { return allServices }
        return allServices.filter { $0.namespace == ns }
    }

    public func ingresses(namespace: String? = nil) -> [IngressInfo] {
        guard let ns = namespace else { return allIngresses }
        return allIngresses.filter { $0.namespace == ns }
    }

    public func nodes() -> [NodeInfo] { allNodes }

    public func events(namespace: String? = nil) -> [EventInfo] {
        guard let ns = namespace else { return allEvents }
        return allEvents.filter { $0.namespace == ns }
    }

    public func namespaces() -> [NamespaceInfo] { allNamespaces }

    public func configMaps(namespace: String? = nil) -> [ConfigMapInfo] {
        guard let ns = namespace else { return allConfigMaps }
        return allConfigMaps.filter { $0.namespace == ns }
    }

    public func secrets(namespace: String? = nil) -> [SecretInfo] {
        guard let ns = namespace else { return allSecrets }
        return allSecrets.filter { $0.namespace == ns }
    }

    public func pvcs(namespace: String? = nil) -> [PVCInfo] {
        guard let ns = namespace else { return allPVCs }
        return allPVCs.filter { $0.namespace == ns }
    }

    /// Computes a cluster summary from the cached state.
    public func clusterSummary() -> ClusterSummary {
        ClusterSummary(
            totalPods: allPods.count,
            runningPods: allPods.filter { $0.phase == .running }.count,
            pendingPods: allPods.filter { $0.phase == .pending }.count,
            failedPods: allPods.filter { $0.phase == .failed }.count,
            totalDeployments: allDeployments.count,
            healthyDeployments: allDeployments.filter { $0.health == .healthy }.count,
            totalJobs: allJobs.count,
            failedJobs: allJobs.filter { $0.health == .error }.count,
            totalNodes: allNodes.count,
            readyNodes: allNodes.filter { $0.ready }.count,
            recentAlerts: 0,
            namespaces: allNamespaces.count
        )
    }

    // MARK: - Update

    public func updatePods(_ pods: [PodInfo]) {
        allPods = pods
        notify(.podsUpdated)
    }

    public func updateDeployments(_ deployments: [DeploymentInfo]) {
        allDeployments = deployments
        notify(.deploymentsUpdated)
    }

    public func updateJobs(_ jobs: [JobInfo]) {
        allJobs = jobs
        notify(.jobsUpdated)
    }

    public func updateCronJobs(_ cronJobs: [CronJobInfo]) {
        allCronJobs = cronJobs
        notify(.cronJobsUpdated)
    }

    public func updateStatefulSets(_ sets: [StatefulSetInfo]) {
        allStatefulSets = sets
        notify(.statefulSetsUpdated)
    }

    public func updateDaemonSets(_ sets: [DaemonSetInfo]) {
        allDaemonSets = sets
        notify(.daemonSetsUpdated)
    }

    public func updateServices(_ services: [ServiceInfo]) {
        allServices = services
        notify(.servicesUpdated)
    }

    public func updateIngresses(_ ingresses: [IngressInfo]) {
        allIngresses = ingresses
        notify(.ingressesUpdated)
    }

    public func updateNodes(_ nodes: [NodeInfo]) {
        allNodes = nodes
        notify(.nodesUpdated)
    }

    public func updateEvents(_ events: [EventInfo]) {
        allEvents = events
        notify(.eventsUpdated)
    }

    public func updateNamespaces(_ namespaces: [NamespaceInfo]) {
        allNamespaces = namespaces
        notify(.namespacesUpdated)
    }

    public func updateConfigMaps(_ configMaps: [ConfigMapInfo]) {
        allConfigMaps = configMaps
        notify(.configMapsUpdated)
    }

    public func updateSecrets(_ secrets: [SecretInfo]) {
        allSecrets = secrets
        notify(.secretsUpdated)
    }

    public func updatePVCs(_ pvcs: [PVCInfo]) {
        allPVCs = pvcs
        notify(.pvcsUpdated)
    }

    // MARK: - Subscriptions

    /// Subscribe to cache update events for SSE streaming.
    public func subscribe() -> (id: UUID, stream: AsyncStream<CacheEvent>) {
        let id = UUID()
        let stream = AsyncStream<CacheEvent> { continuation in
            subscribers[id] = continuation
        }
        return (id, stream)
    }

    /// Unsubscribe from cache events.
    public func unsubscribe(id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }

    private func notify(_ event: CacheEvent) {
        for (_, continuation) in subscribers {
            continuation.yield(event)
        }
    }
}
