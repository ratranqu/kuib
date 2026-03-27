/// Base HTML layout wrapping all pages with navigation and Tailwind CSS.
///
/// ``BaseLayout`` provides the common HTML document structure including:
/// - Tailwind CSS from CDN
/// - HTMX library for dynamic updates
/// - Navigation sidebar
/// - Main content area
/// - Alert notification banner
///
/// All page views compose inside this layout.

import Elementary
import ElementaryHTMX

/// Base HTML document layout for all KUIB pages.
public struct BaseLayout<Content: HTML>: HTMLDocument {
    public var title: String
    var currentPath: String
    @HTMLBuilder var content: Content

    public init(title: String, currentPath: String, @HTMLBuilder content: () -> Content) {
        self.title = "KUIB - \(title)"
        self.currentPath = currentPath
        self.content = content()
    }

    public var head: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1.0"))
        link(.rel(.stylesheet), .href("https://cdn.jsdelivr.net/npm/tailwindcss@3/dist/tailwind.min.css"))
        script(.src("https://unpkg.com/htmx.org@2.0.0")) { "" }
        script(.src("https://unpkg.com/htmx-ext-sse@2.0.0/sse.js")) { "" }
        style {
            """
            .health-healthy { color: #10b981; }
            .health-warning { color: #f59e0b; }
            .health-error { color: #ef4444; }
            .health-unknown { color: #6b7280; }
            .badge { display: inline-flex; align-items: center; padding: 2px 8px; border-radius: 9999px; font-size: 0.75rem; font-weight: 500; }
            .badge-healthy { background-color: #d1fae5; color: #065f46; }
            .badge-warning { background-color: #fef3c7; color: #92400e; }
            .badge-error { background-color: #fee2e2; color: #991b1b; }
            .badge-unknown { background-color: #f3f4f6; color: #374151; }
            .badge-info { background-color: #dbeafe; color: #1e40af; }
            .log-viewer { font-family: 'Menlo', 'Monaco', 'Courier New', monospace; font-size: 0.8rem; line-height: 1.4; background: #1e1e2e; color: #cdd6f4; padding: 1rem; overflow-x: auto; max-height: 600px; overflow-y: auto; }
            .sidebar-link { display: flex; align-items: center; padding: 0.5rem 1rem; border-radius: 0.375rem; color: #d1d5db; text-decoration: none; transition: all 0.15s; }
            .sidebar-link:hover { background-color: #374151; color: white; }
            .sidebar-link.active { background-color: #1f2937; color: white; font-weight: 500; }
            """
        }
    }

    public var body: some HTML {
        div(.class("flex h-screen bg-gray-100")) {
            // Sidebar
            nav(.class("w-64 bg-gray-900 text-white flex-shrink-0 overflow-y-auto")) {
                div(.class("p-4")) {
                    h1(.class("text-xl font-bold text-white mb-1")) { "KUIB" }
                    p(.class("text-xs text-gray-400")) { "Kubernetes UI Board" }
                }

                div(.class("px-3 py-2")) {
                    SidebarSection(title: "Overview") {
                        SidebarLink(path: "/", label: "Dashboard", icon: "grid", currentPath: currentPath)
                        SidebarLink(path: "/namespaces", label: "Namespaces", icon: "layers", currentPath: currentPath)
                    }

                    SidebarSection(title: "Workloads") {
                        SidebarLink(path: "/pods", label: "Pods", icon: "box", currentPath: currentPath)
                        SidebarLink(path: "/deployments", label: "Deployments", icon: "upload", currentPath: currentPath)
                        SidebarLink(path: "/statefulsets", label: "StatefulSets", icon: "database", currentPath: currentPath)
                        SidebarLink(path: "/daemonsets", label: "DaemonSets", icon: "cpu", currentPath: currentPath)
                        SidebarLink(path: "/jobs", label: "Jobs", icon: "play", currentPath: currentPath)
                        SidebarLink(path: "/cronjobs", label: "CronJobs", icon: "clock", currentPath: currentPath)
                    }

                    SidebarSection(title: "Networking") {
                        SidebarLink(path: "/services", label: "Services", icon: "share", currentPath: currentPath)
                        SidebarLink(path: "/ingresses", label: "Ingresses", icon: "globe", currentPath: currentPath)
                    }

                    SidebarSection(title: "Infrastructure") {
                        SidebarLink(path: "/nodes", label: "Nodes", icon: "server", currentPath: currentPath)
                        SidebarLink(path: "/events", label: "Events", icon: "activity", currentPath: currentPath)
                    }

                    SidebarSection(title: "Configuration") {
                        SidebarLink(path: "/configmaps", label: "ConfigMaps", icon: "file", currentPath: currentPath)
                        SidebarLink(path: "/secrets", label: "Secrets", icon: "lock", currentPath: currentPath)
                        SidebarLink(path: "/pvcs", label: "PVCs", icon: "hard-drive", currentPath: currentPath)
                    }

                    SidebarSection(title: "Alerting") {
                        SidebarLink(path: "/alerts", label: "Alerts", icon: "bell", currentPath: currentPath)
                        SidebarLink(path: "/alerts/rules", label: "Alert Rules", icon: "sliders", currentPath: currentPath)
                        SidebarLink(path: "/alerts/webhooks", label: "Webhooks", icon: "send", currentPath: currentPath)
                    }
                }
            }

            // Main content
            div(.class("flex-1 flex flex-col overflow-hidden")) {
                // Top bar with user info
                header(.class("bg-white shadow-sm border-b border-gray-200 px-6 py-3 flex items-center justify-between")) {
                    div(.class("flex items-center space-x-2")) {
                        span(.class("text-sm text-gray-500")) { "Kubernetes Cluster" }
                    }
                    div(.class("flex items-center space-x-4"),
                        .attribute("hx-get", value: "/api/alerts/count"),
                        .attribute("hx-trigger", value: "every 10s"),
                        .attribute("hx-swap", value: "innerHTML")
                    ) {
                        span(.class("text-sm text-gray-500"), .id("alert-count")) { "" }
                    }
                }

                // Scrollable content area
                main(.class("flex-1 overflow-y-auto p-6")) {
                    content
                }
            }
        }
    }
}

