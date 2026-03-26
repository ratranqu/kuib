/// Middleware that reads the user identity from oauth2-proxy headers.
///
/// When the application runs behind oauth2-proxy, the proxy sets
/// `X-Forwarded-User` and `X-Forwarded-Email` headers after successful
/// authentication. This middleware extracts those for logging and display.

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
        let user = request.headers[.init("X-Forwarded-User")!]
        let email = request.headers[.init("X-Forwarded-Email")!]

        if let user {
            context.logger.info("Request from user: \(user) (\(email ?? "no email"))")
        }

        return try await next(request, context)
    }
}
