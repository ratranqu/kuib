/// Job and CronJob list and detail pages with Jenkins-style timeline.

import Components
import Database
import Elementary
import Models

// MARK: - Jobs List

/// Page listing all Jobs.
public struct JobListPage: HTML {
    let jobs: [JobInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(jobs: [JobInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.jobs = jobs
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "Jobs", currentPath: "/jobs") {
            PageHeader(title: "Jobs", subtitle: "\(jobs.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/jobs/list")
            }

            div(.id("resource-list")) {
                JobListPartial(jobs: jobs)
            }
        }
    }
}

/// Partial for job list table.
public struct JobListPartial: HTML {
    let jobs: [JobInfo]

    public var content: some HTML {
        if jobs.isEmpty {
            EmptyState("No jobs found")
        } else {
            ResourceTable {
                TableHeader("Name")
                TableHeader("Namespace")
                TableHeader("Status")
                TableHeader("Active")
                TableHeader("Succeeded")
                TableHeader("Failed")
                TableHeader("Duration")
                TableHeader("Started")
            } body: {
                for job in jobs {
                    tr(.class("hover:bg-gray-50")) {
                        TableCell {
                            a(.href("/jobs/\(job.namespace)/\(job.name)"),
                              .class("text-blue-600 hover:text-blue-800 font-medium")) { job.name }
                        }
                        TableCell { span(.class("text-gray-700")) { job.namespace } }
                        TableCell { HealthBadge(job.health) }
                        TableCell { span { "\(job.active)" } }
                        TableCell { span(.class("text-green-600")) { "\(job.succeeded)" } }
                        TableCell { span(.class(job.failed > 0 ? "text-red-600 font-medium" : "text-gray-600")) { "\(job.failed)" } }
                        TableCell {
                            if let duration = job.duration {
                                span(.class("text-gray-600")) { formatDuration(duration) }
                            } else {
                                span(.class("text-gray-400")) { "-" }
                            }
                        }
                        TableCell { Timestamp(job.startTime) }
                    }
                }
            }
        }
    }
}

// MARK: - Job Detail

/// Detail page for a single Job with log access.
public struct JobDetailPage: HTML {
    let job: JobInfo
    let pods: [PodInfo]
    let events: [EventInfo]
    let history: [JobRunRecord]

    public init(job: JobInfo, pods: [PodInfo] = [], events: [EventInfo] = [], history: [JobRunRecord] = []) {
        self.job = job
        self.pods = pods
        self.events = events
        self.history = history
    }

    public var content: some HTML {
        BaseLayout(title: "Job: \(job.name)", currentPath: "/jobs") {
            nav(.class("flex items-center space-x-2 text-sm text-gray-500 mb-4")) {
                a(.href("/jobs"), .class("hover:text-blue-600")) { "Jobs" }
                span { "/" }
                span(.class("text-gray-900")) { job.name }
            }

            PageHeader(title: job.name, subtitle: "Namespace: \(job.namespace)") {
                HealthBadge(job.health)
            }

            // Stats
            div(.class("grid grid-cols-1 md:grid-cols-4 gap-6 mb-6")) {
                StatCard(label: "Active", value: "\(job.active)", color: "blue")
                StatCard(label: "Succeeded", value: "\(job.succeeded)", color: "green")
                StatCard(label: "Failed", value: "\(job.failed)", color: job.failed > 0 ? "red" : "gray")
                StatCard(label: "Duration", value: job.duration.map { formatDuration($0) } ?? "-", color: "gray")
            }

            // Run History Timeline (Jenkins-style)
            if !history.isEmpty {
                div(.class("bg-white rounded-lg shadow mb-6")) {
                    div(.class("px-6 py-4 border-b border-gray-200")) {
                        h2(.class("text-lg font-semibold text-gray-900")) { "Run History" }
                    }
                    div(.class("p-6")) {
                        JobTimeline(history: history)
                    }
                }
            }

            // Pods
            div(.class("bg-white rounded-lg shadow mb-6")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Pods" }
                }
                div(.class("p-6")) {
                    PodListPartial(pods: pods)
                }
            }

            // Events
            div(.class("bg-white rounded-lg shadow")) {
                div(.class("px-6 py-4 border-b border-gray-200")) {
                    h2(.class("text-lg font-semibold text-gray-900")) { "Events" }
                }
                div(.class("p-6")) {
                    RecentEventsPanel(events: events)
                }
            }
        }
    }
}

