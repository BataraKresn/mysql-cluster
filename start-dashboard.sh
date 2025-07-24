#!/bin/bash

# Quick Start Script untuk MySQL Cluster Dashboard
echo "🚀 Starting MySQL Cluster Dashboard..."

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Please run this script from the mysql-cluster directory"
    exit 1
fi

# Start main cluster if not running
echo "📋 Checking MySQL cluster status..."
if ! docker ps | grep -q mysql-primary; then
    echo "🐬 Starting MySQL cluster..."
    docker-compose up -d mysql-primary mysql-replica proxysql
    
    echo "⏳ Waiting for cluster to initialize..."
    sleep 30
    
    # Verify cluster is up
    if ! docker ps | grep -q mysql-primary; then
        echo "❌ Failed to start MySQL cluster"
        exit 1
    fi
    echo "✅ MySQL cluster is running"
else
    echo "✅ MySQL cluster is already running"
fi

# Build and start dashboard
echo "🏗️ Building and starting dashboard..."
cd web-ui

# Check if Docker image needs to be built
if ! docker images | grep -q mysql-cluster_mysql-dashboard; then
    echo "📦 Building dashboard image..."
    docker-compose build
fi

# Start dashboard
docker-compose up -d

# Go back to main directory
cd ..

# Wait for dashboard to be ready
echo "⏳ Waiting for dashboard to be ready..."
for i in {1..30}; do
    if curl -f http://localhost:5000/health >/dev/null 2>&1; then
        echo "✅ Dashboard is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Dashboard health check failed"
        exit 1
    fi
    sleep 2
done

echo ""
echo "🎉 MySQL Cluster Dashboard is ready!"
echo ""
echo "📊 Access URLs:"
echo "   Main Dashboard:   http://localhost:5000"
echo "   ProxySQL Web UI:  http://localhost:6080"
echo ""
echo "🔗 Connection Strings:"
echo "   ProxySQL Admin:   mysql -h localhost -P 6032 -u admin -padmin"
echo "   MySQL via Proxy:  mysql -h localhost -P 6033 -u root -p2fF2P7xqVtc4iCExR"
echo ""
echo "📋 Quick Commands:"
echo "   View logs:        docker compose -f web-ui/docker compose.yml logs"
echo "   Stop dashboard:   docker compose -f web-ui/docker compose.yml down"
echo "   Restart:          docker compose -f web-ui/docker compose.yml restart"
echo ""
