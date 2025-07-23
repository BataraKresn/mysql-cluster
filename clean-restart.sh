#!/bin/bash
# Script untuk clean restart MySQL cluster
# HATI-HATI: Ini akan menghapus SEMUA data!

echo "======================================"
echo "  CLEAN RESTART MySQL CLUSTER"
echo "======================================"
echo "⚠️  WARNING: Ini akan menghapus SEMUA data MySQL!"
echo "Tekan Ctrl+C untuk membatalkan dalam 10 detik..."
sleep 10

cd /mnt/mysql-new/mysql-cluster

echo "🗑️  Stopping dan removing containers..."
docker compose down -v

echo "🗑️  Removing data directories..."
sudo rm -rf primary-data/* replicat-data/*

echo "📁  Recreating data directories..."
sudo mkdir -p primary-data replicat-data
sudo chown -R 999:999 primary-data replicat-data

echo "🚀  Starting fresh deployment..."
./deploy.sh

echo "✅  Clean restart completed!"
echo "Database akan otomatis sinkron dengan replication!"
