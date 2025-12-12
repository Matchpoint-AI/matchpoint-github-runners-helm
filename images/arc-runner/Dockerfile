# Custom GitHub Actions Runner with Project-Beta Tools
# Based on official GitHub Actions runner image
FROM ghcr.io/actions/actions-runner:latest

# Install base dependencies
USER root

# Update package lists and install essential build tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    unzip \
    jq \
    shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.12 (using ensurepip to avoid distutils dependency removed in 3.12)
RUN add-apt-repository ppa:deadsnakes/ppa -y \
    && apt-get update \
    && apt-get install -y \
        python3.12 \
        python3.12-dev \
        python3.12-venv \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && python3.12 -m ensurepip --upgrade \
    && python3.12 -m pip install --upgrade pip setuptools wheel \
    && python3.12 -m pip install poetry \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL 16 client and pgvector
RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y \
        postgresql-client-16 \
        postgresql-16-pgvector \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
ARG TERRAFORM_VERSION=1.9.8
RUN wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && terraform --version

# Install terraform-docs
ARG TERRAFORM_DOCS_VERSION=0.19.0
RUN wget -q https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz \
    && tar -xzf terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz \
    && mv terraform-docs /usr/local/bin/ \
    && rm terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz \
    && terraform-docs --version

# Install Docker CLI (for Docker-in-Docker scenarios)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install additional tools commonly used in CI
RUN apt-get update && apt-get install -y \
    make \
    build-essential \
    zip \
    rsync \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Switch back to runner user
USER runner

# Verify installations
RUN node --version && \
    npm --version && \
    python3 --version && \
    pip --version && \
    poetry --version && \
    terraform --version && \
    terraform-docs --version && \
    psql --version && \
    docker --version && \
    shellcheck --version

# Set environment variables for optimal CI performance
ENV NODE_OPTIONS="--max-old-space-size=4096"
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV TERRAFORM_PLUGIN_CACHE_DIR=/home/runner/.terraform.d/plugin-cache

# Create terraform plugin cache directory
RUN mkdir -p /home/runner/.terraform.d/plugin-cache

# Labels
LABEL org.opencontainers.image.source="https://github.com/Matchpoint-AI/matchpoint-github-runners-helm"
LABEL org.opencontainers.image.description="Custom GitHub Actions Runner with Node.js, Terraform, PostgreSQL, and pgvector"
LABEL org.opencontainers.image.vendor="Matchpoint AI"
LABEL maintainer="Matchpoint AI <engineering@matchpoint.ai>"
