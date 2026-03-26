/// Middleware that reads the user identity from oauth2-proxy headers.
///
/// When the application runs behind oauth2-proxy, the proxy sets
/// `X-Forwarded-User` and `X-Forwarded-Email` headers after successful
/// authentication. This middleware extracts those for logging and display.

import HTTPTypes
import Hummingbird
import Logging

/// Extracts user identity from oauth2-proxy forwarded headers.
public struct AuthMiddleware<Context: RequestContext>: RouterMiddleware {
    private let logger: Logger

    public init(logger: Logger = Logger(label: "kuib.auth")) {
        self.logger = logger
    }

    public func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        let user: String? = HTTPField.Name("X-Forwarded-User").flatMap { request.headers[$0] }
        let email: String? = HTTPField.Name("X-Forwarded-Email").flatMap { request.headers[$0] }

        if let user {
            context.logger.info("Request from user: \(user) (\(email ?? "no email"))")
        }

        return try await next(request, context)
    }
}
