/// Mock Kubernetes client for unit testing.
///
/// Returns configurable fixture data for all resource types.
/// Use this in tests to verify pages, cache, watchers, and alerts
/// without requiring a real Kubernetes cluster.

import Foundation
import K8s
import Models

/// Mock implementation of ``K8sClientProtocol`` for testing.
public final class MockK8sClient: K8sClientProtocol, @unchecked Sendable {
    // Configurable return values
    public var pods: [PodInfo] = []
    public var deployments: [DeploymentInfo] = []
    public var jobs: [JobInfo] = []
    public var cronJobs: [CronJobInfo] = []
    public var statefulSets: [StatefulSetInfo] = []
    public var daemonSets: [DaemonSetInfo] = []
    public var services: [ServiceInfo] = []
    public var ingresses: [IngressInfo] = []
    public var nodes: [NodeInfo] = []
    public var events: [EventInfo] = []
    public var namespaces: [NamespaceInfo] = []
    public var configMaps: [ConfigMapInfo] = []
    public var secrets: [SecretInfo] = []
    public var pvcs: [PVCInfo] = []
    public var podLogs: String = "mock log line 1\nmock log line 2\n"

    // Tracking calls
    public var deletedPods: [(namespace: String, name: String)] = []
    public var deletedJobs: [(namespace: String, name: String)] = []
    public var scaledDeployments: [(namespace: String, name: String, replicas: Int32)] = []

    // Error simulation
    public var shouldThrow: Error?

    public init() {}

    private func checkError() throws {
        if let error = shouldThrow { throw error }
    }

    private func filter<T>(_ items: [T], namespace: NamespaceSelector, nsKeyPath: KeyPath<T, String>) -> [T] {
        switch namespace {
        case .all: return items
        case .namespace(let ns): return items.filter { $0[keyPath: nsKeyPath] == ns }
        }
    }

    public func listPods(namespace: NamespaceSelector) async throws -> [PodInfo] {
        try checkError()
        return filter(pods, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func getPod(namespace: String, name: String) async throws -> PodInfo? {
        try checkError()
        return pods.first { $0.namespace == namespace && $0.name == name }
    }

    public func getPodLogs(namespace: String, name: String, container: String?, tailLines: Int?) async throws -> String {
        try checkError()
        return podLogs
    }

    public func deletePod(namespace: String, name: String) async throws {
        try checkError()
        deletedPods.append((namespace: namespace, name: name))
    }

    public func listDeployments(namespace: NamespaceSelector) async throws -> [DeploymentInfo] {
        try checkError()
        return filter(deployments, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func getDeployment(namespace: String, name: String) async throws -> DeploymentInfo? {
        try checkError()
        return deployments.first { $0.namespace == namespace && $0.name == name }
    }

    public func scaleDeployment(namespace: String, name: String, replicas: Int32) async throws {
        try checkError()
        scaledDeployments.append((namespace: namespace, name: name, replicas: replicas))
    }

    public func listJobs(namespace: NamespaceSelector) async throws -> [JobInfo] {
        try checkError()
        return filter(jobs, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func getJob(namespace: String, name: String) async throws -> JobInfo? {
        try checkError()
        return jobs.first { $0.namespace == namespace && $0.name == name }
    }

    public func deleteJob(namespace: String, name: String) async throws {
        try checkError()
        deletedJobs.append((namespace: namespace, name: name))
    }

    public func listCronJobs(namespace: NamespaceSelector) async throws -> [CronJobInfo] {
        try checkError()
        return filter(cronJobs, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listStatefulSets(namespace: NamespaceSelector) async throws -> [StatefulSetInfo] {
        try checkError()
        return filter(statefulSets, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listDaemonSets(namespace: NamespaceSelector) async throws -> [DaemonSetInfo] {
        try checkError()
        return filter(daemonSets, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listServices(namespace: NamespaceSelector) async throws -> [ServiceInfo] {
        try checkError()
        return filter(services, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listIngresses(namespace: NamespaceSelector) async throws -> [IngressInfo] {
        try checkError()
        return filter(ingresses, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listNodes() async throws -> [NodeInfo] {
        try checkError()
        return nodes
    }

    public func listEvents(namespace: NamespaceSelector) async throws -> [EventInfo] {
        try checkError()
        return filter(events, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listNamespaces() async throws -> [NamespaceInfo] {
        try checkError()
        return namespaces
    }

    public func listConfigMaps(namespace: NamespaceSelector) async throws -> [ConfigMapInfo] {
        try checkError()
        return filter(configMaps, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listSecrets(namespace: NamespaceSelector) async throws -> [SecretInfo] {
        try checkError()
        return filter(secrets, namespace: namespace, nsKeyPath: \.namespace)
    }

    public func listPVCs(namespace: NamespaceSelector) async throws -> [PVCInfo] {
        try checkError()
        return filter(pvcs, namespace: namespace, nsKeyPath: \.namespace)
    }
}

/// Standard error for mock testing.
public enum MockError: Error {
    case simulatedFailure
}
