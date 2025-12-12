# Custom Runner Images

This directory contains Dockerfiles for custom GitHub Actions runner images with pre-installed tools.

## ARC Runner (`arc-runner`)

Our custom runner image based on `ghcr.io/actions/actions-runner:latest` with additional tools commonly needed by Matchpoint-AI workflows.

### Included Tools

- **Node.js 20 LTS**: JavaScript runtime with npm and yarn
- **Python 3.12**: Python runtime with pip and poetry
- **Terraform 1.9.x**: Infrastructure as Code tool
- **terraform-docs**: Documentation generator for Terraform modules
- **PostgreSQL 16 client**: Database client with pgvector extension support
- **Docker CLI**: Docker client for containerized builds
- **Build tools**: make, build-essential, zip, rsync
- **Linting**: shellcheck

### Building the Image

The image is automatically built and pushed to `ghcr.io/matchpoint-ai/arc-runner:latest` when changes are merged to main.

To build manually:

```bash
cd images/arc-runner
docker build -t ghcr.io/matchpoint-ai/arc-runner:latest .
```

### Testing the Image Locally

```bash
docker run --rm ghcr.io/matchpoint-ai/arc-runner:latest bash -c "
  node --version && \
  npm --version && \
  python3 --version && \
  terraform --version && \
  psql --version && \
  docker --version
"
```

### Using the Custom Image

The custom image is already configured as the default in `charts/github-actions-runners/values.yaml`:

```yaml
template:
  spec:
    containers:
    - name: runner
      image: ghcr.io/matchpoint-ai/arc-runner:latest
```

To revert to the base image:

```yaml
image: ghcr.io/actions/actions-runner:latest
```

### Updating the Image

To update tool versions:

1. Edit `images/arc-runner/Dockerfile`
2. Update version ARGs (e.g., `TERRAFORM_VERSION`, `TERRAFORM_DOCS_VERSION`)
3. Commit and push changes
4. The workflow will automatically build and push the new image
5. Update runner deployments to use the new image

### Version Pinning

For production stability, consider pinning to specific image tags:

```yaml
image: ghcr.io/matchpoint-ai/arc-runner:v1.0.0
```

Available tags:
- `latest`: Latest build from main branch
- `main`: Latest build from main branch
- `sha-<commit>`: Specific commit builds
- `v*.*.*`: Semantic version tags (when created)

### Troubleshooting

**Image pull errors**: Ensure the runner has access to GitHub Container Registry:
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<github-pat>
```

**Tool version conflicts**: Check installed versions:
```bash
kubectl exec -it <runner-pod> -- bash -c "node --version && terraform --version"
```

## Creating Additional Custom Images

If you need a custom runner image with different tools:

1. Create a subdirectory with your image name (e.g., `images/my-runner/`)
2. Add a `Dockerfile` based on `ghcr.io/actions/actions-runner:latest`
3. Update `.github/workflows/build-runner-image.yml` to build your image
4. Update the runner values to use the custom image

## Note

While custom images provide faster CI (no setup time) and consistent environments, they add maintenance burden. Consider using testcontainers or service containers for database/service dependencies when possible.
