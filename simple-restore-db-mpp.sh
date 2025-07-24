#!/bin/bash

# ============================================================================
# Simple MySQL Database Restore Script
# ============================================================================
# Script untuk restore database dp_mpp-24072025.sql ke cluster MySQL
# dengan nama database: db-mpp
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROXYSQL_HOST="192.168.11.122"
PROXYSQL_PORT="6033"
MYSQL_USER="root"
MYSQL_PASS="2fF2P7xqVtc4iCExR"
SOURCE_SQL_FILE="dp_mpp-24072025.sql"
NEW_DATABASE_NAME="db-mpp"

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

# Main restore process
log "============================================================================"
log "Starting database restore process"
log "Source: $SOURCE_SQL_FILE"
log "Target: $NEW_DATABASE_NAME"
log "ProxySQL: $PROXYSQL_HOST:$PROXYSQL_PORT"
log "============================================================================"

# Check if source file exists
if [[ ! -f "$SOURCE_SQL_FILE" ]]; then
    error "Source SQL file '$SOURCE_SQL_FILE' not found!"
    exit 1
fi

# Test connection
log "Testing ProxySQL connection..."
if mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1;" &>/dev/null; then
    success "ProxySQL connection successful"
else
    error "Cannot connect to ProxySQL"
    exit 1
fi

# Drop existing database if exists
log "Dropping existing database '$NEW_DATABASE_NAME' if exists..."
mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
    -e "DROP DATABASE IF EXISTS \`$NEW_DATABASE_NAME\`;" 2>/dev/null

# Create new database
log "Creating database '$NEW_DATABASE_NAME'..."
mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
    -e "CREATE DATABASE \`$NEW_DATABASE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null

success "Database '$NEW_DATABASE_NAME' created successfully"

# Start restore process
log "Starting database restore (this may take a while for large files)..."
log "File size: $(du -h $SOURCE_SQL_FILE | cut -f1)"

# Create temporary SQL file for restore
TEMP_SQL="temp_restore_$(date +%s).sql"

# Prepare SQL with proper database context
cat > "$TEMP_SQL" << EOF
USE \`$NEW_DATABASE_NAME\`;
SET FOREIGN_KEY_CHECKS=0;
SET UNIQUE_CHECKS=0;
SET AUTOCOMMIT=0;
EOF

# Process original SQL file and append to temp file
# Remove any existing database creation/use statements
sed -e '/^CREATE DATABASE/d' \
    -e '/^USE /d' \
    -e '/^\/\*.*CREATE DATABASE.*\*\//d' \
    "$SOURCE_SQL_FILE" >> "$TEMP_SQL"

# Add commit at the end
echo "COMMIT;" >> "$TEMP_SQL"
echo "SET FOREIGN_KEY_CHECKS=1;" >> "$TEMP_SQL"
echo "SET UNIQUE_CHECKS=1;" >> "$TEMP_SQL"

# Main restore function
main() {
    log "============================================================================"
    log "Starting database restore process"
    log "Source: $SOURCE_SQL_FILE"
    log "Target: $NEW_DATABASE_NAME"
    log "ProxySQL: $PROXYSQL_HOST:$PROXYSQL_PORT"
    log "============================================================================"

    # Save PID for monitoring
    echo $$ > restore_process.pid
    
    # Check if source file exists
    if [[ ! -f "$SOURCE_SQL_FILE" ]]; then
        error "Source SQL file '$SOURCE_SQL_FILE' not found!"
        rm -f restore_process.pid
        exit 1
    fi

    # Test connection
    log "Testing ProxySQL connection..."
    if mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1;" &>/dev/null; then
        success "ProxySQL connection successful"
    else
        error "Cannot connect to ProxySQL"
        rm -f restore_process.pid
        exit 1
    fi

    # Drop existing database if exists
    log "Dropping existing database '$NEW_DATABASE_NAME' if exists..."
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "DROP DATABASE IF EXISTS \`$NEW_DATABASE_NAME\`;" 2>/dev/null

    # Create new database
    log "Creating database '$NEW_DATABASE_NAME'..."
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "CREATE DATABASE \`$NEW_DATABASE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null

    success "Database '$NEW_DATABASE_NAME' created successfully"

    # Start restore process
    log "Starting database restore (this may take a while for large files)..."
    log "File size: $(du -h $SOURCE_SQL_FILE | cut -f1)"
    log "Monitor progress with: ./monitor-restore.sh"

    # Create temporary SQL file for restore
    TEMP_SQL="temp_restore_$(date +%s).sql"

    # Prepare SQL with proper database context
    cat > "$TEMP_SQL" << EOF
USE \`$NEW_DATABASE_NAME\`;
SET FOREIGN_KEY_CHECKS=0;
SET UNIQUE_CHECKS=0;
SET AUTOCOMMIT=0;
EOF

    # Process original SQL file and append to temp file
    # Remove any existing database creation/use statements
    sed -e '/^CREATE DATABASE/d' \
        -e '/^USE /d' \
        -e '/^\/\*.*CREATE DATABASE.*\*\//d' \
        "$SOURCE_SQL_FILE" >> "$TEMP_SQL"

    # Add commit at the end
    echo "COMMIT;" >> "$TEMP_SQL"
    echo "SET FOREIGN_KEY_CHECKS=1;" >> "$TEMP_SQL"
    echo "SET UNIQUE_CHECKS=1;" >> "$TEMP_SQL"

    # Execute restore
    log "Executing SQL restore..."
    start_time=$(date +%s)

    if mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" < "$TEMP_SQL"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        success "Database restore completed in ${duration} seconds"
    else
        error "Database restore failed!"
        rm -f "$TEMP_SQL"
        rm -f restore_process.pid
        exit 1
    fi

    # Cleanup
    rm -f "$TEMP_SQL"

    # Verify restore
    log "Verifying restore..."
    sleep 2

    TABLE_COUNT=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$NEW_DATABASE_NAME';" \
        --skip-column-names --silent 2>/dev/null)

    if [[ "$TABLE_COUNT" -gt 0 ]]; then
        success "Restore verification successful - $TABLE_COUNT tables found"
    else
        warning "No tables found after restore"
    fi

    # Generate connection info
    log "============================================================================"
    success "🎉 DATABASE RESTORE COMPLETED SUCCESSFULLY! 🎉"
    log "Database: $NEW_DATABASE_NAME"
    log "Tables: $TABLE_COUNT"
    log "Connection details:"
    echo "  Host: $PROXYSQL_HOST"
    echo "  Port: $PROXYSQL_PORT"
    echo "  Database: $NEW_DATABASE_NAME"
    echo "  Username: $MYSQL_USER"
    echo ""
    echo "Connection string example:"
    echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_PORT -u $MYSQL_USER -p $NEW_DATABASE_NAME"
    log "============================================================================"
    
    # Clean up PID file
    rm -f restore_process.pid
}

# Execute main function
main "$@"
