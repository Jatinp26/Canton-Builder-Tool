#!/bin/bash
# Creates multiple PostgreSQL databases from a comma-separated list
# in POSTGRES_MULTIPLE_DATABASES env var.
set -e

function create_db() {
  local db=$1
  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE DATABASE "$db";
    GRANT ALL PRIVILEGES ON DATABASE "$db" TO "$POSTGRES_USER";
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
  echo "Creating multiple databases..."
  # Strip whitespace and newlines, split on comma
  for db in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' '\n' | tr -d ' \t\r\n'); do
    create_db "$db"
  done
  echo "All databases created."
fi
