/// Tests for the ResourceCache actor.

import Foundation
import Testing
@testable import K8s
@testable import Models

@Suite("ResourceCache Tests")
struct ResourceCacheTests {

    @Test("Empty cache returns empty arrays")
    func emptyCacheReturnsEmpty() async {
        let cache = ResourceCache()

        let pods = await cache.pods()
        #expect(pods.isEmpty)

        let deployments = await cache.deployments()
        #expect(deployments.isEmpty)

        let summary = await cache.clusterSummary()
        #expect(summary.totalPods == 0)
        #expect(summary.totalDeployments == 0)
    }

    @Test("Update and retrieve pods")
    func updateAndRetrievePods() async {
        let cache = ResourceCache()

        let testPods = [
            PodInfo(name: "web-1", namespace: "default", phase: .running,
                    containers: [], nodeName: "node-1", startTime: Date(),
                    labels: ["app": "web"], health: .healthy),
            PodInfo(name: "api-1", namespace: "production", phase: .running,
                    containers: [], nodeName: "node-2", startTime: Date(),
                    labels: ["app": "api"], health: .healthy),
            PodInfo(name: "worker-1", namespace: "default", phase: .failed,
                    containers: [], nodeName: "node-1", startTime: Date(),
                    labels: ["app": "worker"], health: .error),
        ]

        await cache.updatePods(testPods)

        let allPods = await cache.pods()
        #expect(allPods.count == 3)

        let defaultPods = await cache.pods(namespace: "default")
        #expect(defaultPods.count == 2)

        let prodPods = await cache.pods(namespace: "production")
        #expect(prodPods.count == 1)
        #expect(prodPods[0].name == "api-1")
    }

    @Test("Retrieve single pod by namespace and name")
    func getPodByName() async {
        let cache = ResourceCache()

        let testPod = PodInfo(name: "web-1", namespace: "default", phase: .running,
                              containers: [], nodeName: nil, startTime: nil,
                              labels: [:], health: .healthy)
        await cache.updatePods([testPod])

        let found = await cache.pod(namespace: "default", name: "web-1")
        #expect(found != nil)
        #expect(found?.name == "web-1")

        let notFound = await cache.pod(namespace: "default", name: "nonexistent")
        #expect(notFound == nil)
    }

    @Test("Cluster summary computes correct counts")
    func clusterSummary() async {
        let cache = ResourceCache()

        await cache.updatePods([
            PodInfo(name: "p1", namespace: "default", phase: .running, containers: [], nodeName: nil, startTime: nil, labels: [:], health: .healthy),
            PodInfo(name: "p2", namespace: "default", phase: .running, containers: [], nodeName: nil, startTime: nil, labels: [:], health: .healthy),
            PodInfo(name: "p3", namespace: "default", phase: .pending, containers: [], nodeName: nil, startTime: nil, labels: [:], health: .warning),
            PodInfo(name: "p4", namespace: "default", phase: .failed, containers: [], nodeName: nil, startTime: nil, labels: [:], health: .error),
        ])

        await cache.updateDeployments([
            DeploymentInfo(name: "d1", namespace: "default", replicas: 3, readyReplicas: 3, updatedReplicas: 3, availableReplicas: 3, labels: [:], health: .healthy),
            DeploymentInfo(name: "d2", namespace: "default", replicas: 2, readyReplicas: 1, updatedReplicas: 2, availableReplicas: 1, labels: [:], health: .warning),
        ])

        await cache.updateNodes([
            NodeInfo(name: "n1", ready: true, roles: ["master"], kubeletVersion: "1.28", osImage: "Ubuntu", allocatableCPU: "4", allocatableMemory: "8Gi", conditions: [], health: .healthy),
            NodeInfo(name: "n2", ready: false, roles: ["worker"], kubeletVersion: "1.28", osImage: "Ubuntu", allocatableCPU: "4", allocatableMemory: "8Gi", conditions: [], health: .error),
        ])

        let summary = await cache.clusterSummary()
        #expect(summary.totalPods == 4)
        #expect(summary.runningPods == 2)
        #expect(summary.pendingPods == 1)
        #expect(summary.failedPods == 1)
        #expect(summary.totalDeployments == 2)
        #expect(summary.healthyDeployments == 1)
        #expect(summary.totalNodes == 2)
        #expect(summary.readyNodes == 1)
    }

    @Test("Cache subscription receives events")
    func subscriptionReceivesEvents() async {
        let cache = ResourceCache()

        let (subId, stream) = await cache.subscribe()

        // Update in background
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            await cache.updatePods([
                PodInfo(name: "p1", namespace: "default", phase: .running, containers: [], nodeName: nil, startTime: nil, labels: [:], health: .healthy),
            ])
        }

