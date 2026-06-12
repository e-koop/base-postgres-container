# Use official Ubuntu image as the base
# 22.04 is the LTS (Long Term Support) version
FROM ubuntu:22.04

# Set metadata labels for documentation
LABEL description="Base Ubuntu container with essential tools and postgresql installed"

# Build arguments from docker-compose
ARG POSTGRES_VERSION
ARG PGDATA
ARG POSTGRES_PORT
ARG DEBIAN_FRONTEND=noninteractive

# Convert ARG to ENV so it's available at runtime
ENV POSTGRES_VERSION=${POSTGRES_VERSION} \
    PGDATA=${PGDATA} \
    POSTGRES_PORT=${POSTGRES_PORT}

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

# PostgreSQL configuration
# Create a directory for PostgreSQL data
RUN mkdir -p /var/run/postgresql && \
    chown -R postgres:postgres /var/run/postgresql && \
    chmod 2775 /var/run/postgresql


RUN mkdir -p ${PGDATA} && \
    chown -R postgres:postgres ${PGDATA} && \
    chmod 700 ${PGDATA}

# Expose PostgreSQL default port
EXPOSE ${POSTGRES_PORT}

# Switch to postgres user for running PostgreSQL
# PostgreSQL must run as the postgres system user for security and proper operation
USER postgres

# Initialize and start PostgreSQL on container startup
ENTRYPOINT ["/bin/sh", "-c", "if [ ! -s \"$PGDATA/PG_VERSION\" ]; then /usr/lib/postgresql/$POSTGRES_VERSION/bin/initdb -D $PGDATA; fi && /usr/lib/postgresql/$POSTGRES_VERSION/bin/postgres -D $PGDATA"]
