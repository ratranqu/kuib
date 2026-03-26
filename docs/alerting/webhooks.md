# Webhook Configuration

## Payload Format

Webhooks receive a JSON POST with the following structure:

```json
{
  "id": "abc-123-def",
  "ruleName": "Pod CrashLoopBackOff",
  "severity": "critical",
  "resourceKind": "Pod",
  "resourceName": "web-abc123",
  "namespace": "default",
  "message": "Pod web-abc123 has container in CrashLoopBackOff state",
  "firedAt": "2024-01-15T10:30:00Z"
}
```

## Endpoint Configuration

Each webhook endpoint supports:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | String | required | Human-readable name |
| `url` | String | required | HTTPS endpoint URL |
| `headers` | Object | `{}` | Custom HTTP headers |
| `enabled` | Bool | `true` | Whether to send to this endpoint |
| `retryCount` | Int | `3` | Max delivery attempts |
| `timeoutSeconds` | Int | `10` | Per-request timeout |

## Retry Behavior

Failed deliveries are retried with exponential backoff:
- Attempt 1: Immediate
- Attempt 2: After 1 second
- Attempt 3: After 2 seconds
- (Additional retries continue doubling)

A delivery is considered failed if:
- The HTTP response status is not 2xx
- The request times out
- A network error occurs

## Integration Examples

### Slack

```json
{
  "name": "Slack #alerts",
  "url": "https://hooks.slack.com/services/T00/B00/xxx",
  "headers": {},
  "enabled": true
}
```

Note: Slack expects a specific payload format. You may need a webhook relay service to transform the KUIB payload.

### Discord

```json
{
  "name": "Discord alerts",
  "url": "https://discord.com/api/webhooks/xxx/yyy",
  "headers": {
    "Content-Type": "application/json"
  },
  "enabled": true
}
```

### PagerDuty

```json
{
  "name": "PagerDuty",
  "url": "https://events.pagerduty.com/v2/enqueue",
  "headers": {
    "Content-Type": "application/json"
  },
  "enabled": true
}
```

### Generic HTTP

Any endpoint that accepts a JSON POST:
```json
{
  "name": "Custom webhook",
  "url": "https://your-api.example.com/webhooks/kuib",
  "headers": {
    "Authorization": "Bearer your-token",
    "X-Custom-Header": "value"
  },
  "enabled": true,
  "retryCount": 5,
  "timeoutSeconds": 15
}
```

## Request Headers

Every webhook request includes:
- `Content-Type: application/json`
- `User-Agent: KUIB/1.0`
- Any custom headers configured on the endpoint