        var received: CacheEvent?
        for await event in stream {
            received = event
            break
        }

        #expect(received == .podsUpdated)
        await cache.unsubscribe(id: subId)
    }

    @Test("Namespace filtering works for all resource types")
    func namespaceFiltering() async {
        let cache = ResourceCache()

        await cache.updateDeployments([
            DeploymentInfo(name: "d1", namespace: "ns1", replicas: 1, readyReplicas: 1, updatedReplicas: 1, availableReplicas: 1, labels: [:], health: .healthy),
            DeploymentInfo(name: "d2", namespace: "ns2", replicas: 1, readyReplicas: 1, updatedReplicas: 1, availableReplicas: 1, labels: [:], health: .healthy),
        ])

        await cache.updateJobs([
            JobInfo(name: "j1", namespace: "ns1", active: 0, succeeded: 1, failed: 0, startTime: nil, completionTime: nil, labels: [:], health: .healthy),
        ])

        let ns1Deployments = await cache.deployments(namespace: "ns1")
        #expect(ns1Deployments.count == 1)

        let ns2Jobs = await cache.jobs(namespace: "ns2")
        #expect(ns2Jobs.isEmpty)
    }

    @Test("ResourceFilter filters by namespace")
    func filterByNamespace() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        let filter = ResourceFilter(namespace: "production")
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 1)
        #expect(pods[0].name == "api-ghi789")
    }

    @Test("ResourceFilter filters by label selectors")
    func filterByLabels() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        let filter = ResourceFilter(labelSelectors: ["app": "web"])
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 1)
        #expect(pods[0].name == "web-abc123")
    }

    @Test("ResourceFilter filters by health status")
    func filterByHealth() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        let filter = ResourceFilter(health: .error)
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 1)
        #expect(pods[0].name == "worker-def456")
    }

    @Test("ResourceFilter filters by name search")
    func filterByNameSearch() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        let filter = ResourceFilter(nameContains: "api")
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 1)
        #expect(pods[0].name == "api-ghi789")
    }

    @Test("ResourceFilter combines multiple selectors with AND logic")
    func filterCombined() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        // namespace=default AND health=healthy -> only web-abc123
        let filter = ResourceFilter(namespace: "default", health: .healthy)
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 1)
        #expect(pods[0].name == "web-abc123")
    }

    @Test("ResourceFilter empty filter returns all")
    func filterEmpty() async {
        let cache = ResourceCache()
        await cache.updatePods(TestFixtures.samplePods())

        let filter = ResourceFilter()
        let pods = await cache.pods(filter: filter)
        #expect(pods.count == 3)
    }

    @Test("ResourceFilter.parseLabels parses correctly")
    func parseLabels() {
        let labels = ResourceFilter.parseLabels("app=nginx,env=prod")
        #expect(labels == ["app": "nginx", "env": "prod"])

        let empty = ResourceFilter.parseLabels(nil)
        #expect(empty.isEmpty)

        let emptyStr = ResourceFilter.parseLabels("")
        #expect(emptyStr.isEmpty)

        let single = ResourceFilter.parseLabels("app=web")
        #expect(single == ["app": "web"])
    }

    @Test("ResourceFilter.queryString builds correct URL params")
    func queryString() {
        let empty = ResourceFilter()
        #expect(empty.queryString == "")

        let nsOnly = ResourceFilter(namespace: "default")
        #expect(nsOnly.queryString == "?namespace=default")

        let full = ResourceFilter(namespace: "prod", health: .error, nameContains: "api")
        #expect(full.queryString.contains("namespace=prod"))
        #expect(full.queryString.contains("health=error"))
        #expect(full.queryString.contains("search=api"))
    }

    @Test("ResourceFilter works with deployments")
    func filterDeployments() async {
        let cache = ResourceCache()
        await cache.updateDeployments(TestFixtures.sampleDeployments())

        let filter = ResourceFilter(health: .warning)
        let deployments = await cache.deployments(filter: filter)
        #expect(deployments.count == 1)
        #expect(deployments[0].name == "api")
    }

    @Test("ResourceFilter works with jobs")
    func filterJobs() async {
        let cache = ResourceCache()
        await cache.updateJobs(TestFixtures.sampleJobs())

        let filter = ResourceFilter(namespace: "production", labelSelectors: ["job": "report"])
        let jobs = await cache.jobs(filter: filter)
        #expect(jobs.count == 1)
        #expect(jobs[0].name == "report-gen-11111")
    }
}
