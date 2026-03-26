/// Production implementation of ``K8sClientProtocol`` using SwiftkubeClient.
///
/// Connects to the Kubernetes API server using in-cluster authentication
/// when deployed on Kubernetes, or kubeconfig for local development.
/// All operations use async/await with the SwiftkubeClient's fluent DSL.

import Foundation
import Logging
import Models
import SwiftkubeClient
import SwiftkubeModel

/// Production Kubernetes client backed by SwiftkubeClient.
public final class SwiftkubeK8sClient: K8sClientProtocol, @unchecked Sendable {
    private let client: KubernetesClient
    private let logger: Logger

    /// Creates a new client, auto-detecting in-cluster or kubeconfig authentication.
    public init(logger: Logger = Logger(label: "kuib.k8s")) throws {
        self.client = try KubernetesClient()
        self.logger = logger
    }

    /// Shuts down the underlying HTTP client.
    public func shutdown() async throws {
        try await client.shutdown()
    }

    // MARK: - Pods

    public func listPods(namespace: NamespaceSelector) async throws -> [PodInfo] {
        let pods = try await client.pods.list(in: namespace.toSwiftkube())
        return pods.items.map { pod in
            PodInfo(from: pod)
        }
    }

    public func getPod(namespace: String, name: String) async throws -> PodInfo? {
        let pod = try await client.pods.get(in: .namespace(namespace), name: name)
        return PodInfo(from: pod)
    }

    public func getPodLogs(namespace: String, name: String, container: String?, tailLines: Int?) async throws -> String {
        let options = core.v1.PodLogOptions(
            container: container,
            tailLines: tailLines.map { Int64($0) }
        )
        return try await client.pods.logs(in: .namespace(namespace), name: name, logOptions: options)
    }

    public func deletePod(namespace: String, name: String) async throws {
        try await client.pods.delete(in: .namespace(namespace), name: name)
    }

    // MARK: - Deployments

    public func listDeployments(namespace: NamespaceSelector) async throws -> [DeploymentInfo] {
        let deployments = try await client.appsV1.deployments.list(in: namespace.toSwiftkube())
        return deployments.items.map { DeploymentInfo(from: $0) }
    }

    public func getDeployment(namespace: String, name: String) async throws -> DeploymentInfo? {
        let deployment = try await client.appsV1.deployments.get(in: .namespace(namespace), name: name)
        return DeploymentInfo(from: deployment)
    }

    public func scaleDeployment(namespace: String, name: String, replicas: Int32) async throws {
        let scale = autoscaling.v1.Scale(
            metadata: meta.v1.ObjectMeta(name: name, namespace: namespace),
            spec: autoscaling.v1.ScaleSpec(replicas: replicas)
        )
        try await client.appsV1.deployments.updateScale(in: .namespace(namespace), name: name, scale: scale)
    }

    // MARK: - Jobs

    public func listJobs(namespace: NamespaceSelector) async throws -> [JobInfo] {
        let jobs = try await client.batchV1.jobs.list(in: namespace.toSwiftkube())
        return jobs.items.map { JobInfo(from: $0) }
    }

    public func getJob(namespace: String, name: String) async throws -> JobInfo? {
        let job = try await client.batchV1.jobs.get(in: .namespace(namespace), name: name)
        return JobInfo(from: job)
    }

    public func deleteJob(namespace: String, name: String) async throws {
        try await client.batchV1.jobs.delete(in: .namespace(namespace), name: name)
    }

    // MARK: - CronJobs

    public func listCronJobs(namespace: NamespaceSelector) async throws -> [CronJobInfo] {
        let cronJobs = try await client.batchV1.cronJobs.list(in: namespace.toSwiftkube())
        return cronJobs.items.map { CronJobInfo(from: $0) }
    }

    // MARK: - StatefulSets

    public func listStatefulSets(namespace: NamespaceSelector) async throws -> [StatefulSetInfo] {
        let sets = try await client.appsV1.statefulSets.list(in: namespace.toSwiftkube())
        return sets.items.map { StatefulSetInfo(from: $0) }
    }

    // MARK: - DaemonSets

    public func listDaemonSets(namespace: NamespaceSelector) async throws -> [DaemonSetInfo] {
        let sets = try await client.appsV1.daemonSets.list(in: namespace.toSwiftkube())
        return sets.items.map { DaemonSetInfo(from: $0) }
    }

    // MARK: - Services

