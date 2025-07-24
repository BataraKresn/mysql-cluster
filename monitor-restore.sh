#!/bin/bash

# Monitor database restore progress with completion detection

PROXYSQL_HOST="192.168.11.122"
PROXYSQL_PORT="6033"
MYSQL_USER="root"
MYSQL_PASS="2fF2P7xqVtc4iCExR"
DATABASE_NAME="db-mpp"
RESTORE_PID_FILE="restore_process.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables to track progress
LAST_TABLE_COUNT=0
STABLE_COUNT=0
MAX_STABLE_CHECKS=6  # 6 checks * 5 seconds = 30 seconds stable

echo -e "${BLUE}=== MySQL Database Restore Progress Monitor ===${NC}"
echo -e "${CYAN}Database: $DATABASE_NAME${NC}"
echo -e "${CYAN}Monitoring started at: $(date)${NC}"
echo -e "${BLUE}===============================================${NC}"

while true; do
    # Get table count
    TABLE_COUNT=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$DATABASE_NAME';" \
        --skip-column-names --silent 2>/dev/null || echo "0")
    
    # Get database size
    DB_SIZE=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb 
            FROM information_schema.tables 
            WHERE table_schema = '$DATABASE_NAME';" \
        --skip-column-names --silent 2>/dev/null || echo "0")
    
    # Get process list to see if restore is running
    PROCESSES=$(mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASS" \
        -e "SHOW PROCESSLIST;" --skip-column-names --silent 2>/dev/null | grep -c "db-mpp" || echo "0")
    
    # Check if restore process is still running
    RESTORE_RUNNING=false
    if [ -f "$RESTORE_PID_FILE" ]; then
        RESTORE_PID=$(cat "$RESTORE_PID_FILE")
        if ps -p "$RESTORE_PID" > /dev/null 2>&1; then
            RESTORE_RUNNING=true
        else
            rm -f "$RESTORE_PID_FILE"
        fi
    fi
    
    # Check for MySQL processes that might indicate restore activity
    MYSQL_RESTORE_PROCESS=$(ps aux | grep -E "(mysql.*db-mpp|simple-restore)" | grep -v grep | wc -l)
    
    # Detect if restore is complete
    RESTORE_STATUS="Running"
    STATUS_COLOR="$YELLOW"
    
    # Check if table count has been stable (not changing)
    if [ "$TABLE_COUNT" -eq "$LAST_TABLE_COUNT" ] && [ "$TABLE_COUNT" -gt 0 ]; then
        ((STABLE_COUNT++))
    else
        STABLE_COUNT=0
        LAST_TABLE_COUNT=$TABLE_COUNT
    fi
    
    # Determine restore status
    if [ "$TABLE_COUNT" -gt 0 ] && [ "$PROCESSES" -eq 0 ] && [ "$MYSQL_RESTORE_PROCESS" -eq 0 ] && [ "$STABLE_COUNT" -ge "$MAX_STABLE_CHECKS" ]; then
        RESTORE_STATUS="Completed"
        STATUS_COLOR="$GREEN"
    elif [ "$TABLE_COUNT" -eq 0 ] && [ "$PROCESSES" -eq 0 ] && [ "$MYSQL_RESTORE_PROCESS" -eq 0 ]; then
        RESTORE_STATUS="Not Started / Failed"
        STATUS_COLOR="$RED"
    elif [ "$MYSQL_RESTORE_PROCESS" -gt 0 ] || [ "$PROCESSES" -gt 0 ]; then
        RESTORE_STATUS="Active"
        STATUS_COLOR="$CYAN"
    elif [ "$TABLE_COUNT" -gt 0 ] && [ "$STABLE_COUNT" -lt "$MAX_STABLE_CHECKS" ]; then
        RESTORE_STATUS="Finalizing"
        STATUS_COLOR="$YELLOW"
    fi
    
    clear
    echo -e "${BLUE}=== MySQL Database Restore Progress Monitor ===${NC}"
    echo -e "${CYAN}Database: $DATABASE_NAME${NC}"
    echo -e "${CYAN}Time: $(date)${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo -e "Tables created: ${YELLOW}$TABLE_COUNT${NC}"
    echo -e "Database size: ${YELLOW}${DB_SIZE} MB${NC}"
    echo -e "Active MySQL processes: ${YELLOW}$PROCESSES${NC}"
    echo -e "Restore processes: ${YELLOW}$MYSQL_RESTORE_PROCESS${NC}"
    echo -e "Status: ${STATUS_COLOR}$RESTORE_STATUS${NC}"
    
    if [ "$RESTORE_STATUS" = "Completed" ]; then
        echo -e "${BLUE}===============================================${NC}"
        echo -e "${GREEN}🎉 RESTORE COMPLETED SUCCESSFULLY! 🎉${NC}"
        echo -e "${GREEN}✅ Total tables: $TABLE_COUNT${NC}"
        echo -e "${GREEN}✅ Database size: ${DB_SIZE} MB${NC}"
        echo -e "${BLUE}===============================================${NC}"
        echo -e "${CYAN}Connection details:${NC}"
        echo -e "  Host: $PROXYSQL_HOST"
        echo -e "  Port: $PROXYSQL_PORT"
        echo -e "  Database: $DATABASE_NAME"
        echo -e "  Username: $MYSQL_USER"
        echo -e "${BLUE}===============================================${NC}"
        echo -e "${CYAN}Test connection:${NC}"
        echo -e "mysql -h $PROXYSQL_HOST -P $PROXYSQL_PORT -u $MYSQL_USER -p $DATABASE_NAME"
        echo -e "${BLUE}===============================================${NC}"
        echo -e "${YELLOW}Press Ctrl+C to exit monitoring${NC}"
        
        # Send notification if available
        if command -v notify-send &> /dev/null; then
            notify-send "MySQL Restore Complete" "Database $DATABASE_NAME restored successfully with $TABLE_COUNT tables"
        fi
        
        # Wait for user to exit
        while true; do
            sleep 10
            echo -e "\n${GREEN}Restore completed at $(date)${NC} - Press Ctrl+C to exit"
        done
        
    elif [ "$RESTORE_STATUS" = "Not Started / Failed" ]; then
        echo -e "${BLUE}===============================================${NC}"
        echo -e "${RED}❌ RESTORE NOT ACTIVE OR FAILED${NC}"
        echo -e "${YELLOW}Suggestions:${NC}"
        echo -e "1. Check if restore script is running"
        echo -e "2. Verify database connectivity"
        echo -e "3. Check for error messages"
        
    else
        echo -e "${BLUE}===============================================${NC}"
        if [ "$STABLE_COUNT" -gt 0 ] && [ "$TABLE_COUNT" -gt 0 ]; then
            if [ "$RESTORE_STATUS" = "Finalizing" ]; then
                echo -e "${YELLOW}🔄 Finalizing restore - stable for ${STABLE_COUNT}/${MAX_STABLE_CHECKS} checks${NC}"
                echo -e "${CYAN}Waiting for all processes to complete...${NC}"
            else
                echo -e "${YELLOW}📊 Active restore - ${STABLE_COUNT} stable checks${NC}"
            fi
        elif [ "$TABLE_COUNT" -eq 0 ]; then
            echo -e "${YELLOW}⏳ Waiting for restore to start creating tables...${NC}"
        else
            echo -e "${YELLOW}🚀 Restore in progress...${NC}"
        fi
    fi
    
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    
    sleep 5
done
