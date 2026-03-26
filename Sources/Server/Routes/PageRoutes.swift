/// HTTP routes serving HTML pages via Elementary.
///
/// All page routes read from the ``ResourceCache`` and render Elementary HTML
/// documents. HTMX partial routes are colocated with their full-page counterparts.

import Database
import Hummingbird
import HummingbirdElementary
import K8s
import Models
import Pages

/// Register all page routes on the router.
public func registerPageRoutes(
    router: Router<some RequestContext>,
    cache: ResourceCache,
    db: DatabaseManager,
    k8sClient: K8sClientProtocol
) {
    // MARK: - Dashboard

    router.get("/") { _, _ -> HTML in
        let summary = await cache.clusterSummary()
        let events = await cache.events()
        let unhealthyPods = await cache.pods().filter { $0.health == .error || $0.health == .warning }
        let unhealthyDeployments = await cache.deployments().filter { $0.health != .healthy }

        return .init(DashboardPage(
            summary: summary,
            recentEvents: Array(events.prefix(20)),
            unhealthyPods: unhealthyPods,
            unhealthyDeployments: unhealthyDeployments
        ))
    }

    // MARK: - Pods

    router.get("/pods") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let pods = await cache.pods(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(PodListPage(pods: pods, namespaces: namespaces, selectedNamespace: namespace))
    }

    router.get("/pods/{namespace}/{name}") { _, context -> HTML in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let pod = await cache.pod(namespace: ns, name: name)

        guard let pod else {
            return .init(PodListPage(pods: [], namespaces: []))
        }

        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }
        return .init(PodDetailPage(pod: pod, events: events))
    }

    // MARK: - Deployments

    router.get("/deployments") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let deployments = await cache.deployments(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(DeploymentListPage(deployments: deployments, namespaces: namespaces, selectedNamespace: namespace))
    }

    router.get("/deployments/{namespace}/{name}") { _, context -> HTML in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let deployment = await cache.deployment(namespace: ns, name: name)

        guard let deployment else {
            return .init(DeploymentListPage(deployments: [], namespaces: []))
        }

        let pods = await cache.pods(namespace: ns).filter { pod in
            deployment.labels.allSatisfy { pod.labels[$0.key] == $0.value }
        }
        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }

        return .init(DeploymentDetailPage(deployment: deployment, pods: pods, events: events))
    }

    // MARK: - Jobs

    router.get("/jobs") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let jobs = await cache.jobs(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(JobListPage(jobs: jobs, namespaces: namespaces, selectedNamespace: namespace))
    }

    router.get("/jobs/{namespace}/{name}") { _, context -> HTML in
        let ns = try context.parameters.require("namespace")
        let name = try context.parameters.require("name")
        let job = await cache.job(namespace: ns, name: name)

        guard let job else {
            return .init(JobListPage(jobs: [], namespaces: []))
        }

        let pods = await cache.pods(namespace: ns).filter { $0.ownerName == name }
        let events = await cache.events(namespace: ns).filter { $0.involvedObjectName == name }
        let history = (try? await db.queryJobHistory(namespace: ns)) ?? []

        return .init(JobDetailPage(job: job, pods: pods, events: events, history: history))
    }

    // MARK: - CronJobs

    router.get("/cronjobs") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let cronJobs = await cache.cronJobs(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(CronJobListPage(cronJobs: cronJobs, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - StatefulSets

    router.get("/statefulsets") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let sets = await cache.statefulSets(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(StatefulSetListPage(statefulSets: sets, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - DaemonSets

    router.get("/daemonsets") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let sets = await cache.daemonSets(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(DaemonSetListPage(daemonSets: sets, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - Services

    router.get("/services") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let services = await cache.services(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(ServiceListPage(services: services, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - Ingresses

    router.get("/ingresses") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let ingresses = await cache.ingresses(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(IngressListPage(ingresses: ingresses, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - Nodes

    router.get("/nodes") { _, _ -> HTML in
        let nodes = await cache.nodes()
        return .init(NodeListPage(nodes: nodes))
    }

    router.get("/nodes/{name}") { _, context -> HTML in
        let name = try context.parameters.require("name")
        let nodes = await cache.nodes()
        guard let node = nodes.first(where: { $0.name == name }) else {
            return .init(NodeListPage(nodes: nodes))
        }

        let pods = await cache.pods().filter { $0.nodeName == name }
        return .init(NodeDetailPage(node: node, pods: pods))
    }

    // MARK: - Events

    router.get("/events") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let events = await cache.events(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(EventsPage(events: events, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - Namespaces

    router.get("/namespaces") { _, _ -> HTML in
        let namespaces = await cache.namespaces()
        return .init(NamespaceListPage(namespaces: namespaces))
    }

    // MARK: - ConfigMaps

    router.get("/configmaps") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let cms = await cache.configMaps(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(ConfigMapListPage(configMaps: cms, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - Secrets

    router.get("/secrets") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let secrets = await cache.secrets(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(SecretListPage(secrets: secrets, namespaces: namespaces, selectedNamespace: namespace))
    }

    // MARK: - PVCs

    router.get("/pvcs") { request, _ -> HTML in
        let namespace = request.uri.queryParameters.get("namespace")
        let pvcs = await cache.pvcs(namespace: namespace)
        let namespaces = await cache.namespaces()

        return .init(PVCListPage(pvcs: pvcs, namespaces: namespaces, selectedNamespace: namespace))
    }
}