// MARK: - Sidebar Components

/// A titled section in the sidebar navigation.
public struct SidebarSection<Inner: HTML>: HTML {
    let title: String
    @HTMLBuilder let inner: Inner

    public init(title: String, @HTMLBuilder content: () -> Inner) {
        self.title = title
        self.inner = content()
    }

    public var body: some HTML {
        div(.class("mb-4")) {
            h3(.class("px-3 text-xs font-semibold text-gray-500 uppercase tracking-wider mb-1")) {
                title
            }
            inner
        }
    }
}

/// A navigation link in the sidebar.
public struct SidebarLink: HTML {
    let path: String
    let label: String
    let icon: String
    let currentPath: String

    public var body: some HTML {
        let isActive = currentPath == path || (path != "/" && currentPath.hasPrefix(path))
        return a(
            .href(path),
            .class("sidebar-link\(isActive ? " active" : "")")
        ) {
            span(.class("mr-3 text-sm")) { iconForName(icon) }
            span { label }
        }
    }

    private func iconForName(_ name: String) -> String {
        switch name {
        case "grid": return "▦"
        case "layers": return "☰"
        case "box": return "□"
        case "upload": return "⬆"
        case "database": return "⛁"
        case "cpu": return "⚙"
        case "play": return "▶"
        case "clock": return "⏰"
        case "share": return "⇆"
        case "globe": return "◎"
        case "server": return "▣"
        case "activity": return "⚡"
        case "file": return "📄"
        case "lock": return "🔒"
        case "hard-drive": return "💾"
        case "bell": return "🔔"
        case "sliders": return "☰"
        case "send": return "➤"
        default: return "•"
        }
    }
}
