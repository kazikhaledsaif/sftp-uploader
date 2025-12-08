#!/bin/bash

# SFTP File Uploader - Home Server Deployment Script
# This script helps you deploy the application on your home server

set -e

echo "🏠 SFTP File Uploader - Home Server Deployment"
echo "=============================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed!"
    echo "Please install Docker Compose first:"
    echo "  sudo apt install docker-compose"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your SFTP credentials:"
    echo "   nano .env"
    echo ""
    read -p "Press Enter after you've configured .env..."
fi

# Generate SECRET_KEY_BASE if not set
if ! grep -q "SECRET_KEY_BASE=.*[a-zA-Z0-9]" .env; then
    echo "🔑 Generating SECRET_KEY_BASE..."
    SECRET=$(docker run --rm ruby:3.2.0-slim ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
    sed -i "s/SECRET_KEY_BASE=.*/SECRET_KEY_BASE=$SECRET/" .env
    echo "✅ SECRET_KEY_BASE generated"
fi

echo ""
echo "🏗️  Building Docker images..."
docker-compose build

echo ""
echo "🚀 Starting services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to start..."
sleep 5

echo ""
echo "📊 Service Status:"
docker-compose ps

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📍 Access your application at:"
echo "   http://localhost:3000"
echo "   http://$(hostname -I | awk '{print $1}'):3000"
echo ""
echo "📝 Useful commands:"
echo "   View logs:        docker-compose logs -f"
echo "   Stop services:    docker-compose down"
echo "   Restart:          docker-compose restart"
echo "   Update app:       git pull && docker-compose build && docker-compose up -d"
echo ""
echo "📚 Documentation:"
echo "   Home Server Guide: HOME_SERVER_DEPLOY.md"
echo ""
