# Deployments

## Deployment List

Shows all deployments with:
- **Health** — Green (all replicas ready), Yellow (partially ready), Red (no replicas available)
- **Ready** — Ready/Desired replica count
- **Up-to-date** — Replicas running the latest pod template
- **Available** — Replicas passing readiness checks

## Deployment Detail

### Replica Stats
Four cards: Desired, Ready, Updated, Available.

### Labels
All deployment labels displayed as badges.

### Managed Pods
Lists pods managed by this deployment, with their individual health status. Uses label selector matching to find related pods.

### Events
Deployment-specific events (scaling, rollout progress, etc.).

## Identifying Issues

- **Ready < Desired** — Pods failing to start. Check pod detail for container errors.
- **Available < Desired** — Pods not passing readiness probes. Check probe configuration.
- **Updated = Desired but Ready < Updated** — Rollout in progress or stuck. Check events.
- **Health = Error** — No replicas available. Critical issue requiring investigation.
