/// Main application entry point.
///
/// Initializes all services (K8s client, database, cache, watchers, alert engine)
/// and starts the Hummingbird HTTP server with all routes configured.

import Alerts
import ArgumentParser
import Database
import Hummingbird
import K8s
import Logging
import Models
import Server

@main
struct KuibApp: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kuib",
        abstract: "Kubernetes UI Board - Monitor and debug your Kubernetes workloads"
    )

    @Option(name: .long, help: "Server host address")
    var host: String?

    @Option(name: .long, help: "Server port")
    var port: Int?

    @Option(name: .long, help: "Log level")
    var logLevel: String?

    func run() async throws {
        // Load configuration
        let config = AppConfig.fromEnvironment()
        let serverHost = host ?? config.server.host
        let serverPort = port ?? config.server.port

        // Configure logging
        var logger = Logger(label: "kuib")
        logger.logLevel = Logger.Level(rawValue: logLevel ?? config.logLevel) ?? .info
        logger.info("Starting KUIB - Kubernetes UI Board")

        // Initialize Kubernetes client
        let k8sClient: K8sClientProtocol
        do {
            k8sClient = try SwiftkubeK8sClient(logger: Logger(label: "kuib.k8s"))
            logger.info("Kubernetes client initialized")
        } catch {
            logger.error("Failed to initialize Kubernetes client: \(error)")
            logger.info("Continuing without K8s connection (pages will show empty data)")
            k8sClient = FallbackK8sClient()
        }

        // Initialize database
        let db = DatabaseManager(config: config.database, logger: Logger(label: "kuib.db"))
        do {
            try await db.initialize()
            logger.info("Database initialized")
        } catch {
            logger.error("Failed to initialize database: \(error)")
            logger.info("Continuing without database (historical data will not be available)")
        }

        // Initialize cache and watchers
        let cache = ResourceCache()
        let watcher = ResourceWatcher(
            client: k8sClient,
            cache: cache,
            logger: Logger(label: "kuib.watcher")
        )

        // Initialize alert system
        let dispatcher = WebhookDispatcher(db: db, logger: Logger(label: "kuib.webhooks"))
        let alertEngine = AlertEngine(
            cache: cache,
            db: db,
            dispatcher: dispatcher,
            logger: Logger(label: "kuib.alerts")
        )
        await alertEngine.loadDefaultRules()

        // Build Hummingbird application
        let router = Router()

        // Register routes
        registerPageRoutes(router: router, cache: cache, db: db, k8sClient: k8sClient)
        registerAPIRoutes(router: router, cache: cache, db: db, k8sClient: k8sClient, alertEngine: alertEngine)

        let app = Application(
            router: router,
            configuration: .init(
                address: .hostname(serverHost, port: serverPort)
            ),
            logger: logger
        )

        // Start background services
        await watcher.start()
        await alertEngine.start()

        logger.info("KUIB server starting on \(serverHost):\(serverPort)")

        // Run the server (blocks until shutdown)
        try await app.run()

        // Cleanup on shutdown
        await watcher.stop()
        await alertEngine.stop()
        try await db.shutdown()
        if let swiftkubeClient = k8sClient as? SwiftkubeK8sClient {
            try await swiftkubeClient.shutdown()
        }

        logger.info("KUIB server shut down")
    }
}

/// Fallback client that returns empty results when K8s is not available.
struct FallbackK8sClient: K8sClientProtocol {
    func listPods(namespace: NamespaceSelector) async throws -> [PodInfo] { [] }
    func getPod(namespace: String, name: String) async throws -> PodInfo? { nil }
    func getPodLogs(namespace: String, name: String, container: String?, tailLines: Int?) async throws -> String { "No Kubernetes connection available" }
    func deletePod(namespace: String, name: String) async throws {}
    func listDeployments(namespace: NamespaceSelector) async throws -> [DeploymentInfo] { [] }
    func getDeployment(namespace: String, name: String) async throws -> DeploymentInfo? { nil }
    func scaleDeployment(namespace: String, name: String, replicas: Int32) async throws {}
    func listJobs(namespace: NamespaceSelector) async throws -> [JobInfo] { [] }
    func getJob(namespace: String, name: String) async throws -> JobInfo? { nil }
    func deleteJob(namespace: String, name: String) async throws {}
    func listCronJobs(namespace: NamespaceSelector) async throws -> [CronJobInfo] { [] }
    func listStatefulSets(namespace: NamespaceSelector) async throws -> [StatefulSetInfo] { [] }
    func listDaemonSets(namespace: NamespaceSelector) async throws -> [DaemonSetInfo] { [] }
    func listServices(namespace: NamespaceSelector) async throws -> [ServiceInfo] { [] }
    func listIngresses(namespace: NamespaceSelector) async throws -> [IngressInfo] { [] }
    func listNodes() async throws -> [NodeInfo] { [] }
    func listEvents(namespace: NamespaceSelector) async throws -> [EventInfo] { [] }
    func listNamespaces() async throws -> [NamespaceInfo] { [] }
    func listConfigMaps(namespace: NamespaceSelector) async throws -> [ConfigMapInfo] { [] }
    func listSecrets(namespace: NamespaceSelector) async throws -> [SecretInfo] { [] }
    func listPVCs(namespace: NamespaceSelector) async throws -> [PVCInfo] { [] }
}
