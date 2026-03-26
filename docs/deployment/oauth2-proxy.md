# OAuth2 Proxy Setup

KUIB delegates authentication to [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/), which runs as a sidecar or standalone deployment in front of the KUIB service.

## How It Works

1. User requests KUIB URL
2. Ingress routes to oauth2-proxy's auth endpoint
3. oauth2-proxy redirects to identity provider (GitHub, Google, etc.)
4. After authentication, oauth2-proxy sets `X-Forwarded-User` and `X-Forwarded-Email` headers
5. KUIB reads these headers for audit logging

## Example: GitHub OAuth

### 1. Create a GitHub OAuth App

Go to GitHub Settings > Developer settings > OAuth Apps > New OAuth App:
- **Homepage URL**: `https://kuib.your-domain.com`
- **Authorization callback URL**: `https://kuib.your-domain.com/oauth2/callback`

### 2. Deploy oauth2-proxy

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: kuib
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
        - name: oauth2-proxy
          image: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0
          args:
            - --provider=github
            - --email-domain=*
            - --upstream=http://kuib.kuib.svc.cluster.local:80
            - --http-address=0.0.0.0:4180
            - --cookie-secret=$(generate-cookie-secret)
            - --cookie-secure=true
            - --set-xauthrequest=true
            - --pass-user-headers=true
          env:
            - name: OAUTH2_PROXY_CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: oauth2-proxy-secrets
                  key: client-id
            - name: OAUTH2_PROXY_CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: oauth2-proxy-secrets
                  key: client-secret
          ports:
            - containerPort: 4180
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: kuib
spec:
  selector:
    app: oauth2-proxy
  ports:
    - port: 4180
      targetPort: 4180
```

### 3. Update Ingress

The KUIB ingress annotations in `Kubernetes/service.yaml` are already configured to use oauth2-proxy:

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
  nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
```

## Other Providers

oauth2-proxy supports many identity providers:
- Google
- Azure AD
- Keycloak
- GitLab
- OIDC (generic)

See the [oauth2-proxy documentation](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/) for provider-specific configuration.

## Disabling Authentication

For development or internal networks, you can skip oauth2-proxy and access KUIB directly. Remove the `auth-url` and `auth-signin` annotations from the Ingress, or use `kubectl port-forward`.
