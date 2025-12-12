# Docker-in-Docker (DinD) Configuration Guide

This guide explains how Docker-in-Docker is configured on ARC (Actions Runner Controller) runners and how to use it effectively with testcontainers and other Docker-based workflows.

## Overview

Docker-in-Docker enables running Docker commands within a containerized GitHub Actions runner. This is essential for:
- Building Docker images in CI/CD pipelines
- Running testcontainers for integration tests
- Using Docker Compose in workflows
- Any workflow that requires Docker daemon access

## Architecture

Our ARC runners use a sidecar pattern where the Docker daemon runs in a separate container alongside the runner:

```
┌─────────────────────────────────────────────┐
│ Kubernetes Pod                              │
│                                             │
│  ┌──────────────┐      ┌────────────────┐  │
│  │   Runner     │◄────►│  Docker Daemon │  │
│  │  Container   │ TCP  │  (DinD)        │  │
│  │              │ 2375 │  Container     │  │
│  └──────────────┘      └────────────────┘  │
│         │                      │            │
│         ▼                      ▼            │
│  ┌──────────────┐      ┌────────────────┐  │
│  │  work/       │      │  /var/lib/     │  │
│  │  (25Gi)      │      │   docker/      │  │
│  │              │      │  (20Gi)        │  │
│  └──────────────┘      └────────────────┘  │
└─────────────────────────────────────────────┘
```

## Configuration

### 1. DinD Sidecar Container

The Docker daemon runs in a privileged sidecar container:

```yaml
- name: dind
  image: docker:24-dind
  command:
  - dockerd
  args:
  - --host=tcp://0.0.0.0:2375      # Listen on all interfaces
  - --storage-driver=overlay2       # Use overlay2 for performance
  env:
  - name: DOCKER_TLS_CERTDIR
    value: ""                       # Disable TLS for localhost
  resources:
    requests:
      cpu: "2"
      memory: 4Gi
    limits:
      cpu: "4"
      memory: 8Gi
  securityContext:
    privileged: true                # Required for Docker daemon
  volumeMounts:
  - name: docker-storage
    mountPath: /var/lib/docker      # Persistent Docker graph storage
  - name: docker-certs
    mountPath: /certs/client
```

### 2. Runner Container Environment

The runner container connects to the DinD sidecar via TCP:

```yaml
- name: runner
  image: ghcr.io/matchpoint-ai/arc-runner:latest
  env:
  - name: DOCKER_HOST
    value: "tcp://localhost:2375"   # Connect to DinD sidecar
  - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER
    value: "false"                  # Don't use job containers
  volumeMounts:
  - name: work
    mountPath: /home/runner/_work
  - name: docker-certs
    mountPath: /certs/client
    readOnly: true
```

### 3. Required Volumes

Three volumes are needed for DinD:

```yaml
volumes:
- name: work
  emptyDir:
    sizeLimit: 25Gi               # Runner workspace
- name: docker-storage
  emptyDir:
    sizeLimit: 20Gi               # Docker images and layers
- name: docker-certs
  emptyDir: {}                    # Certificate sharing (optional)
```

## Security Considerations

### Privileged Containers

The DinD container **requires privileged mode** to run the Docker daemon. This is a security consideration:

**Why privileged is required:**
- Docker daemon needs access to kernel features (cgroups, namespaces)
- Must mount filesystems and manipulate network interfaces
- Requires device access for container isolation

**Mitigation strategies:**
1. **Network isolation**: Runners are in dedicated Kubernetes namespaces
2. **Pod Security Standards**: Apply appropriate PSS policies
3. **Resource limits**: Constrain CPU, memory, and storage
4. **Ephemeral storage**: Use emptyDir volumes that are destroyed after job completion
5. **Runner isolation**: Each workflow run gets a fresh pod

### TLS Disabled

We disable TLS (`DOCKER_TLS_CERTDIR=""`) because:
- Communication is localhost-only (within the same pod)
- Simplifies configuration (no certificate management)
- TLS provides no security benefit for intra-pod communication

**Risk:** If the pod network is compromised, Docker daemon is accessible without authentication.
**Mitigation:** Kubernetes pod network isolation and proper RBAC policies.

## Testcontainers Integration

Testcontainers works automatically with our DinD configuration. The `DOCKER_HOST` environment variable tells testcontainers where to find the Docker daemon.

### Required Environment Variables

For testcontainers to work reliably, set these in your workflow:

```yaml
jobs:
  test:
    runs-on: arc-beta-runners    # Must use ARC runners with DinD
    steps:
      - name: Run tests with testcontainers
        run: pytest tests/
        env:
          # Already configured in runner:
          # DOCKER_HOST: tcp://localhost:2375

          # Optional testcontainers settings:
          TESTCONTAINERS_HOST_OVERRIDE: localhost
          TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE: /var/run/docker.sock
          TESTCONTAINERS_RYUK_DISABLED: "false"  # Enable cleanup
```

### Common Testcontainers Issues

#### Issue: Container startup timeout

**Symptom:** Tests fail with "Container did not start in 60 seconds"

**Cause:** DinD container is pulling large images or has insufficient resources

**Solution:**
1. Increase DinD memory limits in values.yaml
2. Pre-pull common images using image puller DaemonSet
3. Increase testcontainers timeout in test code

```python
# Example: Increase timeout in pytest
container = PostgresContainer("postgres:16")
container.with_command("postgres -c shared_preload_libraries=vector")
container.start(timeout=300)  # 5 minutes instead of default 60s
```

#### Issue: "Cannot connect to Docker daemon"

**Symptom:** Tests fail with connection refused or Docker not found

**Cause:** Workflow is running on `ubuntu-latest` (GitHub-hosted) instead of ARC runners

