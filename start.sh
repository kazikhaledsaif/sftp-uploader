#!/bin/bash

# Quick Start Script for SFTP Uploader
# Run this after setting up the project

set -e

echo "🚀 Starting SFTP Uploader..."

# Check if Redis is running
if ! pgrep -x "redis-server" > /dev/null; then
    echo "⚠️  Redis is not running. Starting Redis..."
    brew services start redis
    sleep 2
fi

# Start Rails server in background
echo "🌐 Starting Rails server..."
rails server -p 3000 &
RAILS_PID=$!

# Start Sidekiq in background
echo "⚙️  Starting Sidekiq..."
bundle exec sidekiq &
SIDEKIQ_PID=$!

echo ""
echo "✅ SFTP Uploader is running!"
echo ""
echo "📍 Access the app at: http://localhost:3000"
echo "📊 Sidekiq dashboard: http://localhost:3000/sidekiq"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Wait for interrupt
trap "echo ''; echo '🛑 Stopping services...'; kill $RAILS_PID $SIDEKIQ_PID; exit" INT
wait
