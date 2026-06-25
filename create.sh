#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status

# --- Configuration ---
COMPOSE_FILE="docker-compose.yml"
SERVICE_NAME="postgres" # Service name in docker-compose.yml
CONTAINER_NAME="postgres-container" # Container name in docker-compose.yml
TEST_SCRIPT_PATH="test.sh" # Path to test.sh inside the container

# Convert ARG to ENV so it's available at runtime
POSTGRES_VERSION=${POSTGRES_VERSION} 
PGDATA=${PGDATA} 
POSTGRES_PORT=${POSTGRES_PORT} 
CLUSTER_NAME=${CLUSTER_NAME} 
POSTGRES_PASSWORD=${POSTGRES_PASSWORD} # MUST match docker-compose.yml

# Define build/runtime args and environment variables.
# These will be passed to `docker compose` and `docker exec`.
# export POSTGRES_VERSION="${POSTGRES_VERSION}"
# export PGDATA="${PGDATA}"
# export POSTGRES_PORT="${POSTGRES_PORT}"
# export CLUSTER_NAME="${CLUSTER_NAME}"
# export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" # MUST match docker-compose.yml

HEALTH_CHECK_TIMEOUT=200 # Max seconds to wait for service to be healthy
SLEEP_INTERVAL=5         # Seconds to sleep between health checks

# --- Cleanup function ---
# This function is called regardless of whether the script exits successfully or due to an error.
cleanup() {
  local exit_code=$? # Capture the exit code of the last command before cleanup
  echo -e "\n--- Cleaning up Docker Compose resources ---"
  # Use 'docker compose down --volumes --remove-orphans' for a complete cleanup.
  # This ensures volumes are removed on failure for a fresh start.
  docker compose -f "${COMPOSE_FILE}" down --volumes --remove-orphans
  echo "--- Cleanup complete ---"
  exit "${exit_code}" # Exit with the original script's exit code
}

# Trap signals (e.g., Ctrl+C) and script exit to ensure cleanup happens
trap cleanup EXIT

echo "--- Starting Docker Compose Test and Run Workflow ---"

# --- 1. Build and Start Services ---
echo "1. Building and starting Docker Compose services in detached mode..."
# Passing environment variables as build-args and environment vars to services
docker compose -f "${COMPOSE_FILE}" up --build -d
echo "   ✅ Docker Compose services started."

# --- 2. Wait for Service Health ---
echo "2. Waiting for '${SERVICE_NAME}' service to become healthy (max ${HEALTH_CHECK_TIMEOUT} seconds)..."
ELAPSED_TIME=0
SERVICE_HEALTH="starting" # Initial state

while [ "${ELAPSED_TIME}" -lt "${HEALTH_CHECK_TIMEOUT}" ]; do
  # `docker compose ps -q` gets the container ID for the service.
  # `docker inspect` then checks its health status.
  SERVICE_HEALTH=$(docker inspect -f '{{.State.Health.Status}}' $(docker compose -f "${COMPOSE_FILE}" ps -q "${SERVICE_NAME}") 2>/dev/null || echo "not_found")
  echo "   Current health status of '${SERVICE_NAME}': ${SERVICE_HEALTH}"
  if [ "${SERVICE_HEALTH}" == "healthy" ]; then
    echo "   ✅ '${SERVICE_NAME}' service is healthy."
    break
  elif [ "${SERVICE_HEALTH}" == "unhealthy" ]; then
    echo "   ❌ '${SERVICE_NAME}' service became unhealthy during startup. Checking logs and exiting."
    docker compose -f "${COMPOSE_FILE}" logs "${SERVICE_NAME}" # Print logs for debugging
    exit 1 # Triggers cleanup via trap
  elif [ "${SERVICE_HEALTH}" == "not_found" ]; then
    echo "   ❌ Container for '${SERVICE_NAME}' not found. Did it fail to start? Exiting."
    exit 1 # Triggers cleanup via trap
  fi

  echo "   Still waiting for '${SERVICE_NAME}' health: ${SERVICE_HEALTH}... (${ELAPSED_TIME}/${HEALTH_CHECK_TIMEOUT}s)"
  sleep "${SLEEP_INTERVAL}"
  ELAPSED_TIME=$((ELAPSED_TIME + SLEEP_INTERVAL))
done

if [ "${SERVICE_HEALTH}" != "healthy" ]; then
  echo "   ❌ Timeout waiting for '${SERVICE_NAME}' to become healthy. Checking logs and exiting."
  docker compose -f "${COMPOSE_FILE}" logs "${SERVICE_NAME}" # Print logs for debugging
  exit 1 # Triggers cleanup via trap
fi

# --- 3. Execute Tests ---
echo "3. Executing tests inside '${CONTAINER_NAME}' container..."
echo "Test script path: ${TEST_SCRIPT_PATH}"
# Pass necessary environment variables to the exec command for the test script.
docker exec ${CONTAINER_NAME} ${TEST_SCRIPT_PATH}

TEST_EXIT_CODE=$?

if [ "${TEST_EXIT_CODE}" -eq 0 ]; then
  echo -e "\n   ✅ All tests passed successfully!"
  echo "--- PostgreSQL service is running and ready to accept connections. ---"
  # If tests pass, we want to keep the services running.
  # So, we unset the trap for a successful exit.
  trap - EXIT # This unsets the trap, preventing cleanup() from running on successful script completion.
else
  echo -e "\n   ❌ Tests failed with exit code ${TEST_EXIT_CODE}. Performing cleanup."
  exit "${TEST_EXIT_CODE}" # Triggers cleanup via trap
fi

# If we reached here and tests passed, the services remain running.
echo "To stop the running services manually, run: docker compose -f ${COMPOSE_FILE} down"