**Solution:** Update workflow to use ARC runners:

```yaml
jobs:
  test:
    runs-on: arc-beta-runners  # NOT ubuntu-latest
```

#### Issue: Docker storage full

**Symptom:** "No space left on device" during image pulls

**Cause:** Docker storage volume (20Gi) is full from multiple test runs

**Solution:**
1. Increase `docker-storage` volume size in values.yaml
2. Add cleanup step in workflow:

```yaml
- name: Clean up Docker
  if: always()
  run: docker system prune -af --volumes
```

#### Issue: Resource exhaustion

**Symptom:** OOM killed or CPU throttling during tests

**Cause:** Testcontainers running resource-intensive databases (PostgreSQL, etc.)

**Solution:** Increase DinD container resources:

```yaml
# In values.yaml
resources:
  limits:
    cpu: "4"        # Increase from 2
    memory: 8Gi     # Increase from 4Gi
```

## Resource Planning

### Storage Sizing

Plan storage based on your Docker image sizes:

| Image Size | Recommended docker-storage | Notes |
|-----------|---------------------------|-------|
| < 1GB     | 10Gi                      | Small base images (alpine, etc.) |
| 1-3GB     | 20Gi                      | Standard images (postgres, node, etc.) |
| 3-5GB     | 40Gi                      | Large images (ML, multi-stage builds) |
| > 5GB     | 60Gi+                     | Very large images or multi-container tests |

Add 20% overhead for layer caching and temporary files.

### Memory Sizing

DinD memory requirements:

| Workload | CPU Request | CPU Limit | Memory Request | Memory Limit |
|----------|-------------|-----------|----------------|--------------|
| Light (single container) | 500m | 1 | 1Gi | 2Gi |
| Medium (2-3 containers) | 1 | 2 | 2Gi | 4Gi |
| Heavy (4+ containers or DB) | 2 | 4 | 4Gi | 8Gi |
| Very Heavy (parallel tests) | 4 | 6 | 8Gi | 12Gi |

### Example Configurations

#### Frontend (Node.js builds + Docker)

```yaml
# For Next.js/React builds with Docker
dind:
  resources:
    requests:
      cpu: "1"
      memory: 2Gi
    limits:
      cpu: "2"
      memory: 4Gi
volumes:
  - name: docker-storage
    emptyDir:
      sizeLimit: 20Gi
```

#### Backend (Python tests with PostgreSQL testcontainers)

```yaml
# For pytest with pgvector/postgres containers
dind:
  resources:
    requests:
      cpu: "2"
      memory: 4Gi
    limits:
      cpu: "4"
      memory: 8Gi
volumes:
  - name: docker-storage
    emptyDir:
      sizeLimit: 30Gi
```

## Monitoring DinD Health

### Check DinD is Running

```bash
# From within a workflow
docker info
docker version

# Check connectivity
curl -f http://localhost:2375/_ping
```

### Monitor Resource Usage

```bash
# Kubernetes pod metrics
kubectl top pod -n arc-runners

# Docker daemon metrics
docker system df
docker stats
```

### Common Health Checks

Add health checks to your workflow:

```yaml
- name: Verify Docker connectivity
  run: |
    echo "Checking Docker daemon..."
    docker version
    docker info
    echo "Docker daemon is healthy"
```

## Troubleshooting

### Enable Debug Logging

For deeper investigation, enable Docker daemon debug mode:

```yaml
# In DinD container args
args:
  - --host=tcp://0.0.0.0:2375
  - --storage-driver=overlay2
  - --log-level=debug         # Add this
```

### View DinD Logs

```bash
# Get pod name
kubectl get pods -n arc-runners

# View DinD container logs
kubectl logs -n arc-runners <pod-name> -c dind --tail=100
```

### Network Connectivity Test

Test that runner can reach DinD:

```yaml
- name: Test Docker connectivity
  run: |
    # Check TCP connectivity
    nc -zv localhost 2375

    # Test Docker API
    curl -v http://localhost:2375/_ping

    # Run container
    docker run --rm hello-world
```

## Best Practices

1. **Always use ARC runners for Docker workflows**: GitHub-hosted runners don't have DinD
2. **Set appropriate resource limits**: Prevent resource exhaustion on shared infrastructure
3. **Clean up after tests**: Use `docker system prune` in cleanup steps
4. **Pre-pull common images**: Use DaemonSet to cache frequently used images
5. **Monitor storage usage**: Alert when docker-storage volume fills up
6. **Use layer caching wisely**: Balance cache benefits vs storage consumption
7. **Disable TLS for localhost**: No security benefit, adds complexity
8. **Run each job in a fresh pod**: Don't reuse pods across workflow runs

## Migration Guide

### From GitHub-hosted to ARC with DinD

If migrating from `ubuntu-latest` to ARC runners:

**Before:**
```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
    steps:
      - run: pytest tests/
```

**After:**
```yaml
jobs:
  test:
    runs-on: arc-beta-runners    # Change 1: Use ARC runners
    # Remove services section    # Change 2: Use testcontainers instead
    steps:
      - run: pytest tests/        # Testcontainers handles DB
        env:
          DOCKER_HOST: tcp://localhost:2375  # Already set in runner
```

## Related Issues

- **Issue #125**: Docker-in-Docker connectivity investigation
- **Issue #68**: Testcontainers resource requirements
- **Issue #101**: Cold start optimization with min runners

## References

- [Docker-in-Docker official image](https://hub.docker.com/_/docker)
- [ARC Documentation](https://github.com/actions/actions-runner-controller)
- [Testcontainers Documentation](https://testcontainers.com/)
- [Kubernetes Security Context](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
