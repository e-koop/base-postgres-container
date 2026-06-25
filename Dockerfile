# Use official Ubuntu image as the base
# 22.04 is the LTS (Long Term Support) version
FROM ubuntu:22.04

# Set metadata labels for documentation
LABEL description="Base Ubuntu container with essential tools and postgresql installed"

# Build arguments from docker-compose
ARG POSTGRES_VERSION
ARG PGDATA
ARG POSTGRES_PORT
ARG CLUSTER_NAME
ARG DEBIAN_FRONTEND=noninteractive

# Convert ARG to ENV so it's available at runtime
ENV POSTGRES_VERSION=${POSTGRES_VERSION} \
    PGDATA=${PGDATA} \
    POSTGRES_PORT=${POSTGRES_PORT} \
    CLUSTER_NAME=${CLUSTER_NAME}

# Update package lists and install dependencies
# --no-install-recommends keeps image size smaller
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gnupg2 \ 
    wget \ 
    curl

RUN apt-get install -y --no-install-recommends postgresql-common ca-certificates 

RUN install -d /usr/share/postgresql-common/pgdg 

RUN curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc

RUN echo 'Types: deb deb-src\nURIs: https://apt.postgresql.org/pub/repos/apt\nSuites: jammy-pgdg\nArchitectures: amd64\nComponents: main\nSigned-By: /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc' \
    > /etc/apt/sources.list.d/pgdg.sources

RUN apt-get update
RUN apt-get -y install postgresql-${POSTGRES_VERSION} postgresql-contrib-${POSTGRES_VERSION}

RUN rm -rf /var/lib/apt/lists/*

# Drop existing cluster (if any)
RUN pg_dropcluster --stop ${POSTGRES_VERSION} main

# PostgreSQL configuration
# Create a directory for PostgreSQL data
RUN mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2775 /var/run/postgresql

# Create data directory if it doesn't exist
RUN mkdir -p ${PGDATA} && \
    chown -R postgres:postgres ${PGDATA} && \
    chmod 700 ${PGDATA}

# Set environment variable for PATH
RUN export PATH=$PATH:/usr/lib/postgresql/${POSTGRES_VERSION}/bin

# Expose PostgreSQL default port
EXPOSE ${POSTGRES_PORT}

# Switch to postgres user for running PostgreSQL
USER postgres

# Copy health check script
COPY --chown=postgres:postgres healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/healthcheck.sh

# Copy test script
COPY --chown=postgres:postgres test.sh /usr/local/bin/test.sh
RUN chmod +x /usr/local/bin/test.sh

# Health check configuration
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

RUN echo "Cluster Name: ${CLUSTER_NAME}, PostgreSQL Version: ${POSTGRES_VERSION}, Data Directory: ${PGDATA}"

RUN if [ ! -s "${PGDATA}/PG_VERSION" ]; then \
    echo "[INIT] No database found in ${PGDATA}. Creating cluster..." &&\
    pg_createcluster -p "${POSTGRES_PORT}" -d "${PGDATA}" "${POSTGRES_VERSION}" "${CLUSTER_NAME}"; \
    else \
    echo "[INIT] Existing database found in ${PGDATA}. Skipping creation."; \
    fi

ENTRYPOINT ["/bin/sh", "-c", "pg_ctlcluster --foreground ${POSTGRES_VERSION} ${CLUSTER_NAME} start"]