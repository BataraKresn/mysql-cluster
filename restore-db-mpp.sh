#!/bin/bash

# ============================================================================
# MySQL Cluster Database Restore Script
# ============================================================================
# Script untuk restore database dp_mpp-24072025.sql ke cluster MySQL
# dengan nama database baru: db-mpp
# 
# Author: MySQL Cluster Admin
# Date: 2025-07-24
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROXYSQL_HOST="192.168.11.122"
PROXYSQL_PORT="6033"
PROXYSQL_ADMIN_PORT="6032"
PROXYSQL_USER="root"
PROXYSQL_PASS="2fF2P7xqVtc4iCExR"
MYSQL_ROOT_PASS="2fF2P7xqVtc4iCExR"
SOURCE_SQL_FILE="dp_mpp-24072025.sql"
NEW_DATABASE_NAME="db-mpp"
BACKUP_DIR="./backups"

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if source SQL file exists
    if [[ ! -f "$SOURCE_SQL_FILE" ]]; then
        error "Source SQL file '$SOURCE_SQL_FILE' not found!"
        exit 1
    fi
    
    # Check if mysql client is available
    if ! command -v mysql &> /dev/null; then
        error "MySQL client not found! Please install mysql-client."
        exit 1
    fi
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    success "Prerequisites check completed"
}

# Test ProxySQL connection
test_proxysql_connection() {
    log "Testing ProxySQL connection..."
    
    if mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" -e "SELECT 1;" &>/dev/null; then
        success "ProxySQL connection successful"
    else
        error "Cannot connect to ProxySQL at $PROXYSQL_HOST:$PROXYSQL_PORT"
        log "Please check if ProxySQL is running and credentials are correct"
        exit 1
    fi
}

# Check cluster status
check_cluster_status() {
    log "Checking MySQL cluster status..."
    
    # Check via ProxySQL admin interface
    local status_query="SELECT hostgroup_id,hostname,port,status,weight FROM mysql_servers ORDER BY hostgroup_id,hostname;"
    
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_ADMIN_PORT" -u"superman" -p"Soleh1!" -e "$status_query" 2>/dev/null || {
        error "Cannot connect to ProxySQL admin interface"
        exit 1
    }
    
    success "Cluster status check completed"
}

