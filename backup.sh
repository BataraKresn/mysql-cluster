#!/bin/bash
# MySQL Cluster Backup Script
# Usage: ./backup.sh [full|incremental]

set -e

# Configuration
BACKUP_DIR="/var/backups/mysql-cluster"
MYSQL_ROOT_PASS="2fF2P7xqVtc4iCExR"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d_%H%M%S)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Create backup directory
mkdir -p $BACKUP_DIR

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}     MySQL Cluster Backup Script${NC}"
echo -e "${BLUE}===========================================${NC}"
echo "Date: $(date)"
echo "Backup Directory: $BACKUP_DIR"
echo

# Function to check if container is running
check_container() {
    if ! docker ps --format "{{.Names}}" | grep -q "^mysql-primary$"; then
        echo -e "${RED}Error: mysql-primary container is not running${NC}"
        exit 1
    fi
}

# Function to create full backup
full_backup() {
    echo -e "${YELLOW}Creating full backup...${NC}"
    
    BACKUP_FILE="$BACKUP_DIR/full_backup_$DATE.sql"
    
    docker exec mysql-primary mysqldump \
        -uroot -p$MYSQL_ROOT_PASS \
        --all-databases \
        --master-data=2 \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --flush-logs \
        --hex-blob \
        --complete-insert > $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        # Compress backup
        gzip $BACKUP_FILE
        BACKUP_FILE="$BACKUP_FILE.gz"
        
        # Get file size
        SIZE=$(du -h $BACKUP_FILE | cut -f1)
        
        echo -e "${GREEN}✓ Full backup completed successfully${NC}"
        echo "Backup file: $BACKUP_FILE"
        echo "Backup size: $SIZE"
        
        # Create checksum
        md5sum $BACKUP_FILE > $BACKUP_FILE.md5
        echo -e "${GREEN}✓ Checksum created${NC}"
        
    else
        echo -e "${RED}✗ Full backup failed${NC}"
        exit 1
    fi
}

# Function to create incremental backup (binary logs)
incremental_backup() {
    echo -e "${YELLOW}Creating incremental backup (binary logs)...${NC}"
    
    BINLOG_DIR="$BACKUP_DIR/binlogs_$DATE"
    mkdir -p $BINLOG_DIR
    
    # Get list of binary logs
    BINLOGS=$(docker exec mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW BINARY LOGS;" | awk 'NR>1 {print $1}')
    
    if [ -z "$BINLOGS" ]; then
        echo -e "${RED}✗ No binary logs found${NC}"
        exit 1
    fi
    
    # Backup each binary log
    for binlog in $BINLOGS; do
        echo "Backing up binary log: $binlog"
        docker exec mysql-primary mysqlbinlog /var/lib/mysql/$binlog > $BINLOG_DIR/$binlog.sql
    done
    
    # Compress binlog directory
    tar -czf $BINLOG_DIR.tar.gz -C $BACKUP_DIR binlogs_$DATE
    rm -rf $BINLOG_DIR
    
    SIZE=$(du -h $BINLOG_DIR.tar.gz | cut -f1)
    
    echo -e "${GREEN}✓ Incremental backup completed${NC}"
    echo "Backup file: $BINLOG_DIR.tar.gz"
    echo "Backup size: $SIZE"
    
    # Create checksum
    md5sum $BINLOG_DIR.tar.gz > $BINLOG_DIR.tar.gz.md5
}

# Function to cleanup old backups
cleanup_old_backups() {
    echo -e "${YELLOW}Cleaning up backups older than $RETENTION_DAYS days...${NC}"
    
    find $BACKUP_DIR -name "*.sql.gz" -type f -mtime +$RETENTION_DAYS -delete
    find $BACKUP_DIR -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
    find $BACKUP_DIR -name "*.md5" -type f -mtime +$RETENTION_DAYS -delete
    
    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Function to verify backup
verify_backup() {
    local backup_file=$1
    
    echo -e "${YELLOW}Verifying backup integrity...${NC}"
    
    if [ -f "$backup_file.md5" ]; then
        if md5sum -c "$backup_file.md5" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Backup integrity verified${NC}"
        else
            echo -e "${RED}✗ Backup integrity check failed${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠ No checksum file found${NC}"
    fi
}

# Function to get replication status
get_replication_info() {
    echo -e "${YELLOW}Capturing replication status...${NC}"
    
    REPL_INFO_FILE="$BACKUP_DIR/replication_info_$DATE.txt"
    
    echo "=== MASTER STATUS ===" > $REPL_INFO_FILE
    docker exec mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW MASTER STATUS\G" >> $REPL_INFO_FILE
    
    echo -e "\n=== SLAVE STATUS ===" >> $REPL_INFO_FILE
    docker exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G" >> $REPL_INFO_FILE 2>/dev/null || echo "Replica not available" >> $REPL_INFO_FILE
    
    echo -e "${GREEN}✓ Replication status saved to $REPL_INFO_FILE${NC}"
}

# Main script logic
check_container

BACKUP_TYPE=${1:-full}

case $BACKUP_TYPE in
    "full")
        full_backup
        get_replication_info
        verify_backup "$BACKUP_DIR/full_backup_$DATE.sql.gz"
        ;;
    "incremental")
        incremental_backup
        get_replication_info
        verify_backup "$BINLOG_DIR.tar.gz"
        ;;
    *)
        echo "Usage: $0 [full|incremental]"
        echo "  full        - Create full database backup (default)"
        echo "  incremental - Create incremental backup (binary logs)"
        exit 1
        ;;
esac

cleanup_old_backups

echo
echo -e "${BLUE}===========================================${NC}"
echo -e "${GREEN}✅ Backup process completed successfully${NC}"
echo -e "${BLUE}===========================================${NC}"

# Show backup summary
echo
echo "Backup Summary:"
echo "---------------"
ls -lh $BACKUP_DIR/*$DATE* 2>/dev/null || echo "No backup files found"

echo
echo "Total backup storage used:"
du -sh $BACKUP_DIR
