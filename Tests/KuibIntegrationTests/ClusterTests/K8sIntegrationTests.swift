/// Integration tests that run against a real Kubernetes cluster (Kind).
///
/// These tests are skipped when `KIND_AVAILABLE` environment variable is not set.
/// To run: `KIND_AVAILABLE=true swift test --filter KuibIntegrationTests`

import Testing
import Foundation
@testable import K8s
@testable import Models

/// Check if a Kind cluster is available for testing.
func isKindAvailable() -> Bool {
    ProcessInfo.processInfo.environment["KIND_AVAILABLE"] == "true"
}

@Suite("Kubernetes Integration Tests", .enabled(if: isKindAvailable()))
struct K8sIntegrationTests {

    @Test("Can connect to cluster and list namespaces")
    func listNamespaces() async throws {
        let client = try SwiftkubeK8sClient()
        defer { Task { try? await client.shutdown() } }

        let namespaces = try await client.listNamespaces()
        #expect(!namespaces.isEmpty)
        #expect(namespaces.contains { $0.name == "default" })
        #expect(namespaces.contains { $0.name == "kube-system" })
    }

    @Test("Can list pods in kube-system")
    func listPodsKubeSystem() async throws {
        let client = try SwiftkubeK8sClient()
        defer { Task { try? await client.shutdown() } }

        let pods = try await client.listPods(namespace: .namespace("kube-system"))
        #expect(!pods.isEmpty)

        // Should have at least coredns running
        let hasCoreDNS = pods.contains { $0.name.contains("coredns") }
        #expect(hasCoreDNS)
    }

    @Test("Can list nodes")
    func listNodes() async throws {
        let client = try SwiftkubeK8sClient()
        defer { Task { try? await client.shutdown() } }

        let nodes = try await client.listNodes()
        #expect(!nodes.isEmpty)
        #expect(nodes[0].ready)
    }

    @Test("Can list all resource types without error")
    func listAllResources() async throws {
        let client = try SwiftkubeK8sClient()
        defer { Task { try? await client.shutdown() } }

        _ = try await client.listPods(namespace: .all)
        _ = try await client.listDeployments(namespace: .all)
        _ = try await client.listJobs(namespace: .all)
        _ = try await client.listCronJobs(namespace: .all)
        _ = try await client.listStatefulSets(namespace: .all)
        _ = try await client.listDaemonSets(namespace: .all)
        _ = try await client.listServices(namespace: .all)
        _ = try await client.listIngresses(namespace: .all)
        _ = try await client.listEvents(namespace: .all)
        _ = try await client.listConfigMaps(namespace: .all)
        _ = try await client.listSecrets(namespace: .all)
        _ = try await client.listPVCs(namespace: .all)
        _ = try await client.listNodes()
        _ = try await client.listNamespaces()
    }

    @Test("ResourceWatcher populates cache from real cluster")
    func watcherWithRealCluster() async throws {
        let client = try SwiftkubeK8sClient()
        let cache = ResourceCache()
        let watcher = ResourceWatcher(
            client: client,
            cache: cache,
            config: WatcherConfig(
                fastPollInterval: .milliseconds(500),
                normalPollInterval: .milliseconds(500),
                slowPollInterval: .milliseconds(500)
            )
        )

        await watcher.start()
        try await Task.sleep(for: .seconds(2))
        await watcher.stop()
        try await client.shutdown()

        let pods = await cache.pods()
        #expect(!pods.isEmpty)

        let namespaces = await cache.namespaces()
        #expect(namespaces.contains { $0.name == "default" })

        let summary = await cache.clusterSummary()
        #expect(summary.totalPods > 0)
        #expect(summary.totalNodes > 0)
    }
}
