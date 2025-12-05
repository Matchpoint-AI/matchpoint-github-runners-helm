# ArgoCD Helm Values
# Managed by Terraform

server:
  # Disable TLS termination (handled by ingress if enabled)
  extraArgs:
    - --insecure

%{ if admin_password_hash != "" }
configs:
  secret:
    argocdServerAdminPassword: "${admin_password_hash}"
%{ endif }

%{ if ingress_enabled }
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
%{ for host in ingress_hosts }
      - ${host}
%{ endfor }
    tls:
      - hosts:
%{ for host in ingress_hosts }
          - ${host}
%{ endfor }
        secretName: argocd-server-tls
%{ endif }

# Controller configuration
controller:
  # Enable status badge
  enableStatefulSet: true

  # Resource limits
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Repo server configuration
repoServer:
  # Environment variable for GitHub token (injected by Terraform)
  env:
    - name: ARGOCD_ENV_GITHUB_TOKEN
      valueFrom:
        secretKeyRef:
          name: github-token
          key: token

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

# Application Set Controller
applicationSet:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

# Redis HA (optional for production)
redis-ha:
  enabled: false

# Dex (authentication)
dex:
  enabled: false

# Notifications (optional)
notifications:
  enabled: false
