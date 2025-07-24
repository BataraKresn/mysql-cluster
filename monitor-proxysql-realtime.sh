#!/bin/bash

# ============================================================================
# Real-time ProxySQL Activity Monitor for Database Restore
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

# Function to execute ProxySQL admin queries
exec_admin() {
    mysql -h"$PROXYSQL_HOST" -P"$PROXYSQL_ADMIN_PORT" -u"$ADMIN_USER" -p"$ADMIN_PASS" -e "$1" --silent 2>/dev/null
}

echo -e "${BLUE}=== Real-time ProxySQL Activity Monitor ===${NC}"
echo -e "${CYAN}Monitoring restore activity and routing${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo -e "${BLUE}===========================================${NC}"

# Initialize counters for rate calculation
LAST_QUERIES_PRIMARY=0
LAST_QUERIES_REPLICA=0
LAST_BYTES_SENT=0
LAST_BYTES_RECV=0
LAST_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_TIME))
    
    # Get connection pool stats
    POOL_STATS=$(exec_admin "SELECT hostgroup, srv_host, ConnUsed, ConnFree, Queries, Bytes_data_sent, Bytes_data_recv FROM stats_mysql_connection_pool ORDER BY hostgroup;")
    
    # Get global stats
    GLOBAL_STATS=$(exec_admin "SELECT Variable_Name, Variable_Value FROM stats_mysql_global WHERE Variable_Name IN ('Questions', 'Queries_backends_bytes_sent', 'Queries_backends_bytes_recv', 'Client_Connections_connected');")
    
    # Parse stats
    PRIMARY_QUERIES=$(echo "$POOL_STATS" | grep "mysql-primary" | awk '{print $5}' || echo "0")
    REPLICA_QUERIES=$(echo "$POOL_STATS" | grep "mysql-replica" | awk '{print $5}' || echo "0")
    
    PRIMARY_CONN_USED=$(echo "$POOL_STATS" | grep "mysql-primary" | awk '{print $3}' || echo "0")
    PRIMARY_CONN_FREE=$(echo "$POOL_STATS" | grep "mysql-primary" | awk '{print $4}' || echo "0")
    
    REPLICA_CONN_USED=$(echo "$POOL_STATS" | grep "mysql-replica" | awk '{print $3}' || echo "0")
    REPLICA_CONN_FREE=$(echo "$POOL_STATS" | grep "mysql-replica" | awk '{print $4}' || echo "0")
    
    # Get bytes transferred
    TOTAL_BYTES_SENT=$(echo "$GLOBAL_STATS" | grep "Queries_backends_bytes_sent" | awk '{print $2}' || echo "0")
    TOTAL_BYTES_RECV=$(echo "$GLOBAL_STATS" | grep "Queries_backends_bytes_recv" | awk '{print $2}' || echo "0")
    TOTAL_QUESTIONS=$(echo "$GLOBAL_STATS" | grep "Questions" | awk '{print $2}' || echo "0")
    CLIENT_CONNECTIONS=$(echo "$GLOBAL_STATS" | grep "Client_Connections_connected" | awk '{print $2}' || echo "0")
    
    # Calculate rates (per second)
    if [ $TIME_DIFF -gt 0 ] && [ $LAST_TIME -gt 0 ]; then
        QUERIES_RATE_PRIMARY=$(( (PRIMARY_QUERIES - LAST_QUERIES_PRIMARY) / TIME_DIFF ))
        QUERIES_RATE_REPLICA=$(( (REPLICA_QUERIES - LAST_QUERIES_REPLICA) / TIME_DIFF ))
        BYTES_SENT_RATE=$(( (TOTAL_BYTES_SENT - LAST_BYTES_SENT) / TIME_DIFF ))
        BYTES_RECV_RATE=$(( (TOTAL_BYTES_RECV - LAST_BYTES_RECV) / TIME_DIFF ))
    else
        QUERIES_RATE_PRIMARY=0
        QUERIES_RATE_REPLICA=0
        BYTES_SENT_RATE=0
        BYTES_RECV_RATE=0
    fi
    
    clear
    echo -e "${BLUE}=== Real-time ProxySQL Activity Monitor ===${NC}"
    echo -e "${CYAN}Time: $(date)${NC}"
    echo -e "${BLUE}===========================================${NC}"
    
    echo -e "\n${GREEN}🔄 Connection Pool Status:${NC}"
    echo -e "${YELLOW}MySQL Primary (Write):${NC}"
    echo -e "  Connections Used: $PRIMARY_CONN_USED | Free: $PRIMARY_CONN_FREE"
    echo -e "  Total Queries: $PRIMARY_QUERIES | Rate: $QUERIES_RATE_PRIMARY/sec"
    
    echo -e "${YELLOW}MySQL Replica (Read):${NC}"
    echo -e "  Connections Used: $REPLICA_CONN_USED | Free: $REPLICA_CONN_FREE"
    echo -e "  Total Queries: $REPLICA_QUERIES | Rate: $QUERIES_RATE_REPLICA/sec"
    
    echo -e "\n${GREEN}📊 Traffic Statistics:${NC}"
    echo -e "Data Sent: $(numfmt --to=iec $TOTAL_BYTES_SENT) | Rate: $(numfmt --to=iec $BYTES_SENT_RATE)/sec"
    echo -e "Data Recv: $(numfmt --to=iec $TOTAL_BYTES_RECV) | Rate: $(numfmt --to=iec $BYTES_RECV_RATE)/sec"
    echo -e "Total Questions: $TOTAL_QUESTIONS"
    echo -e "Client Connections: $CLIENT_CONNECTIONS"
    
    echo -e "\n${GREEN}📈 Query Distribution:${NC}"
    TOTAL_BACKEND_QUERIES=$((PRIMARY_QUERIES + REPLICA_QUERIES))
    if [ $TOTAL_BACKEND_QUERIES -gt 0 ]; then
        PRIMARY_PCT=$(( PRIMARY_QUERIES * 100 / TOTAL_BACKEND_QUERIES ))
        REPLICA_PCT=$(( REPLICA_QUERIES * 100 / TOTAL_BACKEND_QUERIES ))
        echo -e "Primary (Write): ${PRIMARY_PCT}% | Replica (Read): ${REPLICA_PCT}%"
    else
        echo -e "No queries processed yet"
    fi
    
    # Activity indicator
    echo -e "\n${GREEN}🚀 Current Activity:${NC}"
    if [ $QUERIES_RATE_PRIMARY -gt 0 ]; then
        echo -e "${CYAN}✅ Active restore to Primary: $QUERIES_RATE_PRIMARY queries/sec${NC}"
    else
        echo -e "${YELLOW}⏸️  No active writes to Primary${NC}"
    fi
    
    if [ $QUERIES_RATE_REPLICA -gt 0 ]; then
        echo -e "${CYAN}✅ Active reads from Replica: $QUERIES_RATE_REPLICA queries/sec${NC}"
    else
        echo -e "${YELLOW}⏸️  No active reads from Replica${NC}"
    fi
    
    echo -e "\n${BLUE}===========================================${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop monitoring${NC}"
    
    # Store current values for next iteration
    LAST_QUERIES_PRIMARY=$PRIMARY_QUERIES
    LAST_QUERIES_REPLICA=$REPLICA_QUERIES
    LAST_BYTES_SENT=$TOTAL_BYTES_SENT
    LAST_BYTES_RECV=$TOTAL_BYTES_RECV
    LAST_TIME=$CURRENT_TIME
    
    sleep 3
done