    public func listServices(namespace: NamespaceSelector) async throws -> [ServiceInfo] {
        let services = try await client.services.list(in: namespace.toSwiftkube())
        return services.items.map { ServiceInfo(from: $0) }
    }

    // MARK: - Ingresses

    public func listIngresses(namespace: NamespaceSelector) async throws -> [IngressInfo] {
        let ingresses = try await client.networkingV1.ingresses.list(in: namespace.toSwiftkube())
        return ingresses.items.map { IngressInfo(from: $0) }
    }

    // MARK: - Nodes

    public func listNodes() async throws -> [NodeInfo] {
        let nodes = try await client.nodes.list()
        return nodes.items.map { NodeInfo(from: $0) }
    }

    // MARK: - Events

    public func listEvents(namespace: NamespaceSelector) async throws -> [EventInfo] {
        let events = try await client.events.list(in: namespace.toSwiftkube())
        return events.items.map { EventInfo(from: $0) }
    }

    // MARK: - Namespaces

    public func listNamespaces() async throws -> [NamespaceInfo] {
        let namespaces = try await client.namespaces.list()
        return namespaces.items.map { NamespaceInfo(from: $0) }
    }

    // MARK: - Config Resources

    public func listConfigMaps(namespace: NamespaceSelector) async throws -> [ConfigMapInfo] {
        let cms = try await client.configMaps.list(in: namespace.toSwiftkube())
        return cms.items.map { ConfigMapInfo(from: $0) }
    }

    public func listSecrets(namespace: NamespaceSelector) async throws -> [SecretInfo] {
        let secrets = try await client.secrets.list(in: namespace.toSwiftkube())
        return secrets.items.map { SecretInfo(from: $0) }
    }

    public func listPVCs(namespace: NamespaceSelector) async throws -> [PVCInfo] {
        let pvcs = try await client.persistentVolumeClaims.list(in: namespace.toSwiftkube())
        return pvcs.items.map { PVCInfo(from: $0) }
    }
}

// MARK: - Namespace Conversion

extension NamespaceSelector {
    func toSwiftkube() -> SwiftkubeModel.NamespaceSelector {
        switch self {
        case .all:
            return .allNamespaces
        case .namespace(let ns):
            return .namespace(ns)
        }
    }
}

// MARK: - Model Conversions

extension PodInfo {
    init(from pod: core.v1.Pod) {
        let containers = (pod.status?.containerStatuses ?? []).map { status in
            ContainerInfo(
                name: status.name,
                image: status.image,
                state: ContainerState(from: status.state),
                ready: status.ready,
                restartCount: status.restartCount
            )
        }

        let phase: PodPhase
        switch pod.status?.phase {
        case "Running": phase = .running
        case "Pending": phase = .pending
        case "Succeeded": phase = .succeeded
        case "Failed": phase = .failed
        default: phase = .unknown
        }

        let health: ResourceHealth
        switch phase {
        case .running:
            let allReady = containers.allSatisfy { $0.ready }
            let hasCrashLoop = containers.contains { container in
                if case .waiting(let reason) = container.state, reason == "CrashLoopBackOff" {
                    return true
                }
                return false
            }
            if hasCrashLoop { health = .error }
            else if allReady { health = .healthy }
            else { health = .warning }
        case .succeeded: health = .healthy
        case .failed: health = .error
        case .pending: health = .warning
        case .unknown: health = .unknown
        }

        let ownerRef = pod.metadata?.ownerReferences?.first

        self.init(
            name: pod.name ?? "unknown",
            namespace: pod.metadata?.namespace ?? "default",
            phase: phase,
            containers: containers,
            nodeName: pod.spec?.nodeName,
            startTime: pod.status?.startTime,
            labels: pod.metadata?.labels ?? [:],
            health: health,
            ownerKind: ownerRef?.kind,
            ownerName: ownerRef?.name
        )
    }
}

extension ContainerState {
    init(from state: core.v1.ContainerState?) {
        if let running = state?.running {
            self = .running(startedAt: running.startedAt)
        } else if let waiting = state?.waiting {
            self = .waiting(reason: waiting.reason)
        } else if let terminated = state?.terminated {
            self = .terminated(
                reason: terminated.reason,
                exitCode: terminated.exitCode,
                finishedAt: terminated.finishedAt
            )
        } else {
            self = .waiting(reason: nil)
        }
    }
}

