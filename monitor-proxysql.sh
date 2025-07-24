#!/bin/bash

# ============================================================================
# ProxySQL Monitoring CLI Commands
# ============================================================================
# Script untuk monitoring ProxySQL dan koneksi ke MySQL cluster
# ============================================================================

PROXYSQL_HOST="192.168.11.122"
PROXYSQL_ADMIN_PORT="6032"
ADMIN_USER="superman"
ADMIN_PASS="Soleh1!"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}============================================================================${NC}"
echo -e "${CYAN}ProxySQL Monitoring Dashboard${NC}"
echo -e "${BLUE}============================================================================${NC}"

# Function to execute ProxySQL admin queries
exec_admin() {
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_ADMIN_PORT" -u"$ADMIN_USER" -p"$ADMIN_PASS" -e "$1" 2>/dev/null
}

echo -e "\n${GREEN}📊 1. MySQL Servers Status (Backend Servers)${NC}"
echo -e "${YELLOW}Shows status of MySQL Primary and Replica servers${NC}"
exec_admin "SELECT hostgroup_id as HG, hostname, port, status, weight, max_connections as max_conn FROM mysql_servers ORDER BY hostgroup_id;"

echo -e "\n${GREEN}📈 2. Connection Pool Statistics${NC}"
echo -e "${YELLOW}Shows connection usage for each server${NC}"
exec_admin "SELECT hostgroup, srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, ConnERR, Queries FROM stats_mysql_connection_pool ORDER BY hostgroup;"

echo -e "\n${GREEN}🔀 3. Query Routing Rules${NC}"
echo -e "${YELLOW}Shows how queries are routed to different hostgroups${NC}"
exec_admin "SELECT rule_id, active, match_pattern, destination_hostgroup, apply FROM mysql_query_rules WHERE active=1 ORDER BY rule_id;"

echo -e "\n${GREEN}📊 4. Query Rules Statistics${NC}"
echo -e "${YELLOW}Shows hit count for each routing rule${NC}"
exec_admin "SELECT rule_id, hits FROM stats_mysql_query_rules ORDER BY hits DESC LIMIT 10;"

echo -e "\n${GREEN}🌐 5. Global Connection Statistics${NC}"
echo -e "${YELLOW}Overall ProxySQL performance metrics${NC}"
exec_admin "SELECT Variable_Name, Variable_Value FROM stats_mysql_global WHERE Variable_Name IN ('Client_Connections_created', 'Client_Connections_connected', 'Server_Connections_created', 'Server_Connections_connected', 'Questions', 'Slow_queries') ORDER BY Variable_Name;"

echo -e "\n${GREEN}⚡ 6. Active Commands/Queries${NC}"
echo -e "${YELLOW}Currently executing commands${NC}"
exec_admin "SELECT hostgroup, srv_host, command, info, time_ms FROM stats_mysql_commands_counters WHERE Total_cnt > 0 ORDER BY Total_cnt DESC LIMIT 10;"

echo -e "\n${GREEN}🔍 7. Backend Health Check Status${NC}"
echo -e "${YELLOW}Health monitoring for backend servers${NC}"
exec_admin "SELECT hostname, port, check_type, ping_error, ping_time_us FROM monitor.mysql_server_ping ORDER BY hostname;"

echo -e "\n${GREEN}📡 8. Real-time Traffic (Bytes)${NC}"
echo -e "${YELLOW}Data transfer statistics${NC}"
exec_admin "SELECT Variable_Name, Variable_Value FROM stats_mysql_global WHERE Variable_Name LIKE '%bytes%' ORDER BY Variable_Name;"

echo -e "\n${BLUE}============================================================================${NC}"
echo -e "${CYAN}Individual CLI Commands for Manual Monitoring:${NC}"
echo -e "${BLUE}============================================================================${NC}"

echo -e "\n${YELLOW}# Connect to ProxySQL Admin Interface:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS'"

echo -e "\n${YELLOW}# Check server status:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM mysql_servers;\""

echo -e "\n${YELLOW}# Monitor connection pool:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM stats_mysql_connection_pool;\""

echo -e "\n${YELLOW}# Check query routing:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM mysql_query_rules;\""

echo -e "\n${YELLOW}# Monitor active queries:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM stats_mysql_processlist;\""

echo -e "\n${YELLOW}# Check global statistics:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM stats_mysql_global;\""

echo -e "\n${YELLOW}# Monitor backend health:${NC}"
echo "mysql -h $PROXYSQL_HOST -P $PROXYSQL_ADMIN_PORT -u $ADMIN_USER -p'$ADMIN_PASS' -e \"SELECT * FROM monitor.mysql_server_ping;\""

echo -e "\n${BLUE}============================================================================${NC}"
echo -e "${GREEN}✅ ProxySQL monitoring completed at $(date)${NC}"
echo -e "${BLUE}============================================================================${NC}"
