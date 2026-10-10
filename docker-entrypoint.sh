#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f /app/tmp/pids/server.pid

# Create/migrate the database (safe to run every start)
bundle exec rails db:prepare

# Execute the main command
exec "$@"