extension DeploymentInfo {
    init(from deployment: apps.v1.Deployment) {
        let replicas = deployment.spec?.replicas ?? 0
        let ready = deployment.status?.readyReplicas ?? 0
        let available = deployment.status?.availableReplicas ?? 0

        let health: ResourceHealth
        if available == replicas && ready == replicas && replicas > 0 {
            health = .healthy
        } else if available > 0 {
            health = .warning
        } else if replicas > 0 {
            health = .error
        } else {
            health = .unknown
        }

        self.init(
            name: deployment.name ?? "unknown",
            namespace: deployment.metadata?.namespace ?? "default",
            replicas: replicas,
            readyReplicas: ready,
            updatedReplicas: deployment.status?.updatedReplicas ?? 0,
            availableReplicas: available,
            labels: deployment.metadata?.labels ?? [:],
            health: health,
            creationTimestamp: deployment.metadata?.creationTimestamp
        )
    }
}

extension JobInfo {
    init(from job: batch.v1.Job) {
        let active = job.status?.active ?? 0
        let succeeded = job.status?.succeeded ?? 0
        let failed = job.status?.failed ?? 0

        let health: ResourceHealth
        if succeeded > 0 && active == 0 && failed == 0 {
            health = .healthy
        } else if failed > 0 {
            health = .error
        } else if active > 0 {
            health = .warning
        } else {
            health = .unknown
        }

        let ownerRef = job.metadata?.ownerReferences?.first

        self.init(
            name: job.name ?? "unknown",
            namespace: job.metadata?.namespace ?? "default",
            active: active,
            succeeded: succeeded,
            failed: failed,
            startTime: job.status?.startTime,
            completionTime: job.status?.completionTime,
            labels: job.metadata?.labels ?? [:],
            health: health,
            ownerName: ownerRef?.name
        )
    }
}

extension CronJobInfo {
    init(from cronJob: batch.v1.CronJob) {
        let activeJobs = cronJob.status?.active?.count ?? 0

        let health: ResourceHealth
        if cronJob.spec?.suspend == true {
            health = .warning
        } else {
            health = .healthy
        }

        self.init(
            name: cronJob.name ?? "unknown",
            namespace: cronJob.metadata?.namespace ?? "default",
            schedule: cronJob.spec?.schedule ?? "unknown",
            suspend: cronJob.spec?.suspend ?? false,
            activeJobs: activeJobs,
            lastScheduleTime: cronJob.status?.lastScheduleTime,
            lastSuccessfulTime: cronJob.status?.lastSuccessfulTime,
            labels: cronJob.metadata?.labels ?? [:],
            health: health
        )
    }
}

extension StatefulSetInfo {
    init(from ss: apps.v1.StatefulSet) {
        let replicas = ss.spec?.replicas ?? 0
        let ready = ss.status?.readyReplicas ?? 0

        let health: ResourceHealth
        if ready == replicas && replicas > 0 { health = .healthy }
        else if ready > 0 { health = .warning }
        else if replicas > 0 { health = .error }
        else { health = .unknown }

        self.init(
            name: ss.name ?? "unknown",
            namespace: ss.metadata?.namespace ?? "default",
            replicas: replicas,
            readyReplicas: ready,
            currentReplicas: ss.status?.currentReplicas ?? 0,
            labels: ss.metadata?.labels ?? [:],
            health: health
        )
    }
}

extension DaemonSetInfo {
    init(from ds: apps.v1.DaemonSet) {
        let desired = ds.status?.desiredNumberScheduled ?? 0
        let ready = ds.status?.numberReady ?? 0

        let health: ResourceHealth
        if ready == desired && desired > 0 { health = .healthy }
        else if ready > 0 { health = .warning }
        else if desired > 0 { health = .error }
        else { health = .unknown }

        self.init(
            name: ds.name ?? "unknown",
            namespace: ds.metadata?.namespace ?? "default",
            desiredNumberScheduled: desired,
            currentNumberScheduled: ds.status?.currentNumberScheduled ?? 0,
            numberReady: ready,
            numberAvailable: ds.status?.numberAvailable ?? 0,
            labels: ds.metadata?.labels ?? [:],
            health: health
        )
    }
}

