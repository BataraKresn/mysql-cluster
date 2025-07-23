#!/bin/bash
# MySQL Cluster Health Check Script
# Usage: ./health_check.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYSQL_ROOT_PASS="2fF2P7xqVtc4iCExR"
PROXYSQL_ADMIN_USER="superman"
PROXYSQL_ADMIN_PASS="Soleh1!"

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}     MySQL Cluster Health Check${NC}"
echo -e "${BLUE}===========================================${NC}"
echo "Date: $(date)"
echo "Location: $SCRIPT_DIR"
echo

# Function to check if container is running
check_container() {
    local container_name=$1
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^$container_name"; then
        echo -e "${GREEN}✓${NC} $container_name is running"
        return 0
    else
        echo -e "${RED}✗${NC} $container_name is not running"
        return 1
    fi
}

# Function to execute MySQL command
mysql_exec() {
    local container=$1
    local command=$2
    docker exec $container mysql -uroot -p$MYSQL_ROOT_PASS -e "$command" 2>/dev/null
}

# Function to execute ProxySQL command
proxysql_exec() {
    local command=$1
    docker exec proxysql mysql -h127.0.0.1 -P6032 -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "$command" 2>/dev/null
}

echo -e "${YELLOW}1. Container Status Check${NC}"
echo "----------------------------------------"

# Check all containers
container_status=0
check_container "mysql-primary" || container_status=1
check_container "mysql-replica" || container_status=1  
check_container "proxysql" || container_status=1

echo

echo -e "${YELLOW}2. MySQL Connectivity Check${NC}"
echo "----------------------------------------"

# Test MySQL connections
if mysql_exec mysql-primary "SELECT 'MySQL Primary OK' as status;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} MySQL Primary connection OK"
else
    echo -e "${RED}✗${NC} MySQL Primary connection FAILED"
    container_status=1
fi

if mysql_exec mysql-replica "SELECT 'MySQL Replica OK' as status;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} MySQL Replica connection OK"
else
    echo -e "${RED}✗${NC} MySQL Replica connection FAILED"  
    container_status=1
fi

# Test ProxySQL connection
if proxysql_exec "SELECT 'ProxySQL OK' as status;" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} ProxySQL Admin connection OK"
else
    echo -e "${RED}✗${NC} ProxySQL Admin connection FAILED"
    container_status=1
fi

echo

echo -e "${YELLOW}3. Replication Status Check${NC}"
echo "----------------------------------------"

# Check replication status
repl_status=$(mysql_exec mysql-replica "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)" || echo "")

if echo "$repl_status" | grep -q "Slave_IO_Running: Yes"; then
    echo -e "${GREEN}✓${NC} Slave IO Thread running"
else
    echo -e "${RED}✗${NC} Slave IO Thread NOT running"
    container_status=1
fi

if echo "$repl_status" | grep -q "Slave_SQL_Running: Yes"; then
    echo -e "${GREEN}✓${NC} Slave SQL Thread running"
else
    echo -e "${RED}✗${NC} Slave SQL Thread NOT running"
    container_status=1
fi

