#!/bin/bash
set -e

# This script checks if PostgreSQL is running and accepting connections.

# -c "SELECT 1;": Execute a simple query to check connectivity.
# -t: Print tuples only (no column names or footers).
# -q: Run quietly.
# --no-align: Do not align columns (useful with -t).

if pg_isready ; then
    # Optional: Further check using psql if pg_isready is not enough
    if psql -c "SELECT 1;" -t -q --no-align > /dev/null 2>&1; then
        echo "PostgreSQL is healthy."
        exit 0
    else
        echo "PostgreSQL is not responding to psql command."
        exit 1
    fi
else
    echo "PostgreSQL is not ready."
    exit 1
fi