// MARK: - CronJob List

/// Page listing all CronJobs.
public struct CronJobListPage: HTML {
    let cronJobs: [CronJobInfo]
    let namespaces: [NamespaceInfo]
    let selectedNamespace: String?

    public init(cronJobs: [CronJobInfo], namespaces: [NamespaceInfo], selectedNamespace: String? = nil) {
        self.cronJobs = cronJobs
        self.namespaces = namespaces
        self.selectedNamespace = selectedNamespace
    }

    public var content: some HTML {
        BaseLayout(title: "CronJobs", currentPath: "/cronjobs") {
            PageHeader(title: "CronJobs", subtitle: "\(cronJobs.count) total") {
                NamespaceFilter(namespaces: namespaces, selected: selectedNamespace, targetUrl: "/partials/cronjobs/list")
            }

            div(.id("resource-list")) {
                if cronJobs.isEmpty {
                    EmptyState("No CronJobs found")
                } else {
                    ResourceTable {
                        TableHeader("Name")
                        TableHeader("Namespace")
                        TableHeader("Schedule")
                        TableHeader("Suspended")
                        TableHeader("Active")
                        TableHeader("Last Schedule")
                        TableHeader("Last Success")
                    } body: {
                        for cj in cronJobs {
                            tr(.class("hover:bg-gray-50")) {
                                TableCell {
                                    a(.href("/cronjobs/\(cj.namespace)/\(cj.name)"),
                                      .class("text-blue-600 hover:text-blue-800 font-medium")) { cj.name }
                                }
                                TableCell { span(.class("text-gray-700")) { cj.namespace } }
                                TableCell { code(.class("text-sm bg-gray-100 px-2 py-1 rounded")) { cj.schedule } }
                                TableCell {
                                    if cj.suspend {
                                        span(.class("badge badge-warning")) { "Suspended" }
                                    } else {
                                        span(.class("badge badge-healthy")) { "Active" }
                                    }
                                }
                                TableCell { span { "\(cj.activeJobs)" } }
                                TableCell { Timestamp(cj.lastScheduleTime) }
                                TableCell { Timestamp(cj.lastSuccessfulTime) }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Job Timeline (Jenkins-style)

/// Jenkins-style visual timeline of job runs.
public struct JobTimeline: HTML {
    let history: [JobRunRecord]

    public var content: some HTML {
        div(.class("flex items-end space-x-1 h-24")) {
            for run in history.suffix(30).reversed() {
                let bgColor: String
                switch run.status {
                case "succeeded": bgColor = "bg-green-500"
                case "failed": bgColor = "bg-red-500"
                default: bgColor = "bg-yellow-500"
                }

                let height: String
                if let duration = run.durationSeconds {
                    let maxHeight = 80.0
                    let minHeight = 8.0
                    let normalized = min(max(duration / 300.0, 0), 1) // normalize to 5min max
                    let h = minHeight + (maxHeight - minHeight) * normalized
                    height = "\(Int(h))px"
                } else {
                    height = "16px"
                }

                div(
                    .class("\(bgColor) rounded-t cursor-pointer hover:opacity-80 transition-opacity"),
                    .style("width: 12px; height: \(height);"),
                    .attribute("title", value: "\(run.jobName): \(run.status)\(run.durationSeconds.map { " (\(formatDuration($0)))" } ?? "")")
                ) {}
            }
        }

        // Legend
        div(.class("flex items-center space-x-4 mt-3 text-xs text-gray-500")) {
            div(.class("flex items-center space-x-1")) {
                div(.class("w-3 h-3 bg-green-500 rounded")) {}
                span { "Succeeded" }
            }
            div(.class("flex items-center space-x-1")) {
                div(.class("w-3 h-3 bg-red-500 rounded")) {}
                span { "Failed" }
            }
            div(.class("flex items-center space-x-1")) {
                div(.class("w-3 h-3 bg-yellow-500 rounded")) {}
                span { "Active/Unknown" }
            }
            span(.class("ml-auto")) { "\(history.count) runs" }
        }
    }
}

// MARK: - Duration Formatter

/// Format a duration in seconds to a human-readable string.
public func formatDuration(_ seconds: TimeInterval) -> String {
    let totalSeconds = Int(seconds)
    if totalSeconds < 60 {
        return "\(totalSeconds)s"
    } else if totalSeconds < 3600 {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return "\(m)m \(s)s"
    } else {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        return "\(h)h \(m)m"
    }
}
