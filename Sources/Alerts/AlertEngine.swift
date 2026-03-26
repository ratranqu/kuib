/// Alert evaluation engine that monitors cache events and fires alerts.
///
/// The ``AlertEngine`` subscribes to ``ResourceCache`` updates and evaluates
/// configured ``AlertRule``s against the current resource state. When a rule
/// matches, it creates a ``FiredAlert`` and dispatches it via the ``WebhookDispatcher``.
///
/// ## Built-in Rules
/// - Pod CrashLoopBackOff
/// - Pod OOMKilled
/// - Pod ImagePullBackOff
/// - Pod Failed
/// - Deployment rollout failed (replicas mismatch)
/// - Job failed
/// - Node not ready
///
/// ## Topics
/// ### Lifecycle
/// - ``start()``
/// - ``stop()``
/// ### Configuration
/// - ``addRule(_:)``
/// - ``removeRule(id:)``

import Database
import Foundation
import K8s
import Logging
import Models

/// Evaluates alert rules against Kubernetes resource state.
public actor AlertEngine {
    private let cache: ResourceCache
    private let db: DatabaseManager
    private let dispatcher: WebhookDispatcher
    private let logger: Logger
    private var rules: [AlertRule] = []
    private var cooldowns: [String: Date] = [:]
    private var task: Task<Void, Never>?

    public init(
        cache: ResourceCache,
        db: DatabaseManager,
        dispatcher: WebhookDispatcher,
        logger: Logger = Logger(label: "kuib.alerts")
    ) {
        self.cache = cache
        self.db = db
        self.dispatcher = dispatcher
        self.logger = logger
    }

    /// Load default alert rules.
    public func loadDefaultRules() {
        rules = [
            AlertRule(id: "pod-crashloop", name: "Pod CrashLoopBackOff", type: .podCrashLoopBackOff, severity: .critical),
            AlertRule(id: "pod-oomkilled", name: "Pod OOMKilled", type: .podOOMKilled, severity: .critical),
            AlertRule(id: "pod-imagepull", name: "Pod ImagePullBackOff", type: .podImagePullBackOff, severity: .warning),
            AlertRule(id: "pod-failed", name: "Pod Failed", type: .podFailed, severity: .warning),
            AlertRule(id: "deploy-mismatch", name: "Deployment Replicas Mismatch", type: .deploymentReplicasMismatch, severity: .warning, cooldownSeconds: 600),
            AlertRule(id: "job-failed", name: "Job Failed", type: .jobFailed, severity: .warning),
            AlertRule(id: "node-notready", name: "Node Not Ready", type: .nodeNotReady, severity: .critical),
            AlertRule(id: "node-memory", name: "Node Memory Pressure", type: .nodeMemoryPressure, severity: .warning),
            AlertRule(id: "node-disk", name: "Node Disk Pressure", type: .nodeDiskPressure, severity: .warning),
        ]
        logger.info("Loaded \(rules.count) default alert rules")
    }

    /// Add a custom alert rule.
    public func addRule(_ rule: AlertRule) {
        rules.append(rule)
    }

    /// Remove an alert rule by ID.
    public func removeRule(id: String) {
        rules.removeAll { $0.id == id }
    }

    /// Get all configured rules.
    public func getRules() -> [AlertRule] {
        rules
    }

    /// Start the alert evaluation loop.
    public func start() {
        task = Task { [self] in
            let (subId, stream) = await cache.subscribe()

            for await event in stream {
                guard !Task.isCancelled else { break }
                await evaluate(event: event)
            }

            await cache.unsubscribe(id: subId)
        }
        logger.info("Alert engine started")
    }

    /// Stop the alert evaluation loop.
    public func stop() {
        task?.cancel()
        task = nil
        logger.info("Alert engine stopped")
    }

    // MARK: - Evaluation

    private func evaluate(event: CacheEvent) async {
        for rule in rules where rule.enabled {
            do {
                let alerts = try await evaluateRule(rule, event: event)
                for alert in alerts {
                    try await fireAlert(alert)
                }
            } catch {
                logger.error("Error evaluating rule \(rule.name): \(error)")
            }
        }
    }

    private func evaluateRule(_ rule: AlertRule, event: CacheEvent) async throws -> [FiredAlert] {
        switch (rule.type, event) {

        case (.podCrashLoopBackOff, .podsUpdated):
            let pods = await cache.pods(namespace: rule.namespaceFilter)
            return pods.compactMap { pod in
                let crashLoop = pod.containers.contains { container in
                    if case .waiting(let reason) = container.state, reason == "CrashLoopBackOff" {
                        return true
                    }
                    return false
                }
                guard crashLoop else { return nil }
                return makeFiredAlert(rule: rule, kind: "Pod", name: pod.name, namespace: pod.namespace,
                    message: "Pod \(pod.name) has container in CrashLoopBackOff state")
            }

        case (.podOOMKilled, .podsUpdated):
            let pods = await cache.pods(namespace: rule.namespaceFilter)
            return pods.compactMap { pod in
                let oomKilled = pod.containers.contains { container in
                    if case .terminated(let reason, _, _) = container.state, reason == "OOMKilled" {
                        return true
                    }
                    return false
                }
                guard oomKilled else { return nil }
                return makeFiredAlert(rule: rule, kind: "Pod", name: pod.name, namespace: pod.namespace,
                    message: "Pod \(pod.name) has container killed by OOM")
            }

        case (.podImagePullBackOff, .podsUpdated):
            let pods = await cache.pods(namespace: rule.namespaceFilter)
            return pods.compactMap { pod in
                let imagePull = pod.containers.contains { container in
                    if case .waiting(let reason) = container.state,
                       reason == "ImagePullBackOff" || reason == "ErrImagePull" {
                        return true
                    }
                    return false
                }
                guard imagePull else { return nil }
                return makeFiredAlert(rule: rule, kind: "Pod", name: pod.name, namespace: pod.namespace,
                    message: "Pod \(pod.name) cannot pull container image")
            }

        case (.podFailed, .podsUpdated):
            let pods = await cache.pods(namespace: rule.namespaceFilter)
            return pods.compactMap { pod in
                guard pod.phase == .failed else { return nil }
                return makeFiredAlert(rule: rule, kind: "Pod", name: pod.name, namespace: pod.namespace,
                    message: "Pod \(pod.name) is in Failed state")
            }

        case (.deploymentReplicasMismatch, .deploymentsUpdated):
            let deployments = await cache.deployments(namespace: rule.namespaceFilter)
            return deployments.compactMap { d in
                guard d.replicas > 0 && d.availableReplicas < d.replicas else { return nil }
                return makeFiredAlert(rule: rule, kind: "Deployment", name: d.name, namespace: d.namespace,
                    message: "Deployment \(d.name) has \(d.availableReplicas)/\(d.replicas) replicas available")
            }

        case (.jobFailed, .jobsUpdated):
            let jobs = await cache.jobs(namespace: rule.namespaceFilter)
            return jobs.compactMap { job in
                guard job.failed > 0 else { return nil }
                return makeFiredAlert(rule: rule, kind: "Job", name: job.name, namespace: job.namespace,
                    message: "Job \(job.name) has \(job.failed) failed executions")
            }

        case (.nodeNotReady, .nodesUpdated):
            let nodes = await cache.nodes()
            return nodes.compactMap { node in
                guard !node.ready else { return nil }
                return makeFiredAlert(rule: rule, kind: "Node", name: node.name, namespace: "cluster",
                    message: "Node \(node.name) is not ready")
            }

        case (.nodeMemoryPressure, .nodesUpdated):
            let nodes = await cache.nodes()
            return nodes.compactMap { node in
                let pressure = node.conditions.contains { $0.type == "MemoryPressure" && $0.status == "True" }
                guard pressure else { return nil }
                return makeFiredAlert(rule: rule, kind: "Node", name: node.name, namespace: "cluster",
                    message: "Node \(node.name) has memory pressure")
            }

        case (.nodeDiskPressure, .nodesUpdated):
            let nodes = await cache.nodes()
            return nodes.compactMap { node in
                let pressure = node.conditions.contains { $0.type == "DiskPressure" && $0.status == "True" }
                guard pressure else { return nil }
                return makeFiredAlert(rule: rule, kind: "Node", name: node.name, namespace: "cluster",
                    message: "Node \(node.name) has disk pressure")
            }

        default:
            return []
        }
    }

    private func makeFiredAlert(rule: AlertRule, kind: String, name: String, namespace: String, message: String) -> FiredAlert? {
        let cooldownKey = "\(rule.id):\(namespace)/\(name)"

        if let lastFired = cooldowns[cooldownKey] {
            let elapsed = Date().timeIntervalSince(lastFired)
            if elapsed < Double(rule.cooldownSeconds) {
                return nil
            }
        }

        cooldowns[cooldownKey] = Date()

        return FiredAlert(
            id: UUID().uuidString,
            ruleId: rule.id,
            ruleName: rule.name,
            severity: rule.severity,
            resourceKind: kind,
            resourceName: name,
            namespace: namespace,
            message: message,
            firedAt: Date()
        )
    }

    private func fireAlert(_ alert: FiredAlert) async throws {
        logger.warning("Alert fired: [\(alert.severity.rawValue)] \(alert.message)")
        try await db.saveFiredAlert(alert)
        await dispatcher.dispatch(alert: alert)
    }
}
