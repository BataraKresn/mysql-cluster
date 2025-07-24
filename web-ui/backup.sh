#!/bin/bash

# MySQL Cluster Backup Script
# Creates a backup of all databases in the cluster

BACKUP_DIR="/app/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
MYSQL_HOST="mysql-primary"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD="2fF2P7xqVtc4iCExR"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting MySQL Cluster backup at $(date)"

# Backup all databases
mysqldump -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" \
    --all-databases \
    --routines \
    --triggers \
    --single-transaction \
    --master-data=2 \
    --flush-logs \
    --hex-blob \
    --opt \
    > "$BACKUP_DIR/mysql_cluster_backup_$TIMESTAMP.sql"

if [ $? -eq 0 ]; then
    echo "Backup completed successfully: mysql_cluster_backup_$TIMESTAMP.sql"
    
    # Compress the backup
    gzip "$BACKUP_DIR/mysql_cluster_backup_$TIMESTAMP.sql"
    echo "Backup compressed: mysql_cluster_backup_$TIMESTAMP.sql.gz"
    
    # Keep only last 10 backups
    ls -t "$BACKUP_DIR"/mysql_cluster_backup_*.sql.gz | tail -n +11 | xargs -r rm
    echo "Old backups cleaned up"
    
    echo "Backup process completed successfully at $(date)"
else
    echo "Backup failed at $(date)"
    exit 1
fi
