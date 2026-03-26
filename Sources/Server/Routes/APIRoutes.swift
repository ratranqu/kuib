/// JSON API routes for HTMX interactions and data endpoints.

import Alerts
import Database
import Hummingbird
import K8s
import Models

/// Register JSON API routes.
public func registerAPIRoutes(
    router: Router<some RequestContext>,
    cache: ResourceCache,
    db: DatabaseManager,
    k8sClient: K8sClientProtocol,
    alertEngine: AlertEngine
) {
    let api = router.group("api")

    // MARK: - Pod Logs

    api.get("pods/{namespace}/{name}/logs") { request, context -> Response in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let container = request.uri.queryParameters.get("container")
        let tailLines = request.uri.queryParameters.get("tailLines").flatMap { Int($0) } ?? 100

        do {
            let logs = try await k8sClient.getPodLogs(
                namespace: ns, name: name, container: container, tailLines: tailLines
            )
            // Return as preformatted text for the log viewer
            let escaped = logs
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            return Response(
                status: .ok,
                headers: [.contentType: "text/html"],
                body: .init(byteBuffer: .init(string: "<pre>\(escaped)</pre>"))
            )
        } catch {
            return Response(
                status: .internalServerError,
                headers: [.contentType: "text/html"],
                body: .init(byteBuffer: .init(string: "<p class=\"text-red-500\">Error loading logs: \(error)</p>"))
            )
        }
    }

    // MARK: - Pod Actions

    api.post("pods/{namespace}/{name}/delete") { _, context -> Response in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")

        do {
            try await k8sClient.deletePod(namespace: ns, name: name)
            return Response(
                status: .ok,
                headers: [.contentType: "text/html", "HX-Redirect": "/pods"],
                body: .init(byteBuffer: .init(string: "Pod deleted"))
            )
        } catch {
            return Response(
                status: .internalServerError,
                body: .init(byteBuffer: .init(string: "Error: \(error)"))
            )
        }
    }

    // MARK: - Deployment Actions

    api.post("deployments/{namespace}/{name}/scale") { request, context -> Response in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")

        guard let replicasStr = request.uri.queryParameters.get("replicas"),
              let replicas = Int32(replicasStr) else {
            return Response(status: .badRequest, body: .init(byteBuffer: .init(string: "Missing replicas parameter")))
        }

        do {
            try await k8sClient.scaleDeployment(namespace: ns, name: name, replicas: replicas)
            return Response(
                status: .ok,
                headers: [.contentType: "text/html"],
                body: .init(byteBuffer: .init(string: "Scaled to \(replicas) replicas"))
            )
        } catch {
            return Response(
                status: .internalServerError,
                body: .init(byteBuffer: .init(string: "Error: \(error)"))
            )
        }
    }

    // MARK: - Alert Count (for top bar)

    api.get("alerts/count") { _, _ -> Response in
        let alerts = (try? await db.queryAlerts(limit: 100)) ?? []
        let recentCount = alerts.filter { alert in
            alert.firedAt.timeIntervalSinceNow > -3600 // last hour
        }.count

        let html: String
        if recentCount > 0 {
            html = "<span class=\"badge badge-error\">\(recentCount) alerts</span>"
        } else {
            html = "<span class=\"text-sm text-green-600\">No active alerts</span>"
        }

        return Response(
            status: .ok,
            headers: [.contentType: "text/html"],
            body: .init(byteBuffer: .init(string: html))
        )
    }

    // MARK: - Alert History API

    api.get("alerts") { request, _ -> Response in
        let namespace = request.uri.queryParameters.get("namespace")
        let severityStr = request.uri.queryParameters.get("severity")
        let severity = severityStr.flatMap { AlertSeverity(rawValue: $0) }

        let alerts = (try? await db.queryAlerts(severity: severity, namespace: namespace)) ?? []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(alerts)

        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(data: data))
        )
    }

    // MARK: - Health Check

    api.get("health") { _, _ -> Response in
        Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(string: "{\"status\":\"ok\"}"))
        )
    }

    api.get("ready") { _, _ -> Response in
        Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(string: "{\"ready\":true}"))
        )
    }

    // MARK: - Historical Logs

    api.get("pods/{namespace}/{name}/logs/history") { _, context -> Response in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")

        let logs = (try? await db.getPodLogs(namespace: ns, podName: name)) ?? []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        struct LogEntry: Codable {
            let container: String
            let capturedAt: Date
            let preview: String
        }

        let entries = logs.map { log in
            LogEntry(
                container: log.container,
                capturedAt: log.capturedAt,
                preview: String(log.log.prefix(200))
            )
        }

        let data = try encoder.encode(entries)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(data: data))
        )
    }

    // MARK: - Job History

    api.get("jobs/history") { request, _ -> Response in
        let namespace = request.uri.queryParameters.get("namespace")
        let cronJob = request.uri.queryParameters.get("cronJob")

        let history = (try? await db.queryJobHistory(namespace: namespace, cronJobName: cronJob)) ?? []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)

        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(data: data))
        )
    }
}
