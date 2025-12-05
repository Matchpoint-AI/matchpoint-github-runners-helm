# Custom Runner Images

This directory contains Dockerfiles for custom GitHub Actions runner images.

## API Runner (`api-runner`)

Custom runner image for the `project-beta-api` repository.

**Features:**
- Based on `ghcr.io/actions/actions-runner:latest`
- PostgreSQL 14 with pgvector extension pre-installed
- Python 3 with pip and venv support

**Purpose:**
The API tests use pytest-postgresql which requires PostgreSQL binaries and extensions
to be available on the runner. The pgvector extension is needed for the BrandEmbedding
model which uses vector similarity search.

**Building locally:**
```bash
cd images/api-runner
docker build -t api-runner:test .
```

**CI/CD:**
Images are automatically built and pushed to `ghcr.io/matchpoint-ai/api-runner` when
changes are pushed to the `main` branch.
