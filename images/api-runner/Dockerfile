# Custom API Runner image with PostgreSQL 14 and pgvector
# Used for project-beta-api tests that require vector operations
FROM ghcr.io/actions/actions-runner:latest

USER root

# Add PostgreSQL APT repository
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# Install PostgreSQL 14, pgvector, and Python
RUN apt-get update && apt-get install -y \
    postgresql-14 \
    postgresql-14-pgvector \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Set PostgreSQL paths for pytest-postgresql
ENV PATH="/usr/lib/postgresql/14/bin:${PATH}"
ENV PGDATA="/var/lib/postgresql/14/main"

# Switch back to runner user
USER runner

# Add runner to postgres group if needed
# RUN sudo usermod -a -G postgres runner
