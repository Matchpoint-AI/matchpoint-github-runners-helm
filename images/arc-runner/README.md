# ARC Runner Custom Image

Custom GitHub Actions Runner image with pre-installed tools for Matchpoint-AI workflows.

## Base Image

Built on top of `ghcr.io/actions/actions-runner:latest` (official GitHub Actions Runner).

## Installed Tools & Versions

### Runtime Environments
- **Node.js**: 20.x LTS
- **Python**: 3.12 with pip, setuptools, wheel

### Package Managers
- **npm**: Latest
- **yarn**: Latest
- **pip**: Latest
- **poetry**: Latest (Python)

### Infrastructure & DevOps
- **Terraform**: 1.9.8
- **terraform-docs**: 0.19.0
- **Docker CLI**: Latest (client only, for DinD scenarios)

### Database Tools
- **PostgreSQL Client**: 16
- **pgvector**: PostgreSQL 16 extension

### Build & Utility Tools
- **make**: System build tool
- **build-essential**: GCC, g++, and build dependencies
- **git**: Version control
- **jq**: JSON processor
- **shellcheck**: Shell script linter
- **zip/unzip**: Archive utilities
- **rsync**: File synchronization
- **openssh-client**: SSH client

## Environment Variables

Pre-configured for optimal CI performance:

```bash
NODE_OPTIONS="--max-old-space-size=4096"
PYTHONUNBUFFERED=1
PIP_NO_CACHE_DIR=1
TERRAFORM_PLUGIN_CACHE_DIR=/home/runner/.terraform.d/plugin-cache
```

## Build Arguments

Customize versions at build time:

```bash
docker build \
  --build-arg TERRAFORM_VERSION=1.10.0 \
  --build-arg TERRAFORM_DOCS_VERSION=0.19.0 \
  -t ghcr.io/matchpoint-ai/arc-runner:latest .
```

## Image Size

Approximate size: ~2.5GB compressed

## Testing

Verify all tools are installed:

```bash
docker run --rm ghcr.io/matchpoint-ai/arc-runner:latest bash -c "
  echo 'Node.js:' && node --version
  echo 'npm:' && npm --version
  echo 'Python:' && python3 --version
  echo 'pip:' && pip --version
  echo 'Poetry:' && poetry --version
  echo 'Terraform:' && terraform --version
  echo 'terraform-docs:' && terraform-docs --version
  echo 'PostgreSQL:' && psql --version
  echo 'Docker:' && docker --version
  echo 'shellcheck:' && shellcheck --version
"
```

## Security

- Runs as `runner` user (non-root)
- No secrets or credentials baked into the image
- Based on official GitHub Actions runner image security practices

## Maintenance

### Updating Tool Versions

1. Edit `Dockerfile` ARG values
2. Test build locally
3. Commit and push - CI will build and publish automatically

### Security Updates

Rebuild periodically to get base image security updates:

```bash
docker build --no-cache -t ghcr.io/matchpoint-ai/arc-runner:latest .
```

## Known Issues

- **Python 3.12 on Ubuntu**: Requires deadsnakes PPA
- **pgvector**: Installed as PostgreSQL extension, requires PostgreSQL 16 client

## Related Issues

- Issue #41: Initial implementation
- Resolves tool availability issues from PRs #1519, #566, #677
