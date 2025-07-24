#!/bin/bash

# MySQL Cluster Dashboard Deployment Script
set -e

echo "🐬 Deploying MySQL Cluster Dashboard..."

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p web-ui/logs
mkdir -p web-ui/backups

# Copy environment file if it doesn't exist
if [ ! -f web-ui/.env ]; then
    echo "📝 Creating environment file..."
    cp web-ui/.env.example web-ui/.env
    echo "⚠️  Please review and update web-ui/.env with your settings"
fi

# Check if main cluster is running
echo "🔍 Checking if MySQL cluster is running..."
if ! docker ps | grep -q mysql-primary; then
    echo "⚠️  MySQL cluster is not running. Starting main cluster first..."
    docker-compose up -d mysql-primary mysql-replica proxysql
    echo "⏳ Waiting for cluster to be ready..."
    sleep 30
fi

# Build and start dashboard
echo "🏗️  Building dashboard..."
cd web-ui
docker-compose build

echo "🚀 Starting dashboard..."
docker-compose up -d

# Wait for dashboard to be ready
echo "⏳ Waiting for dashboard to be ready..."
sleep 10

# Health check
echo "🏥 Performing health check..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health >/dev/null 2>&1; then
        echo "✅ Dashboard is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Dashboard health check failed"
        echo "📋 Checking logs..."
        docker-compose logs mysql-dashboard
        exit 1
    fi
    sleep 2
done

echo ""
echo "🎉 MySQL Cluster Dashboard deployed successfully!"
echo ""
echo "📊 Access Points:"
echo "   Dashboard:        http://localhost:5000"
echo "   ProxySQL Web UI:  http://localhost:6080"
echo "   ProxySQL Admin:   mysql -h localhost -P 6032 -u admin -p"
echo "   MySQL Proxy:      mysql -h localhost -P 6033 -u your_user -p"
echo ""
echo "🛠️  Management Commands:"
echo "   View logs:        docker compose logs mysql-dashboard"
echo "   Restart:          docker compose restart mysql-dashboard"
echo "   Stop:             docker compose down"
echo "   Update:           docker compose pull && docker compose up -d"
echo ""
echo "📋 Dashboard Features:"
echo "   ✓ Real-time cluster monitoring"
echo "   ✓ ProxySQL backend status"
echo "   ✓ Replication lag monitoring"
echo "   ✓ Quick service restart"
echo "   ✓ Automated backup"
echo "   ✓ Log viewing"
echo ""
