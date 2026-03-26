/// Background service that watches Kubernetes resources and updates the cache.
///
/// The ``ResourceWatcher`` establishes polling loops that periodically refresh
/// resource state from the Kubernetes API and update the ``ResourceCache``.
/// It runs as a background task managed by the application lifecycle.
///
/// ## Topics
/// ### Lifecycle
/// - ``start()``
/// - ``stop()``
/// ### Configuration
/// - ``WatcherConfig``

import Foundation
import Logging
import Models

/// Configuration for resource watcher polling intervals.
public struct WatcherConfig: Sendable {
    /// Polling interval for fast-changing resources (pods, events).
    public let fastPollInterval: Duration

    /// Polling interval for slower-changing resources (deployments, services).
    public let normalPollInterval: Duration

    /// Polling interval for rarely-changing resources (nodes, namespaces).
    public let slowPollInterval: Duration

    public init(
        fastPollInterval: Duration = .seconds(5),
        normalPollInterval: Duration = .seconds(15),
        slowPollInterval: Duration = .seconds(60)
    ) {
        self.fastPollInterval = fastPollInterval
        self.normalPollInterval = normalPollInterval
        self.slowPollInterval = slowPollInterval
    }
}

/// Watches Kubernetes resources and maintains an in-memory cache.
public actor ResourceWatcher {
    private let client: K8sClientProtocol
    private let cache: ResourceCache
    private let config: WatcherConfig
    private let logger: Logger
    private var tasks: [Task<Void, Never>] = []

    public init(
        client: K8sClientProtocol,
        cache: ResourceCache,
        config: WatcherConfig = WatcherConfig(),
        logger: Logger = Logger(label: "kuib.watcher")
    ) {
        self.client = client
        self.cache = cache
        self.config = config
        self.logger = logger
    }

    /// Start all resource watchers as background tasks.
    public func start() {
        logger.info("Starting resource watchers")

        // Fast poll: pods, events
        tasks.append(Task { await self.pollLoop("pods", interval: config.fastPollInterval) {
            let pods = try await self.client.listPods(namespace: .all)
            await self.cache.updatePods(pods)
        }})

        tasks.append(Task { await self.pollLoop("events", interval: config.fastPollInterval) {
            let events = try await self.client.listEvents(namespace: .all)
            await self.cache.updateEvents(events)
        }})

        // Normal poll: deployments, jobs, cronjobs, statefulsets, daemonsets, services, ingresses
        tasks.append(Task { await self.pollLoop("deployments", interval: config.normalPollInterval) {
            let deployments = try await self.client.listDeployments(namespace: .all)
            await self.cache.updateDeployments(deployments)
        }})

        tasks.append(Task { await self.pollLoop("jobs", interval: config.normalPollInterval) {
            let jobs = try await self.client.listJobs(namespace: .all)
            await self.cache.updateJobs(jobs)
        }})

        tasks.append(Task { await self.pollLoop("cronjobs", interval: config.normalPollInterval) {
            let cronJobs = try await self.client.listCronJobs(namespace: .all)
            await self.cache.updateCronJobs(cronJobs)
        }})

        tasks.append(Task { await self.pollLoop("statefulsets", interval: config.normalPollInterval) {
            let sets = try await self.client.listStatefulSets(namespace: .all)
            await self.cache.updateStatefulSets(sets)
        }})

        tasks.append(Task { await self.pollLoop("daemonsets", interval: config.normalPollInterval) {
            let sets = try await self.client.listDaemonSets(namespace: .all)
            await self.cache.updateDaemonSets(sets)
        }})

        tasks.append(Task { await self.pollLoop("services", interval: config.normalPollInterval) {
            let services = try await self.client.listServices(namespace: .all)
            await self.cache.updateServices(services)
        }})

        tasks.append(Task { await self.pollLoop("ingresses", interval: config.normalPollInterval) {
            let ingresses = try await self.client.listIngresses(namespace: .all)
            await self.cache.updateIngresses(ingresses)
        }})

        // Slow poll: nodes, namespaces, configmaps, secrets, pvcs
        tasks.append(Task { await self.pollLoop("nodes", interval: config.slowPollInterval) {
            let nodes = try await self.client.listNodes()
            await self.cache.updateNodes(nodes)
        }})

        tasks.append(Task { await self.pollLoop("namespaces", interval: config.slowPollInterval) {
            let namespaces = try await self.client.listNamespaces()
            await self.cache.updateNamespaces(namespaces)
        }})

        tasks.append(Task { await self.pollLoop("configmaps", interval: config.slowPollInterval) {
            let cms = try await self.client.listConfigMaps(namespace: .all)
            await self.cache.updateConfigMaps(cms)
        }})

        tasks.append(Task { await self.pollLoop("secrets", interval: config.slowPollInterval) {
            let secrets = try await self.client.listSecrets(namespace: .all)
            await self.cache.updateSecrets(secrets)
        }})

        tasks.append(Task { await self.pollLoop("pvcs", interval: config.slowPollInterval) {
            let pvcs = try await self.client.listPVCs(namespace: .all)
            await self.cache.updatePVCs(pvcs)
        }})

        logger.info("All resource watchers started", metadata: ["count": "\(tasks.count)"])
    }

    /// Stop all resource watchers.
    public func stop() {
        logger.info("Stopping resource watchers")
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }

    /// Generic polling loop with error handling and backoff.
    private func pollLoop(
        _ resource: String,
        interval: Duration,
        fetch: @escaping @Sendable () async throws -> Void
    ) async {
        var consecutiveErrors = 0

        while !Task.isCancelled {
            do {
                try await fetch()
                consecutiveErrors = 0
            } catch {
                consecutiveErrors += 1
                let backoff = min(consecutiveErrors * 2, 30)
                logger.error(
                    "Failed to poll \(resource)",
                    metadata: [
                        "error": "\(error)",
                        "consecutive_errors": "\(consecutiveErrors)",
                        "backoff_seconds": "\(backoff)",
                    ]
                )
                try? await Task.sleep(for: .seconds(backoff))
            }

            try? await Task.sleep(for: interval)
        }
    }
}