extension ServiceInfo {
    init(from svc: core.v1.Service) {
        let ports = (svc.spec?.ports ?? []).map { port in
            let targetPortStr: String
            if let tp = port.targetPort {
                switch tp {
                case .int(let value): targetPortStr = "\(value)"
                case .string(let value): targetPortStr = value
                }
            } else {
                targetPortStr = "\(port.port)"
            }
            return Models.ServicePort(
                name: port.name,
                port: port.port,
                targetPort: targetPortStr,
                protocol_: port.protocol_ ?? "TCP"
            )
        }

        self.init(
            name: svc.name ?? "unknown",
            namespace: svc.metadata?.namespace ?? "default",
            type: svc.spec?.type ?? "ClusterIP",
            clusterIP: svc.spec?.clusterIP,
            externalIPs: svc.spec?.externalIPs ?? [],
            ports: ports,
            labels: svc.metadata?.labels ?? [:]
        )
    }
}

extension IngressInfo {
    init(from ingress: networking.v1.Ingress) {
        let hosts = (ingress.spec?.rules ?? []).compactMap { $0.host }

        self.init(
            name: ingress.name ?? "unknown",
            namespace: ingress.metadata?.namespace ?? "default",
            hosts: hosts,
            ingressClassName: ingress.spec?.ingressClassName,
            labels: ingress.metadata?.labels ?? [:]
        )
    }
}

extension NodeInfo {
    init(from node: core.v1.Node) {
        let conditions = (node.status?.conditions ?? []).map { cond in
            Models.NodeCondition(
                type: cond.type,
                status: cond.status,
                reason: cond.reason,
                message: cond.message
            )
        }

        let ready = conditions.first { $0.type == "Ready" }?.status == "True"
        let roles = (node.metadata?.labels ?? [:])
            .keys
            .filter { $0.hasPrefix("node-role.kubernetes.io/") }
            .map { String($0.dropFirst("node-role.kubernetes.io/".count)) }

        self.init(
            name: node.name ?? "unknown",
            ready: ready,
            roles: roles.isEmpty ? ["worker"] : roles,
            kubeletVersion: node.status?.nodeInfo?.kubeletVersion ?? "unknown",
            osImage: node.status?.nodeInfo?.osImage ?? "unknown",
            allocatableCPU: node.status?.allocatable?["cpu"]?.stringValue ?? "0",
            allocatableMemory: node.status?.allocatable?["memory"]?.stringValue ?? "0",
            conditions: conditions,
            health: ready ? .healthy : .error
        )
    }
}

extension EventInfo {
    init(from event: core.v1.Event) {
        self.init(
            id: event.metadata?.uid ?? UUID().uuidString,
            namespace: event.metadata?.namespace ?? "default",
            involvedObjectKind: event.involvedObject?.kind ?? "unknown",
            involvedObjectName: event.involvedObject?.name ?? "unknown",
            reason: event.reason ?? "Unknown",
            message: event.message ?? "",
            type: event.type ?? "Normal",
            firstTimestamp: event.firstTimestamp,
            lastTimestamp: event.lastTimestamp,
            count: event.count ?? 1
        )
    }
}

extension NamespaceInfo {
    init(from ns: core.v1.Namespace) {
        self.init(
            name: ns.name ?? "unknown",
            status: ns.status?.phase ?? "Active",
            labels: ns.metadata?.labels ?? [:]
        )
    }
}

extension ConfigMapInfo {
    init(from cm: core.v1.ConfigMap) {
        self.init(
            name: cm.name ?? "unknown",
            namespace: cm.metadata?.namespace ?? "default",
            dataKeys: Array(cm.data?.keys ?? [String: String]().keys),
            creationTimestamp: cm.metadata?.creationTimestamp
        )
    }
}

extension SecretInfo {
    init(from secret: core.v1.Secret) {
        self.init(
            name: secret.name ?? "unknown",
            namespace: secret.metadata?.namespace ?? "default",
            type: secret.type ?? "Opaque",
            dataKeys: Array(secret.data?.keys ?? [String: Data]().keys),
            creationTimestamp: secret.metadata?.creationTimestamp
        )
    }
}

extension PVCInfo {
    init(from pvc: core.v1.PersistentVolumeClaim) {
        self.init(
            name: pvc.name ?? "unknown",
            namespace: pvc.metadata?.namespace ?? "default",
            status: pvc.status?.phase ?? "Unknown",
            storageClass: pvc.spec?.storageClassName,
            capacity: pvc.status?.capacity?["storage"]?.stringValue,
            accessModes: pvc.spec?.accessModes ?? []
        )
    }
}
