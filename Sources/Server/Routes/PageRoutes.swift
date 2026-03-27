/// HTTP routes serving HTML pages via Elementary.
///
/// All page routes read from the ``ResourceCache`` and render Elementary HTML
/// documents. HTMX partial routes are colocated with their full-page counterparts.

import Database
import Elementary
import Hummingbird
import HummingbirdElementary
import K8s
import Models
import Pages

/// Extract a ``ResourceFilter`` from HTTP query parameters.
private func extractFilter(from request: Request) -> ResourceFilter {
    let namespace = request.uri.queryParameters.get("namespace")
    let labelsRaw = request.uri.queryParameters.get("labels")
    let healthRaw = request.uri.queryParameters.get("health")
    let search = request.uri.queryParameters.get("search")

    return ResourceFilter(
        namespace: namespace?.isEmpty == true ? nil : namespace,
        labelSelectors: ResourceFilter.parseLabels(labelsRaw),
        health: healthRaw.flatMap { ResourceHealth(rawValue: $0) },
        nameContains: search?.isEmpty == true ? nil : search
    )
}

/// Register all page routes on the router.
public func registerPageRoutes(
    router: Router<some RequestContext>,
    cache: ResourceCache,
    db: DatabaseManager,
    k8sClient: K8sClientProtocol
) {
    // MARK: - Dashboard

    router.get("/") { _, _ -> HTMLResponse in
        let summary = await cache.clusterSummary()
        let events = await cache.events()
        let unhealthyPods = await cache.pods().filter { $0.health == .error || $0.health == .warning }
        let unhealthyDeployments = await cache.deployments().filter { $0.health != .healthy }

        return HTMLResponse {
            DashboardPage(
                summary: summary,
                recentEvents: Array(events.prefix(20)),
                unhealthyPods: unhealthyPods,
                unhealthyDeployments: unhealthyDeployments
            )
        }
    }

    // MARK: - Pods

    router.get("/pods") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let pods = await cache.pods(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            PodListPage(pods: pods, namespaces: namespaces, filter: filter)
        }
    }

    router.get("/pods/{namespace}/{name}") { _, context -> HTMLResponse in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let pod = await cache.pod(namespace: ns, name: name)

        guard let pod else {
            return HTMLResponse {
                PodListPage(pods: [], namespaces: [])
            }
        }

        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }
        return HTMLResponse {
            PodDetailPage(pod: pod, events: events)
        }
    }

    // MARK: - Deployments

    router.get("/deployments") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let deployments = await cache.deployments(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            DeploymentListPage(deployments: deployments, namespaces: namespaces, filter: filter)
        }
    }

    router.get("/deployments/{namespace}/{name}") { _, context -> HTMLResponse in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let deployment = await cache.deployment(namespace: ns, name: name)

        guard let deployment else {
            return HTMLResponse {
                DeploymentListPage(deployments: [], namespaces: [])
            }
        }

        let pods = await cache.pods(namespace: ns).filter { pod in
            deployment.labels.allSatisfy { pod.labels[$0.key] == $0.value }
        }
        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }

        return HTMLResponse {
            DeploymentDetailPage(deployment: deployment, pods: pods, events: events)
        }
    }

    // MARK: - Jobs

    router.get("/jobs") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let jobs = await cache.jobs(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            JobListPage(jobs: jobs, namespaces: namespaces, filter: filter)
        }
    }

    router.get("/jobs/{namespace}/{name}") { _, context -> HTMLResponse in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let job = await cache.job(namespace: ns, name: name)

        guard let job else {
            return HTMLResponse {
                JobListPage(jobs: [], namespaces: [])
            }
        }

        let pods = await cache.pods(namespace: ns).filter { $0.ownerName == name }
        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }
        let history = (try? await db.queryJobHistory(namespace: ns)) ?? []

        return HTMLResponse {
            JobDetailPage(job: job, pods: pods, events: events, history: history)
        }
    }

    // MARK: - CronJobs

    router.get("/cronjobs") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let cronJobs = await cache.cronJobs(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            CronJobListPage(cronJobs: cronJobs, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - StatefulSets

    router.get("/statefulsets") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let sets = await cache.statefulSets(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            StatefulSetListPage(statefulSets: sets, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - DaemonSets

    router.get("/daemonsets") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let sets = await cache.daemonSets(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            DaemonSetListPage(daemonSets: sets, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - Services

    router.get("/services") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let services = await cache.services(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            ServiceListPage(services: services, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - Ingresses

    router.get("/ingresses") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let ingresses = await cache.ingresses(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            IngressListPage(ingresses: ingresses, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - Nodes

    router.get("/nodes") { _, _ -> HTMLResponse in
        let nodes = await cache.nodes()
        return HTMLResponse {
            NodeListPage(nodes: nodes)
        }
    }

    router.get("/nodes/{name}") { _, context -> HTMLResponse in
        let name = try context.parameters.require("name")
        let nodes = await cache.nodes()
        guard let node = nodes.first(where: { $0.name == name }) else {
            return HTMLResponse {
                NodeListPage(nodes: nodes)
            }
        }

        let pods = await cache.pods().filter { $0.nodeName == name }
        return HTMLResponse {
            NodeDetailPage(node: node, pods: pods)
        }
    }

    // MARK: - Events

    router.get("/events") { request, _ -> HTMLResponse in
        let namespace = request.uri.queryParameters.get("namespace")
        let events = await cache.events(namespace: namespace)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            EventsPage(events: events, namespaces: namespaces, selectedNamespace: namespace)
        }
    }

    // MARK: - Namespaces

    router.get("/namespaces") { _, _ -> HTMLResponse in
        let namespaces = await cache.namespaces()
        return HTMLResponse {
            NamespaceListPage(namespaces: namespaces)
        }
    }

    // MARK: - ConfigMaps

    router.get("/configmaps") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let cms = await cache.configMaps(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            ConfigMapListPage(configMaps: cms, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - Secrets

    router.get("/secrets") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let secrets = await cache.secrets(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            SecretListPage(secrets: secrets, namespaces: namespaces, filter: filter)
        }
    }

    // MARK: - PVCs

    router.get("/pvcs") { request, _ -> HTMLResponse in
        let filter = extractFilter(from: request)
        let pvcs = await cache.pvcs(filter: filter)
        let namespaces = await cache.namespaces()

        return HTMLResponse {
            PVCListPage(pvcs: pvcs, namespaces: namespaces, filter: filter)
        }
    }
}
