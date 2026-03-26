# Alert Rules

## Built-in Rules

KUIB ships with 9 default alert rules that are enabled on startup:

| Rule | Type | Severity | Cooldown | Description |
|------|------|----------|----------|-------------|
| Pod CrashLoopBackOff | `podCrashLoopBackOff` | Critical | 5 min | Container stuck in crash-restart loop |
| Pod OOMKilled | `podOOMKilled` | Critical | 5 min | Container killed due to out-of-memory |
| Pod ImagePullBackOff | `podImagePullBackOff` | Warning | 5 min | Cannot pull container image |
| Pod Failed | `podFailed` | Warning | 5 min | Pod entered Failed state |
| Deployment Replicas Mismatch | `deploymentReplicasMismatch` | Warning | 10 min | Available replicas < desired |
| Job Failed | `jobFailed` | Warning | 5 min | Job has failed executions |
| Node Not Ready | `nodeNotReady` | Critical | 5 min | Node is not in Ready condition |
| Node Memory Pressure | `nodeMemoryPressure` | Warning | 5 min | Node has memory pressure |
| Node Disk Pressure | `nodeDiskPressure` | Warning | 5 min | Node has disk pressure |

## How Rules Are Evaluated

1. The AlertEngine subscribes to ResourceCache update events
2. When a cache event fires (e.g., `podsUpdated`), matching rules are evaluated
3. Each rule checks the current resource state against its condition
4. If the condition matches, a FiredAlert is created
5. Cooldown prevents duplicate alerts for the same resource within the cooldown period
6. The alert is persisted to PostgreSQL and dispatched to webhooks

## Cooldown

Each rule has a `cooldownSeconds` setting (default: 300 seconds / 5 minutes). After an alert fires for a specific resource, it won't fire again for that same resource until the cooldown expires. This prevents alert storms during prolonged issues.

## Namespace Filtering

Rules can optionally filter by namespace. When `namespaceFilter` is set, the rule only evaluates resources in that namespace. When null, it evaluates all namespaces.

## Severity Levels

- **Info** — Informational, no action needed
- **Warning** — Potential issue, investigate soon
- **Critical** — Immediate attention required

## Alert Lifecycle

1. **Fired** — Rule condition matched, alert created
2. **Pending** — Webhook delivery in progress
3. **Delivered** — Webhook successfully sent
4. **Failed** — Webhook delivery failed after retries
5. **Cooldown** — Duplicate suppressed by cooldown
