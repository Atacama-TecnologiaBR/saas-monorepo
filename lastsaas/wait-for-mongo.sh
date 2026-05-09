#!/bin/sh
# Aguarda MongoDB aceitar conexões antes de iniciar o servidor Go
set -e

MONGO_HOST="${MONGO_HOST:-mongodb}"
MONGO_PORT="${MONGO_PORT:-27017}"
MAX_WAIT=120
WAIT_INTERVAL=3

echo "Waiting for MongoDB at $MONGO_HOST:$MONGO_PORT..."
elapsed=0

while [ $elapsed -lt $MAX_WAIT ]; do
  if nc -z "$MONGO_HOST" "$MONGO_PORT" 2>/dev/null; then
    echo "MongoDB is up after ${elapsed}s. Starting lastsaas..."
    sleep 2
    exec "$@"
  fi
  sleep $WAIT_INTERVAL
  elapsed=$((elapsed + WAIT_INTERVAL))
  echo "Still waiting for MongoDB... (${elapsed}s)"
done

echo "MongoDB not available after ${MAX_WAIT}s, starting anyway..."
exec "$@"
