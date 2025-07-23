#!/bin/bash
# Real-time monitoring script for load testing
# Usage: ./monitor_loadtest.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PROXYSQL_ADMIN_USER="superman"
PROXYSQL_ADMIN_PASS="Soleh1!"
MYSQL_ROOT_PASS="2fF2P7xqVtc4iCExR"
INTERVAL=5

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  MySQL Cluster Load Test Monitor${NC}"
echo -e "${BLUE}=====================================${NC}"
echo "Monitoring interval: ${INTERVAL} seconds"
echo "Press Ctrl+C to stop monitoring"
echo

# Function to get metrics
get_metrics() {
    echo -e "${YELLOW}[$(date)] Cluster Metrics:${NC}"
    
    # ProxySQL Connection Pool
    echo -e "${CYAN}ProxySQL Connection Pool:${NC}"
    mysql -h127.0.0.1 -P6032 -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
    SELECT 
        CONCAT(srv_host, ':', srv_port) as Server,
        hostgroup as HG,
        status as Status,
        ConnUsed as Used,
        ConnFree as Free,
        ConnOK as OK,
        ConnERR as Error,
        Queries as Queries,
        ROUND(Bytes_data_sent/1024/1024, 2) as 'Sent_MB',
        ROUND(Bytes_data_recv/1024/1024, 2) as 'Recv_MB'
    FROM stats_mysql_connection_pool 
    ORDER BY hostgroup;" 2>/dev/null || echo "Failed to get ProxySQL stats"
    
    echo
    
    # MySQL Primary Status
    echo -e "${CYAN}MySQL Primary Status:${NC}"
    mysql -h127.0.0.1 -P3306 -uroot -p$MYSQL_ROOT_PASS -e "
    SELECT 
        'Threads_connected' as Metric, 
        VARIABLE_VALUE as Value 
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME='Threads_connected'
    UNION ALL
    SELECT 
        'Questions', 
        VARIABLE_VALUE 
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME='Questions'
    UNION ALL
    SELECT 
        'Com_select', 
        VARIABLE_VALUE 
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME='Com_select'
    UNION ALL
    SELECT 
        'Com_insert', 
        VARIABLE_VALUE 
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME='Com_insert'
    UNION ALL
    SELECT 
        'Com_update', 
        VARIABLE_VALUE 
    FROM information_schema.GLOBAL_STATUS 
    WHERE VARIABLE_NAME='Com_update';" 2>/dev/null || echo "Failed to get MySQL Primary stats"
    
    echo
    
    # Replication Status
    echo -e "${CYAN}Replication Status:${NC}"
    docker exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
    SELECT 
        'IO_Running' as Metric,
        Slave_IO_Running as Value
    FROM (SHOW SLAVE STATUS) as ss
    UNION ALL
    SELECT 
        'SQL_Running',
        Slave_SQL_Running
    FROM (SHOW SLAVE STATUS) as ss
    UNION ALL
    SELECT 
        'Seconds_Behind',
        IFNULL(Seconds_Behind_Master, 'NULL')
    FROM (SHOW SLAVE STATUS) as ss;" 2>/dev/null || echo "Failed to get replication status"
    
    echo
    
    # System Resources
    echo -e "${CYAN}Container Resources:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"
    
    echo -e "${BLUE}=====================================${NC}"
    echo
}

# Trap Ctrl+C
trap 'echo -e "\n${YELLOW}Monitoring stopped by user${NC}"; exit 0' INT

# Main monitoring loop
while true; do
    get_metrics
    sleep $INTERVAL
done