# Prepare SQL file for new database name
prepare_sql_file() {
    log "Preparing SQL file for database name change..."
    
    local temp_sql_file="temp_${NEW_DATABASE_NAME}_$(date +%s).sql"
    
    # Read the original SQL file and replace database references
    log "Creating modified SQL file: $temp_sql_file"
    
    # Create a new SQL file with database name changes
    cat > "$temp_sql_file" << EOF
-- ============================================================================
-- Database Restore Script for $NEW_DATABASE_NAME
-- Generated from: $SOURCE_SQL_FILE
-- Target Database: $NEW_DATABASE_NAME
-- Restore Date: $(date)
-- ============================================================================

-- Create database if not exists
CREATE DATABASE IF NOT EXISTS \`$NEW_DATABASE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use the new database
USE \`$NEW_DATABASE_NAME\`;

-- Source original SQL content
EOF

    # Process the original SQL file
    sed -e "s/CREATE DATABASE[^;]*;//g" \
        -e "s/USE [^;]*;//g" \
        -e "s/\`dp_mpp\`/\`$NEW_DATABASE_NAME\`/g" \
        -e "s/dp_mpp/$NEW_DATABASE_NAME/g" \
        "$SOURCE_SQL_FILE" >> "$temp_sql_file"
    
    echo "$temp_sql_file"
}

# Backup existing database if exists
backup_existing_database() {
    log "Checking if database '$NEW_DATABASE_NAME' already exists..."
    
    local db_exists=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" \
        -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$NEW_DATABASE_NAME';" \
        --skip-column-names --silent)
    
    if [[ -n "$db_exists" ]]; then
        warning "Database '$NEW_DATABASE_NAME' already exists!"
        
        # Create backup
        local backup_file="$BACKUP_DIR/backup_${NEW_DATABASE_NAME}_$(date +%Y%m%d_%H%M%S).sql"
        log "Creating backup: $backup_file"
        
        mysqldump -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" \
            --single-transaction --routines --triggers --events \
            "$NEW_DATABASE_NAME" > "$backup_file"
        
        success "Backup created: $backup_file"
        
        # Ask for confirmation
        read -p "Do you want to drop existing database and continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Operation cancelled by user"
            exit 0
        fi
        
        # Drop existing database
        mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" \
            -e "DROP DATABASE IF EXISTS \`$NEW_DATABASE_NAME\`;"
        
        success "Existing database dropped"
    else
        log "Database '$NEW_DATABASE_NAME' does not exist - will create new"
    fi
}

# Restore database to primary (write operations)
restore_to_primary() {
    local sql_file="$1"
    
    log "Restoring database to MySQL cluster via ProxySQL..."
    log "Source file: $sql_file"
    log "Target database: $NEW_DATABASE_NAME"
    
    # Execute the restore via ProxySQL (writes go to primary)
    if mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" < "$sql_file"; then
        success "Database restore completed successfully"
    else
        error "Database restore failed!"
        exit 1
    fi
}

# Verify replication status
verify_replication() {
    log "Verifying replication status..."
    
    # Wait a moment for replication to catch up
    sleep 3
    
    # Check if database exists on both primary and replica
    local primary_tables=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" \
        -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$NEW_DATABASE_NAME';" \
        --skip-column-names --silent)
    
    log "Tables found in database '$NEW_DATABASE_NAME': $primary_tables"
    
    if [[ "$primary_tables" -gt 0 ]]; then
        success "Database '$NEW_DATABASE_NAME' created successfully with $primary_tables tables"
    else
        warning "No tables found in database '$NEW_DATABASE_NAME'"
    fi
    
    # Check replication lag via ProxySQL admin
    log "Checking replication lag..."
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_ADMIN_PORT" -u"superman" -p"Soleh1!" \
        -e "SELECT hostgroup_id,hostname,port,status FROM mysql_servers;" \
        2>/dev/null || warning "Could not check detailed replication stats"
}

# Configure ProxySQL query rules for new database
configure_proxysql_rules() {
    log "Configuring ProxySQL query rules for database '$NEW_DATABASE_NAME'..."
    
    # Add query rules for the new database
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_ADMIN_PORT" -u"superman" -p"Soleh1!" << EOF
-- Add query rule for SELECT queries on db-mpp (route to reader hostgroup)
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) 
VALUES (3000, 1, '^SELECT.*FROM.*$NEW_DATABASE_NAME.*', 1, 1)
ON DUPLICATE KEY UPDATE 
    active=1, 
    match_pattern='^SELECT.*FROM.*$NEW_DATABASE_NAME.*', 
    destination_hostgroup=1, 
    apply=1;

-- Add query rule for write queries on db-mpp (route to writer hostgroup)
INSERT INTO mysql_query_rules (rule_id, active, match_pattern, destination_hostgroup, apply) 
VALUES (3001, 1, '^(INSERT|UPDATE|DELETE|CREATE|DROP|ALTER).*$NEW_DATABASE_NAME.*', 0, 1)
ON DUPLICATE KEY UPDATE 
    active=1, 
    match_pattern='^(INSERT|UPDATE|DELETE|CREATE|DROP|ALTER).*$NEW_DATABASE_NAME.*', 
    destination_hostgroup=0, 
    apply=1;

-- Load the rules to runtime
LOAD MYSQL QUERY RULES TO RUNTIME;

-- Save to disk
SAVE MYSQL QUERY RULES TO DISK;
EOF

    if [[ $? -eq 0 ]]; then
        success "ProxySQL query rules configured for database '$NEW_DATABASE_NAME'"
    else
        warning "Failed to configure ProxySQL query rules"
    fi
}

# Test database access
test_database_access() {
    log "Testing database access..."
    
    # Test read access
    local test_query="SELECT COUNT(*) as table_count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$NEW_DATABASE_NAME';"
    local result=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$PROXYSQL_USER" -p"$PROXYSQL_PASS" \
        -e "$test_query" --skip-column-names --silent)
    
    success "Database access test completed. Tables found: $result"
    
    # Show connection info
    log "Database connection info:"
    echo "  Host: $PROXYSQL_HOST"
    echo "  Port: $PROXYSQL_PORT"
    echo "  Database: $NEW_DATABASE_NAME"
    echo "  Username: $PROXYSQL_USER"
}

# Generate connection examples
generate_connection_examples() {
    log "Generating connection examples..."
    
    cat > "connection-examples-${NEW_DATABASE_NAME}.txt" << EOF
# ============================================================================
# Database Connection Examples for $NEW_DATABASE_NAME
# Generated: $(date)
# ============================================================================

## MySQL Command Line
mysql -h $PROXYSQL_HOST -P $PROXYSQL_PORT -u $PROXYSQL_USER -p$PROXYSQL_PASS $NEW_DATABASE_NAME

## PHP PDO Connection
\$pdo = new PDO(
    'mysql:host=$PROXYSQL_HOST;port=$PROXYSQL_PORT;dbname=$NEW_DATABASE_NAME;charset=utf8mb4',
    '$PROXYSQL_USER',
    '$PROXYSQL_PASS',
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]
);

## Laravel .env Configuration
DB_CONNECTION=mysql
DB_HOST=$PROXYSQL_HOST
DB_PORT=$PROXYSQL_PORT
DB_DATABASE=$NEW_DATABASE_NAME
DB_USERNAME=$PROXYSQL_USER
DB_PASSWORD=$PROXYSQL_PASS

## Python PyMySQL
import pymysql
connection = pymysql.connect(
    host='$PROXYSQL_HOST',
    port=$PROXYSQL_PORT,
    user='$PROXYSQL_USER',
    password='$PROXYSQL_PASS',
    database='$NEW_DATABASE_NAME',
    charset='utf8mb4'
)

## Node.js MySQL2
const mysql = require('mysql2/promise');
const connection = await mysql.createConnection({
    host: '$PROXYSQL_HOST',
    port: $PROXYSQL_PORT,
    user: '$PROXYSQL_USER',
    password: '$PROXYSQL_PASS',
    database: '$NEW_DATABASE_NAME'
});

## DBeaver/Navicat Connection
Host: $PROXYSQL_HOST
Port: $PROXYSQL_PORT
Database: $NEW_DATABASE_NAME
Username: $PROXYSQL_USER
Password: $PROXYSQL_PASS

## Query Routing (via ProxySQL)
- SELECT queries → Routed to MySQL Replica (Read)
- INSERT/UPDATE/DELETE → Routed to MySQL Primary (Write)
- DDL statements → Routed to MySQL Primary (Write)

EOF

    success "Connection examples saved to: connection-examples-${NEW_DATABASE_NAME}.txt"
}

# Main restore function
main() {
    log "============================================================================"
    log "MySQL Cluster Database Restore Script"
    log "============================================================================"
    log "Source SQL file: $SOURCE_SQL_FILE"
    log "Target database: $NEW_DATABASE_NAME"
    log "ProxySQL endpoint: $PROXYSQL_HOST:$PROXYSQL_PORT"
    log "============================================================================"
    
    # Run all steps
    check_prerequisites
    test_proxysql_connection
    check_cluster_status
    
    # Prepare SQL file
    local temp_sql_file=$(prepare_sql_file)
    
    # Backup existing database if needed
    backup_existing_database
    
    # Restore database
    restore_to_primary "$temp_sql_file"
    
    # Configure ProxySQL rules
    configure_proxysql_rules
    
    # Verify and test
    verify_replication
    test_database_access
    
    # Generate connection examples
    generate_connection_examples
    
    # Cleanup
    rm -f "$temp_sql_file"
    
    log "============================================================================"
    success "Database restore completed successfully!"
    log "Database '$NEW_DATABASE_NAME' is now available via ProxySQL"
    log "Connection details saved in: connection-examples-${NEW_DATABASE_NAME}.txt"
    log "============================================================================"
}

# Show usage if help requested
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "This script restores the database dp_mpp-24072025.sql to MySQL cluster"
    echo "with new database name: $NEW_DATABASE_NAME"
    echo ""
    echo "Prerequisites:"
    echo "  - ProxySQL must be running and accessible"
    echo "  - MySQL cluster must be healthy"
    echo "  - Source SQL file must exist: $SOURCE_SQL_FILE"
    echo ""
    echo "The script will:"
    echo "  1. Check prerequisites and connections"
    echo "  2. Backup existing database (if exists)"
    echo "  3. Restore database via ProxySQL"
    echo "  4. Configure ProxySQL routing rules"
    echo "  5. Verify replication and access"
    echo "  6. Generate connection examples"
    exit 0
fi

# Run main function
main "$@"
