/// Protocol-based abstraction over the Kubernetes API client.
///
/// ``K8sClientProtocol`` provides a testable interface for all Kubernetes operations
/// used by KUIB. In production, ``SwiftkubeK8sClient`` implements this using
/// SwiftkubeClient. In tests, ``MockK8sClient`` provides fixture-based responses.
///
/// ## Topics
/// ### Listing Resources
/// - ``listPods(namespace:)``
/// - ``listDeployments(namespace:)``
/// - ``listJobs(namespace:)``
/// - ``listCronJobs(namespace:)``
/// - ``listStatefulSets(namespace:)``
/// - ``listDaemonSets(namespace:)``
/// - ``listServices(namespace:)``
/// - ``listIngresses(namespace:)``
/// - ``listNodes()``
/// - ``listEvents(namespace:)``
/// - ``listNamespaces()``
/// ### Logs
/// - ``getPodLogs(namespace:name:container:tailLines:)``

import Foundation
import Models

/// Namespace selector for Kubernetes queries.
public enum NamespaceSelector: Sendable {
    case all
    case namespace(String)
}

/// Protocol abstracting Kubernetes API operations for testability.
public protocol K8sClientProtocol: Sendable {
    // Pods
    func listPods(namespace: NamespaceSelector) async throws -> [PodInfo]
    func getPod(namespace: String, name: String) async throws -> PodInfo?
    func getPodLogs(namespace: String, name: String, container: String?, tailLines: Int?) async throws -> String
    func deletePod(namespace: String, name: String) async throws

    // Deployments
    func listDeployments(namespace: NamespaceSelector) async throws -> [DeploymentInfo]
    func getDeployment(namespace: String, name: String) async throws -> DeploymentInfo?
    func scaleDeployment(namespace: String, name: String, replicas: Int32) async throws

    // Jobs
    func listJobs(namespace: NamespaceSelector) async throws -> [JobInfo]
    func getJob(namespace: String, name: String) async throws -> JobInfo?
    func deleteJob(namespace: String, name: String) async throws

    // CronJobs
    func listCronJobs(namespace: NamespaceSelector) async throws -> [CronJobInfo]

    // StatefulSets
    func listStatefulSets(namespace: NamespaceSelector) async throws -> [StatefulSetInfo]

    // DaemonSets
    func listDaemonSets(namespace: NamespaceSelector) async throws -> [DaemonSetInfo]

    // Services
    func listServices(namespace: NamespaceSelector) async throws -> [ServiceInfo]

    // Ingresses
    func listIngresses(namespace: NamespaceSelector) async throws -> [IngressInfo]

    // Nodes
    func listNodes() async throws -> [NodeInfo]

    // Events
    func listEvents(namespace: NamespaceSelector) async throws -> [EventInfo]

    // Namespaces
    func listNamespaces() async throws -> [NamespaceInfo]

    // Config resources
    func listConfigMaps(namespace: NamespaceSelector) async throws -> [ConfigMapInfo]
    func listSecrets(namespace: NamespaceSelector) async throws -> [SecretInfo]
    func listPVCs(namespace: NamespaceSelector) async throws -> [PVCInfo]
}
