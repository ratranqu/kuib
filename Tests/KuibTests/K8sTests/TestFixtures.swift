/// Test fixture data for Kubernetes resources.

import Foundation
@testable import Models

/// Factory methods for creating test data.
public enum TestFixtures {

    // MARK: - Pods

    public static func samplePods() -> [PodInfo] {
        [
            PodInfo(
                name: "web-abc123", namespace: "default", phase: .running,
                containers: [
                    ContainerInfo(name: "web", image: "nginx:1.25", state: .running(startedAt: Date()), ready: true, restartCount: 0),
                ],
                nodeName: "node-1", startTime: Date().addingTimeInterval(-3600),
                labels: ["app": "web", "version": "v1"], health: .healthy
            ),
            PodInfo(
                name: "worker-def456", namespace: "default", phase: .running,
                containers: [
                    ContainerInfo(name: "worker", image: "myapp:latest", state: .waiting(reason: "CrashLoopBackOff"), ready: false, restartCount: 15),
                ],
                nodeName: "node-2", startTime: Date().addingTimeInterval(-7200),
                labels: ["app": "worker"], health: .error
            ),
            PodInfo(
                name: "api-ghi789", namespace: "production", phase: .running,
                containers: [
                    ContainerInfo(name: "api", image: "myapp-api:v2", state: .running(startedAt: Date()), ready: true, restartCount: 0),
                    ContainerInfo(name: "sidecar", image: "envoy:1.28", state: .running(startedAt: Date()), ready: true, restartCount: 0),
                ],
                nodeName: "node-1", startTime: Date().addingTimeInterval(-86400),
                labels: ["app": "api", "version": "v2"], health: .healthy
            ),
        ]
    }

    // MARK: - Deployments

    public static func sampleDeployments() -> [DeploymentInfo] {
        [
            DeploymentInfo(name: "web", namespace: "default", replicas: 3, readyReplicas: 3,
                           updatedReplicas: 3, availableReplicas: 3,
                           labels: ["app": "web"], health: .healthy),
            DeploymentInfo(name: "api", namespace: "production", replicas: 5, readyReplicas: 3,
                           updatedReplicas: 5, availableReplicas: 3,
                           labels: ["app": "api"], health: .warning),
            DeploymentInfo(name: "worker", namespace: "default", replicas: 2, readyReplicas: 0,
                           updatedReplicas: 2, availableReplicas: 0,
                           labels: ["app": "worker"], health: .error),
        ]
    }

    // MARK: - Jobs

    public static func sampleJobs() -> [JobInfo] {
        [
            JobInfo(name: "migrate-db-12345", namespace: "default", active: 0, succeeded: 1, failed: 0,
                    startTime: Date().addingTimeInterval(-300), completionTime: Date().addingTimeInterval(-120),
                    labels: ["job": "migration"], health: .healthy, ownerName: "migrate-db"),
            JobInfo(name: "backup-67890", namespace: "default", active: 0, succeeded: 0, failed: 3,
                    startTime: Date().addingTimeInterval(-600), completionTime: nil,
                    labels: ["job": "backup"], health: .error, ownerName: "backup"),
            JobInfo(name: "report-gen-11111", namespace: "production", active: 1, succeeded: 0, failed: 0,
                    startTime: Date(), completionTime: nil,
                    labels: ["job": "report"], health: .warning),
        ]
    }

    // MARK: - Nodes

    public static func sampleNodes() -> [NodeInfo] {
        [
            NodeInfo(name: "node-1", ready: true, roles: ["control-plane"],
                     kubeletVersion: "v1.28.5", osImage: "Ubuntu 22.04",
                     allocatableCPU: "8", allocatableMemory: "32Gi",
                     conditions: [NodeCondition(type: "Ready", status: "True", reason: nil, message: nil)],
                     health: .healthy),
            NodeInfo(name: "node-2", ready: true, roles: ["worker"],
                     kubeletVersion: "v1.28.5", osImage: "Ubuntu 22.04",
                     allocatableCPU: "16", allocatableMemory: "64Gi",
                     conditions: [NodeCondition(type: "Ready", status: "True", reason: nil, message: nil)],
                     health: .healthy),
            NodeInfo(name: "node-3", ready: false, roles: ["worker"],
                     kubeletVersion: "v1.28.5", osImage: "Ubuntu 22.04",
                     allocatableCPU: "16", allocatableMemory: "64Gi",
                     conditions: [
                        NodeCondition(type: "Ready", status: "False", reason: "KubeletNotReady", message: "container runtime not ready"),
                        NodeCondition(type: "MemoryPressure", status: "True", reason: nil, message: nil),
                     ],
                     health: .error),
        ]
    }

    // MARK: - Events

    public static func sampleEvents() -> [EventInfo] {
        [
            EventInfo(id: "evt-1", namespace: "default", involvedObjectKind: "Pod",
                      involvedObjectName: "web-abc123", reason: "Scheduled",
                      message: "Successfully assigned default/web-abc123 to node-1",
                      type: "Normal", firstTimestamp: Date().addingTimeInterval(-3600),
                      lastTimestamp: Date().addingTimeInterval(-3600), count: 1),
            EventInfo(id: "evt-2", namespace: "default", involvedObjectKind: "Pod",
                      involvedObjectName: "worker-def456", reason: "BackOff",
                      message: "Back-off restarting failed container",
                      type: "Warning", firstTimestamp: Date().addingTimeInterval(-7200),
                      lastTimestamp: Date().addingTimeInterval(-60), count: 42),
            EventInfo(id: "evt-3", namespace: "production", involvedObjectKind: "Deployment",
                      involvedObjectName: "api", reason: "ScalingReplicaSet",
                      message: "Scaled up replica set api-789 to 5",
                      type: "Normal", firstTimestamp: Date().addingTimeInterval(-1800),
                      lastTimestamp: Date().addingTimeInterval(-1800), count: 1),
        ]
    }

    // MARK: - Namespaces

    public static func sampleNamespaces() -> [NamespaceInfo] {
        [
            NamespaceInfo(name: "default", status: "Active", labels: [:]),
            NamespaceInfo(name: "production", status: "Active", labels: ["env": "prod"]),
            NamespaceInfo(name: "kube-system", status: "Active", labels: [:]),
        ]
    }

    // MARK: - CronJobs

    public static func sampleCronJobs() -> [CronJobInfo] {
        [
            CronJobInfo(name: "backup", namespace: "default", schedule: "0 2 * * *",
                        suspend: false, activeJobs: 0,
                        lastScheduleTime: Date().addingTimeInterval(-86400),
                        lastSuccessfulTime: Date().addingTimeInterval(-86400),
                        labels: ["app": "backup"], health: .healthy),
        ]
    }

    // MARK: - Cluster Summary

    public static func sampleClusterSummary() -> ClusterSummary {
        ClusterSummary(
            totalPods: 25, runningPods: 20, pendingPods: 3, failedPods: 2,
            totalDeployments: 8, healthyDeployments: 6,
            totalJobs: 5, failedJobs: 1,
            totalNodes: 3, readyNodes: 2,
            recentAlerts: 3, namespaces: 4
        )
    }
}
