/// Tests for the ResourceWatcher.

import Testing
@testable import K8s
@testable import Models

@Suite("ResourceWatcher Tests")
struct ResourceWatcherTests {

    @Test("Watcher populates cache from mock client")
    func watcherPopulatesCache() async throws {
        let mockClient = MockK8sClient()
        mockClient.pods = [
            PodInfo(name: "test-pod", namespace: "default", phase: .running,
                    containers: [], nodeName: "node-1", startTime: Date(),
                    labels: [:], health: .healthy),
        ]
        mockClient.namespaces = [
            NamespaceInfo(name: "default", status: "Active", labels: [:]),
        ]

        let cache = ResourceCache()
        let watcher = ResourceWatcher(
            client: mockClient,
            cache: cache,
            config: WatcherConfig(
                fastPollInterval: .milliseconds(100),
                normalPollInterval: .milliseconds(100),
                slowPollInterval: .milliseconds(100)
            )
        )

        await watcher.start()
        // Wait for at least one poll cycle
        try await Task.sleep(for: .milliseconds(300))
        await watcher.stop()

        let pods = await cache.pods()
        #expect(pods.count == 1)
        #expect(pods[0].name == "test-pod")

        let namespaces = await cache.namespaces()
        #expect(namespaces.count == 1)
    }

    @Test("Watcher handles errors gracefully")
    func watcherHandlesErrors() async throws {
        let mockClient = MockK8sClient()
        mockClient.shouldThrow = MockError.simulatedFailure

        let cache = ResourceCache()
        let watcher = ResourceWatcher(
            client: mockClient,
            cache: cache,
            config: WatcherConfig(
                fastPollInterval: .milliseconds(100),
                normalPollInterval: .milliseconds(100),
                slowPollInterval: .milliseconds(100)
            )
        )

        await watcher.start()
        try await Task.sleep(for: .milliseconds(300))
        await watcher.stop()

        // Cache should remain empty but not crash
        let pods = await cache.pods()
        #expect(pods.isEmpty)
    }

    @Test("Watcher stops cleanly")
    func watcherStopsCleanly() async throws {
        let mockClient = MockK8sClient()
        let cache = ResourceCache()
        let watcher = ResourceWatcher(
            client: mockClient,
            cache: cache,
            config: WatcherConfig(
                fastPollInterval: .milliseconds(50),
                normalPollInterval: .milliseconds(50),
                slowPollInterval: .milliseconds(50)
            )
        )

        await watcher.start()
        try await Task.sleep(for: .milliseconds(100))
        await watcher.stop()

        // Should not crash or hang
    }
}
