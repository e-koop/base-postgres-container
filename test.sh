#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

echo "--- Starting PostgreSQL Docker Container Tests ---"

# --- Test 1: PostgreSQL Version Check ---
echo "1. Checking PostgreSQL version..."

# Get the version from the installed PostgreSQL instance
# We'll use psql -V and extract the version number
INSTALLED_PG_VERSION=$(psql -V | grep -oP '\d+\.\d+' | head -1 | cut -d'.' -f1)
echo "Installed PostgreSQL version: $INSTALLED_PG_VERSION"

# Get the version from the environment variable set in the Dockerfile
EXPECTED_PG_VERSION=${POSTGRES_VERSION}
echo "Expected PostgreSQL version (from ENV): $EXPECTED_PG_VERSION"

if [ "$INSTALLED_PG_VERSION" == "$EXPECTED_PG_VERSION" ]; then
    echo "  ✅ PostgreSQL version matches expected: $INSTALLED_PG_VERSION"
else
    echo "  ❌ PostgreSQL version mismatch! Expected: $EXPECTED_PG_VERSION, Installed: $INSTALLED_PG_VERSION"
    exit 1
fi

# --- Test 2: psql Connection Check ---
echo "2. Checking psql connection..."

# Attempt to connect to PostgreSQL using psql
# and execute a simple query. If it succeeds, the connection is working.
# We use the 'postgres' user and the default 'postgres' database.
# -t means print tuples only
# -c means run command
# We pipe to 'cat' to consume the output and ensure the command completes.
if psql -U postgres -d postgres -t -c "SELECT 1;" > /dev/null 2>&1; then
    echo "  ✅ Successfully connected to PostgreSQL using psql."
else
    echo "  ❌ Failed to connect to PostgreSQL using psql."
    exit 1
fi

echo "--- All Tests Passed! ---"