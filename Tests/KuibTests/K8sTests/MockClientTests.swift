/// Tests for the MockK8sClient itself to ensure fixtures work correctly.

import Testing
@testable import K8s
@testable import Models

@Suite("MockK8sClient Tests")
struct MockClientTests {

    @Test("Mock client returns configured pods")
    func returnsConfiguredPods() async throws {
        let client = MockK8sClient()
        client.pods = TestFixtures.samplePods()

        let all = try await client.listPods(namespace: .all)
        #expect(all.count == 3)

        let defaultPods = try await client.listPods(namespace: .namespace("default"))
        #expect(defaultPods.count == 2)
    }

    @Test("Mock client tracks deletions")
    func tracksDeleteActions() async throws {
        let client = MockK8sClient()
        try await client.deletePod(namespace: "default", name: "test-pod")
        try await client.deleteJob(namespace: "batch", name: "test-job")

        #expect(client.deletedPods.count == 1)
        #expect(client.deletedPods[0].name == "test-pod")
        #expect(client.deletedJobs.count == 1)
    }

    @Test("Mock client tracks scale operations")
    func tracksScaleActions() async throws {
        let client = MockK8sClient()
        try await client.scaleDeployment(namespace: "default", name: "web", replicas: 5)

        #expect(client.scaledDeployments.count == 1)
        #expect(client.scaledDeployments[0].replicas == 5)
    }

    @Test("Mock client throws configured errors")
    func throwsConfiguredErrors() async {
        let client = MockK8sClient()
        client.shouldThrow = MockError.simulatedFailure

        do {
            _ = try await client.listPods(namespace: .all)
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error is MockError)
        }
    }
}
