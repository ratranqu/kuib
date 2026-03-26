# Testing Guide

## Test Structure

```
Tests/
├── KuibTests/                    # Unit tests (no external dependencies)
│   ├── K8sTests/
│   │   ├── MockK8sClient.swift   # Mock Kubernetes client
│   │   ├── MockClientTests.swift # Tests for the mock itself
│   │   ├── ResourceCacheTests.swift
│   │   └── ResourceWatcherTests.swift
│   ├── PageTests/
│   │   └── PageRenderTests.swift # HTML rendering tests
│   └── AlertTests/
│       └── AlertEngineTests.swift
├── KuibIntegrationTests/         # Requires Kind cluster
│   └── ClusterTests/
│       └── K8sIntegrationTests.swift
└── Fixtures/
    └── TestFixtures.swift        # Shared test data factory
```

## Running Tests

### Unit Tests Only
```bash
swift test --filter KuibTests
```

### Integration Tests (requires Kind)
```bash
# Install Kind
brew install kind  # or: go install sigs.k8s.io/kind@latest

# Create a cluster
kind create cluster --name kuib-test

# Run integration tests
KIND_AVAILABLE=true swift test --filter KuibIntegrationTests

# Clean up
kind delete cluster --name kuib-test
```

### All Tests
```bash
swift test
```

## Writing Tests

### Framework
We use Swift Testing (`@Test`, `#expect`). Do not use XCTest.

```swift
import Testing
@testable import K8s

@Suite("My Tests")
struct MyTests {
    @Test("Descriptive test name")
    func testSomething() async throws {
        let cache = ResourceCache()
        // ... setup
        #expect(result == expected)
    }
}
```

### Using the Mock Client
```swift
let client = MockK8sClient()
client.pods = TestFixtures.samplePods()
client.shouldThrow = MockError.simulatedFailure  // To test error handling

let pods = try await client.listPods(namespace: .all)
```

### Testing Pages
Pages are tested by rendering to a string and asserting content:
```swift
let html = render(PodListPartial(pods: testPods))
#expect(html.contains("pod-name"))
#expect(html.contains("badge-healthy"))
```

### Test Fixtures
Add new fixture data to `Tests/Fixtures/TestFixtures.swift`. Use the factory methods to create consistent test data across tests.

## CI Configuration

Unit tests run on every push. Integration tests run when `KIND_AVAILABLE=true`.

Example GitHub Actions workflow:
```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.2"
      - run: swift test --filter KuibTests

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
      - uses: helm/kind-action@v1
      - run: KIND_AVAILABLE=true swift test --filter KuibIntegrationTests
```
