/// Webhook dispatcher for sending alert notifications to external endpoints.
///
/// The ``WebhookDispatcher`` sends HTTP POST requests to configured webhook
/// endpoints when alerts fire. It supports:
/// - Configurable retry with exponential backoff
/// - Timeout per request
/// - Custom headers per endpoint
/// - JSON payload format compatible with Slack, Discord, PagerDuty, etc.

import Database
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Hummingbird
import Logging
import Models

/// Dispatches alert notifications to webhook endpoints.
public actor WebhookDispatcher {
    private var endpoints: [WebhookEndpoint] = []
    private let db: DatabaseManager
    private let logger: Logger

    public init(db: DatabaseManager, logger: Logger = Logger(label: "kuib.webhooks")) {
        self.db = db
        self.logger = logger
    }

    /// Update the list of configured endpoints.
    public func setEndpoints(_ endpoints: [WebhookEndpoint]) {
        self.endpoints = endpoints
    }

    /// Get configured endpoints.
    public func getEndpoints() -> [WebhookEndpoint] {
        endpoints
    }

    /// Dispatch an alert to all configured and enabled endpoints.
    public func dispatch(alert: FiredAlert) async {
        let activeEndpoints = endpoints.filter { $0.enabled }

        guard !activeEndpoints.isEmpty else {
            logger.debug("No active webhook endpoints configured, skipping dispatch")
            return
        }

        let payload = WebhookPayload(
            id: alert.id,
            ruleName: alert.ruleName,
            severity: alert.severity.rawValue,
            resourceKind: alert.resourceKind,
            resourceName: alert.resourceName,
            namespace: alert.namespace,
            message: alert.message,
            firedAt: ISO8601DateFormatter().string(from: alert.firedAt)
        )

        for endpoint in activeEndpoints {
            await sendToEndpoint(endpoint, payload: payload, alertId: alert.id)
        }
    }

    private func sendToEndpoint(_ endpoint: WebhookEndpoint, payload: WebhookPayload, alertId: String) async {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let body = try? encoder.encode(payload) else {
            logger.error("Failed to encode webhook payload for alert \(alertId)")
            return
        }

        var lastError: Error?

        for attempt in 0..<endpoint.retryCount {
            do {
                guard let url = URL(string: endpoint.url) else {
                    logger.error("Invalid webhook URL: \(endpoint.url)")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("KUIB/1.0", forHTTPHeaderField: "User-Agent")
                request.timeoutInterval = TimeInterval(endpoint.timeoutSeconds)

                for (key, value) in endpoint.headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                request.httpBody = body

                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    logger.info("Webhook delivered to \(endpoint.name) for alert \(alertId)")
                    try? await db.updateAlertDelivery(id: alertId, status: .delivered, deliveredAt: Date())
                    return
                } else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    lastError = WebhookError.httpError(statusCode)
                    logger.warning("Webhook to \(endpoint.name) returned \(statusCode), attempt \(attempt + 1)/\(endpoint.retryCount)")
                }
            } catch {
                lastError = error
                logger.warning("Webhook to \(endpoint.name) failed: \(error), attempt \(attempt + 1)/\(endpoint.retryCount)")
            }

            // Exponential backoff
            if attempt < endpoint.retryCount - 1 {
                let delay = pow(2.0, Double(attempt))
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        logger.error("Webhook delivery to \(endpoint.name) failed after \(endpoint.retryCount) attempts: \(String(describing: lastError))")
        try? await db.updateAlertDelivery(id: alertId, status: .failed, deliveredAt: nil)
    }
}

/// JSON payload sent to webhook endpoints.
struct WebhookPayload: Codable, Sendable {
    let id: String
    let ruleName: String
    let severity: String
    let resourceKind: String
    let resourceName: String
    let namespace: String
    let message: String
    let firedAt: String
}

/// Webhook dispatch errors.
enum WebhookError: Error {
    case httpError(Int)
    case invalidURL
}
