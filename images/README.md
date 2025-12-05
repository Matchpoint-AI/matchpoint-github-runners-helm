# Custom Runner Images

This directory can contain Dockerfiles for custom GitHub Actions runner images.

## Creating a Custom Image

If you need a custom runner image with specific tools:

1. Create a subdirectory with your image name (e.g., `images/my-runner/`)
2. Add a `Dockerfile` based on `ghcr.io/actions/actions-runner:latest`
3. Create a GitHub workflow to build and push the image
4. Update the runner values to use the custom image

## Note

Most use cases are better served by using testcontainers or service containers
in your CI workflow rather than custom runner images. Custom images add maintenance
burden and can become outdated.
