/// Tests for HTML page rendering.
///
/// These tests verify that pages render valid HTML containing expected
/// elements, status indicators, and resource data.

import Foundation
import Testing
import Elementary
@testable import Components
@testable import Database
@testable import Models
@testable import Pages

@Suite("Page Rendering Tests")
struct PageRenderTests {

    // Helper to render HTML to string using Elementary's rendering API
    func render(_ html: consuming some HTML) -> String {
        html.render()
    }

    @Test("Dashboard stats render with correct counts")
    func dashboardStatsRender() {
        let summary = TestFixtures.sampleClusterSummary()
        let html = render(DashboardStats(summary: summary))

        #expect(html.contains("20/25"))       // running/total pods
        #expect(html.contains("6/8"))         // healthy/total deployments
        #expect(html.contains("2/3"))         // ready/total nodes
        #expect(html.contains("3"))           // recent alerts
    }

    @Test("Pod list renders all pods")
    func podListRenders() {
        let pods = TestFixtures.samplePods()
        let html = render(PodListPartial(pods: pods))

        #expect(html.contains("web-abc123"))
        #expect(html.contains("worker-def456"))
        #expect(html.contains("api-ghi789"))
        #expect(html.contains("default"))
        #expect(html.contains("production"))
    }

    @Test("Pod list shows empty state when no pods")
    func podListEmptyState() {
        let html = render(PodListPartial(pods: []))
        #expect(html.contains("No pods found"))
    }

    @Test("Health badge renders correct classes")
    func healthBadgeRendersCorrectly() {
        let healthy = render(HealthBadge(.healthy))
        #expect(healthy.contains("badge-healthy"))
        #expect(healthy.contains("Healthy"))

        let error = render(HealthBadge(.error))
        #expect(error.contains("badge-error"))

        let custom = render(HealthBadge(.warning, label: "Degraded"))
        #expect(custom.contains("Degraded"))
    }

    @Test("Pod phase badge shows correct phase")
    func podPhaseBadge() {
        let running = render(PodPhaseBadge(.running))
        #expect(running.contains("Running"))
        #expect(running.contains("badge-healthy"))

        let failed = render(PodPhaseBadge(.failed))
        #expect(failed.contains("Failed"))
        #expect(failed.contains("badge-error"))
    }

    @Test("Stat card renders label and value")
    func statCardRenders() {
        let html = render(StatCard(label: "Pods", value: "42", color: "green", subtitle: "All healthy"))
        #expect(html.contains("Pods"))
        #expect(html.contains("42"))
        #expect(html.contains("All healthy"))
    }

    @Test("Deployment list renders deployments")
    func deploymentListRenders() {
        let deployments = TestFixtures.sampleDeployments()
        let html = render(DeploymentListPartial(deployments: deployments))

        #expect(html.contains("web"))
        #expect(html.contains("api"))
        #expect(html.contains("worker"))
        #expect(html.contains("3/3"))
    }

    @Test("Job list renders jobs with duration")
    func jobListRenders() {
        let jobs = TestFixtures.sampleJobs()
        let html = render(JobListPartial(jobs: jobs))

        #expect(html.contains("migrate-db-12345"))
        #expect(html.contains("backup-67890"))
    }

    @Test("Events list renders with type badges")
    func eventsListRenders() {
        let events = TestFixtures.sampleEvents()
        let html = render(EventsListPartial(events: events))

        #expect(html.contains("Scheduled"))
        #expect(html.contains("BackOff"))
        #expect(html.contains("Warning"))
        #expect(html.contains("Normal"))
    }

    @Test("Issues panel shows healthy state when no issues")
    func issuesPanelHealthy() {
        let html = render(IssuesPanel(pods: [], deployments: []))
        #expect(html.contains("No issues detected"))
    }

    @Test("Issues panel shows problematic resources")
    func issuesPanelWithIssues() {
        let pods = TestFixtures.samplePods().filter { $0.health == .error }
        let html = render(IssuesPanel(pods: pods, deployments: []))
        #expect(html.contains("worker-def456"))
    }

    @Test("Labels display shows limited labels with overflow")
    func labelsDisplay() {
        let labels = ["app": "web", "version": "v1", "env": "prod", "team": "platform", "tier": "frontend"]
        let html = render(LabelsDisplay(labels, maxDisplay: 3))
        #expect(html.contains("+2 more"))
    }

    @Test("Namespace filter renders options")
    func namespaceFilter() {
        let namespaces = TestFixtures.sampleNamespaces()
        let html = render(NamespaceFilter(namespaces: namespaces, selected: "production", targetUrl: "/test"))
        #expect(html.contains("All Namespaces"))
        #expect(html.contains("production"))
        #expect(html.contains("selected"))
    }

    @Test("Resource filter bar renders all filter inputs")
    func resourceFilterBarRenders() {
        let namespaces = TestFixtures.sampleNamespaces()
        let filter = ResourceFilter(namespace: "production", labelSelectors: ["app": "web"], health: .healthy, nameContains: "api")
        let html = render(ResourceFilterBar(namespaces: namespaces, filter: filter, targetUrl: "/partials/pods/list"))

        #expect(html.contains("All Namespaces"))
        #expect(html.contains("production"))
        #expect(html.contains("app=web"))
        #expect(html.contains("api"))
        #expect(html.contains("All Status"))
        #expect(html.contains("active filter"))
    }

    @Test("Resource filter bar hides health filter when disabled")
    func resourceFilterBarNoHealth() {
        let namespaces = TestFixtures.sampleNamespaces()
        let filter = ResourceFilter()
        let html = render(ResourceFilterBar(namespaces: namespaces, filter: filter, targetUrl: "/test", showHealthFilter: false))

        #expect(!html.contains("All Status"))
        #expect(!html.contains("name=\"health\""))
    }

    @Test("Severity badge renders all levels")
    func severityBadge() {
        let info = render(SeverityBadge(.info))
        #expect(info.contains("Info"))

        let warning = render(SeverityBadge(.warning))
        #expect(warning.contains("Warning"))

        let critical = render(SeverityBadge(.critical))
        #expect(critical.contains("Critical"))
    }

    @Test("Job timeline renders bars for history")
    func jobTimeline() {
        let history = [
            JobRunRecord(id: "1", namespace: "default", jobName: "job-1", ownerName: nil, status: "succeeded", startTime: Date(), completionTime: Date(), durationSeconds: 120),
            JobRunRecord(id: "2", namespace: "default", jobName: "job-2", ownerName: nil, status: "failed", startTime: Date(), completionTime: Date(), durationSeconds: 60),
        ]

        let html = render(JobTimeline(history: history))
        #expect(html.contains("bg-green-500"))
        #expect(html.contains("bg-red-500"))
        #expect(html.contains("2 runs"))
    }
}