# Check replication lag
lag=$(echo "$repl_status" | grep "Seconds_Behind_Master" | awk '{print $2}')
if [[ "$lag" =~ ^[0-9]+$ ]]; then
    if [ "$lag" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Replication lag: ${lag} seconds"
    elif [ "$lag" -le 10 ]; then
        echo -e "${YELLOW}⚠${NC} Replication lag: ${lag} seconds (Warning)"
    else
        echo -e "${RED}✗${NC} Replication lag: ${lag} seconds (Critical)"
        container_status=1
    fi
else
    echo -e "${RED}✗${NC} Cannot determine replication lag"
    container_status=1
fi

echo

echo -e "${YELLOW}4. ProxySQL Server Status${NC}"
echo "----------------------------------------"

# Check ProxySQL server status
proxysql_servers=$(proxysql_exec "SELECT hostgroup,srv_host,srv_port,status,weight FROM mysql_servers;" 2>/dev/null || echo "")

if [ -n "$proxysql_servers" ]; then
    echo "$proxysql_servers"
    
    # Check if servers are ONLINE
    if echo "$proxysql_servers" | grep -q "ONLINE"; then
        echo -e "${GREEN}✓${NC} ProxySQL servers are ONLINE"
    else
        echo -e "${RED}✗${NC} Some ProxySQL servers are OFFLINE"
        container_status=1
    fi
else
    echo -e "${RED}✗${NC} Cannot retrieve ProxySQL server status"
    container_status=1
fi

echo

echo -e "${YELLOW}5. Connection Count Check${NC}"
echo "----------------------------------------"

# Check connection counts
primary_conn=$(mysql_exec mysql-primary "SHOW STATUS LIKE 'Threads_connected';" | tail -1 | awk '{print $2}' 2>/dev/null || echo "0")
replica_conn=$(mysql_exec mysql-replica "SHOW STATUS LIKE 'Threads_connected';" | tail -1 | awk '{print $2}' 2>/dev/null || echo "0")

echo "Primary connections: $primary_conn"
echo "Replica connections: $replica_conn"

# Check if connection count is within limits
if [ "$primary_conn" -gt 1500 ]; then
    echo -e "${YELLOW}⚠${NC} Primary connection count is high: $primary_conn"
elif [ "$primary_conn" -gt 1800 ]; then
    echo -e "${RED}✗${NC} Primary connection count is critical: $primary_conn"
    container_status=1
else
    echo -e "${GREEN}✓${NC} Primary connection count is normal"
fi

echo

echo -e "${YELLOW}6. Disk Space Check${NC}"
echo "----------------------------------------"

# Check disk space for data directories
primary_data_size=$(du -sh primary-data 2>/dev/null | cut -f1)
replica_data_size=$(du -sh replicat-data 2>/dev/null | cut -f1)
disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Primary data size: $primary_data_size"
echo "Replica data size: $replica_data_size"
echo "Disk usage: $disk_usage%"

if [ "$disk_usage" -gt 90 ]; then
    echo -e "${RED}✗${NC} Disk usage is critical: $disk_usage%"
    container_status=1
elif [ "$disk_usage" -gt 80 ]; then
    echo -e "${YELLOW}⚠${NC} Disk usage is high: $disk_usage%"
else
    echo -e "${GREEN}✓${NC} Disk usage is normal: $disk_usage%"
fi

echo

echo -e "${YELLOW}7. Performance Metrics${NC}"
echo "----------------------------------------"

# Check buffer pool hit ratio
hit_ratio=$(mysql_exec mysql-primary "
SELECT ROUND((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') - (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_reads')) / (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') * 100, 2) AS hit_ratio;" 2>/dev/null | tail -1)

echo "InnoDB Buffer Pool Hit Ratio: $hit_ratio%"

if (( $(echo "$hit_ratio < 95" | bc -l) )); then
    echo -e "${YELLOW}⚠${NC} Buffer pool hit ratio is low: $hit_ratio%"
else
    echo -e "${GREEN}✓${NC} Buffer pool hit ratio is good: $hit_ratio%"
fi

# Check slow queries
slow_queries=$(mysql_exec mysql-primary "SHOW STATUS LIKE 'Slow_queries';" | tail -1 | awk '{print $2}' 2>/dev/null || echo "0")
echo "Slow queries: $slow_queries"

echo

echo -e "${YELLOW}8. Docker Resource Usage${NC}"
echo "----------------------------------------"
docker stats --no-stream mysql-primary mysql-replica proxysql --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

echo
echo -e "${BLUE}===========================================${NC}"

# Final status
if [ $container_status -eq 0 ]; then
    echo -e "${GREEN}✅ Overall Status: HEALTHY${NC}"
    exit 0
else
    echo -e "${RED}❌ Overall Status: ISSUES DETECTED${NC}"
    echo -e "${YELLOW}Please check the issues above and take corrective action.${NC}"
    exit 1
fi
