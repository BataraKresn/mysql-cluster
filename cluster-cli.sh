#!/bin/bash

# MySQL Cluster CLI Documentation & Management Tool
# Comprehensive command-line interface for MySQL Cluster operations

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="mysql-cluster"
PROXYSQL_HOST="127.0.0.1"
PROXYSQL_PORT="6033"
PROXYSQL_ADMIN_PORT="6032"
PROXYSQL_ADMIN_USER="superman"
PROXYSQL_ADMIN_PASS="Soleh1!"
MYSQL_ROOT_PASS="RootPass123!"
APP_USER="appuser"
APP_PASS="AppPass123!"

# Helper functions
print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${WHITE}  MySQL Cluster CLI - $1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo "----------------------------------------"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Main menu
show_main_menu() {
    clear
    print_header "Main Menu"
    echo -e "${WHITE}Select an option:${NC}"
    echo "1.  📊 Cluster Status Overview"
    echo "2.  🔍 ProxySQL Status & Configuration"
    echo "3.  🗄️  MySQL Primary Status"
    echo "4.  🗄️  MySQL Replica Status"
    echo "5.  🔗 Replication Status"
    echo "6.  📈 Performance Monitoring"
    echo "7.  🔧 Cluster Operations"
    echo "8.  🚀 Load Testing"
    echo "9.  �️  GUI Management"
    echo "10. �📚 Documentation"
    echo "11. 🔧 Troubleshooting"
    echo "0.  ❌ Exit"
    echo ""
    read -p "Enter your choice [0-11]: " choice
}

# 1. Cluster Status Overview
cluster_overview() {
    print_header "Cluster Status Overview"
    
    print_section "Container Status"
    docker compose ps
    
    print_section "Network Configuration"
    docker network ls | grep mysql-cluster || print_warning "Custom network not found"
    
    print_section "Quick Health Check"
    
    # Check ProxySQL
    if docker compose exec -T proxysql mysql -h127.0.0.1 -P6033 -u$APP_USER -p$APP_PASS -e "SELECT 'ProxySQL OK' as status;" 2>/dev/null; then
        print_success "ProxySQL is responding"
    else
        print_error "ProxySQL connection failed"
    fi
    
    # Check MySQL Primary
    if docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT 'Primary OK' as status;" 2>/dev/null; then
        print_success "MySQL Primary is responding"
    else
        print_error "MySQL Primary connection failed"
    fi
    
    # Check MySQL Replica
    if docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT 'Replica OK' as status;" 2>/dev/null; then
        print_success "MySQL Replica is responding"
    else
        print_error "MySQL Replica connection failed"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# 2. ProxySQL Status & Configuration
proxysql_status() {
    print_header "ProxySQL Status & Configuration"
    
    print_section "ProxySQL Server Status"
    if docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "SELECT version();" 2>/dev/null; then
        print_success "ProxySQL Admin interface is accessible"
    else
        print_error "Cannot connect to ProxySQL admin interface"
        return 1
    fi
    
    print_section "MySQL Servers Configuration"
    docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
        SELECT 
            hostgroup_id,
            hostname,
            port,
            status,
            weight,
            max_connections
        FROM mysql_servers 
        ORDER BY hostgroup_id, hostname;" 2>/dev/null || print_error "Failed to get server status"
    
    print_section "Connection Pool Statistics"
    docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
        SELECT 
            srv_host,
            srv_port,
            status,
            ConnUsed,
            ConnFree,
            ConnOK,
            ConnERR,
            MaxConnUsed
        FROM stats_mysql_connection_pool 
        ORDER BY srv_host;" 2>/dev/null || print_error "Failed to get connection pool stats"
    
    print_section "Query Rules"
    docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
        SELECT 
            rule_id,
            active,
            match_pattern,
            destination_hostgroup,
            apply
        FROM mysql_query_rules 
        WHERE active=1 
        ORDER BY rule_id;" 2>/dev/null || print_error "Failed to get query rules"
    
    print_section "ProxySQL Users"
    docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
        SELECT 
            username,
            active,
            default_hostgroup,
            max_connections
        FROM mysql_users 
        WHERE active=1;" 2>/dev/null || print_error "Failed to get user configuration"
    
    echo ""
    read -p "Press Enter to continue..."
}

# 3. MySQL Primary Status
mysql_primary_status() {
    print_header "MySQL Primary Status"
    
    if ! docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT 1;" &>/dev/null; then
        print_error "Cannot connect to MySQL Primary"
        return 1
    fi
    
    print_section "Server Information"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SELECT 
            VERSION() as mysql_version,
            @@server_id as server_id,
            @@read_only as read_only,
            @@gtid_mode as gtid_mode;" 2>/dev/null
    
    print_section "Master Status"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW MASTER STATUS;" 2>/dev/null
    
    print_section "Binary Log Status"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW BINARY LOGS;" 2>/dev/null | tail -10
    
    print_section "Database List"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SELECT 
            SCHEMA_NAME as database_name,
            ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as size_mb
        FROM information_schema.SCHEMATA s
        LEFT JOIN information_schema.TABLES t ON s.SCHEMA_NAME = t.TABLE_SCHEMA
        WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
        GROUP BY SCHEMA_NAME
        ORDER BY size_mb DESC;" 2>/dev/null
    
    print_section "Current Connections"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SHOW STATUS LIKE 'Threads_connected';
        SHOW STATUS LIKE 'Max_used_connections';
        SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null
    
    print_section "Recent Error Log (Last 10 lines)"
    docker compose logs mysql-primary 2>/dev/null | tail -10 | grep -i error || print_info "No recent errors found"
    
    echo ""
    read -p "Press Enter to continue..."
}

# 4. MySQL Replica Status
mysql_replica_status() {
    print_header "MySQL Replica Status"
    
    if ! docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT 1;" &>/dev/null; then
        print_error "Cannot connect to MySQL Replica"
        return 1
    fi
    
    print_section "Server Information"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SELECT 
            VERSION() as mysql_version,
            @@server_id as server_id,
            @@read_only as read_only,
            @@gtid_mode as gtid_mode;" 2>/dev/null
    
    print_section "Slave Status"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null
    
    print_section "Replication Lag"
    local lag=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    if [ "$lag" = "0" ]; then
        print_success "Replication is up to date (lag: 0 seconds)"
    elif [ "$lag" = "NULL" ]; then
        print_error "Replication is not running"
    else
        print_warning "Replication lag: $lag seconds"
    fi
    
    print_section "Database List"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SELECT 
            SCHEMA_NAME as database_name,
            ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) as size_mb
        FROM information_schema.SCHEMATA s
        LEFT JOIN information_schema.TABLES t ON s.SCHEMA_NAME = t.TABLE_SCHEMA
        WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
        GROUP BY SCHEMA_NAME
        ORDER BY size_mb DESC;" 2>/dev/null
    
    print_section "Recent Error Log (Last 10 lines)"
    docker compose logs mysql-replica 2>/dev/null | tail -10 | grep -i error || print_info "No recent errors found"
    
    echo ""
    read -p "Press Enter to continue..."
}

# 5. Replication Status
replication_status() {
    print_header "Replication Status"
    
    print_section "GTID Status"
    echo "Primary GTID Executed:"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT @@gtid_executed;" 2>/dev/null
    
    echo -e "\nReplica GTID Executed:"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT @@gtid_executed;" 2>/dev/null
    
    print_section "Detailed Replication Status"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SHOW SLAVE STATUS\G;" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error|Master_Host|Master_Port|Auto_Position)"
    
    print_section "Replication Health Check"
    local io_running=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null | grep "Slave_IO_Running" | awk '{print $2}')
    local sql_running=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null | grep "Slave_SQL_Running" | awk '{print $2}')
    local lag=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    
    if [ "$io_running" = "Yes" ] && [ "$sql_running" = "Yes" ]; then
        if [ "$lag" = "0" ]; then
            print_success "Replication is healthy and up to date"
        elif [ "$lag" = "NULL" ]; then
            print_warning "Replication lag is NULL (check configuration)"
        else
            print_warning "Replication is working but has lag: $lag seconds"
        fi
    else
        print_error "Replication is not working properly"
        echo "IO Running: $io_running"
        echo "SQL Running: $sql_running"
    fi
    
    print_section "Test Replication"
    echo "Creating test table on Primary..."
    local test_table="replication_test_$(date +%s)"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        USE appdb;
        CREATE TABLE IF NOT EXISTS $test_table (id INT PRIMARY KEY, test_data VARCHAR(50));
        INSERT INTO $test_table VALUES (1, 'Replication test at $(date)');
        SELECT COUNT(*) as primary_count FROM $test_table;" 2>/dev/null
    
    sleep 2
    
    echo -e "\nChecking replication on Replica..."
    local replica_count=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "USE appdb; SELECT COUNT(*) FROM $test_table;" 2>/dev/null | tail -1)
    
    if [ "$replica_count" = "1" ]; then
        print_success "Replication test passed - data replicated successfully"
    else
        print_error "Replication test failed - data not found on replica"
    fi
    
    # Cleanup
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "USE appdb; DROP TABLE IF EXISTS $test_table;" 2>/dev/null
    
    echo ""
    read -p "Press Enter to continue..."
}

# 6. Performance Monitoring
performance_monitoring() {
    print_header "Performance Monitoring"
    
    print_section "System Resources"
    echo "Memory Usage:"
    free -h
    echo -e "\nDisk Usage:"
    df -h | head -5
    echo -e "\nCPU Usage:"
    top -bn1 | grep "Cpu(s)" || uptime
    
    print_section "Docker Container Resources"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    print_section "MySQL Performance Metrics - Primary"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SHOW STATUS LIKE 'Queries';
        SHOW STATUS LIKE 'Questions';
        SHOW STATUS LIKE 'Slow_queries';
        SHOW STATUS LIKE 'Threads_connected';
        SHOW STATUS LIKE 'Innodb_buffer_pool_read_requests';
        SHOW STATUS LIKE 'Innodb_buffer_pool_reads';" 2>/dev/null
    
    print_section "MySQL Performance Metrics - Replica"
    docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SHOW STATUS LIKE 'Queries';
        SHOW STATUS LIKE 'Questions';
        SHOW STATUS LIKE 'Slow_queries';
        SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null
    
    print_section "ProxySQL Query Statistics"
    docker compose exec -T proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "
        SELECT 
            hostgroup,
            sum_time,
            count_star,
            avg_time,
            digest_text
        FROM stats_mysql_query_digest 
        ORDER BY count_star DESC 
        LIMIT 10;" 2>/dev/null || print_warning "ProxySQL stats not available"
    
    print_section "Top 5 Slowest Queries (Primary)"
    docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "
        SELECT 
            TRUNCATE(TIMER_WAIT/1000000000000,6) as Duration,
            SQL_TEXT
        FROM performance_schema.events_statements_history_long 
        WHERE SQL_TEXT NOT LIKE '%performance_schema%'
        ORDER BY TIMER_WAIT DESC 
        LIMIT 5;" 2>/dev/null || print_info "Performance schema data not available"
    
    echo ""
    read -p "Press Enter to continue..."
}

# 7. Cluster Operations
cluster_operations() {
    print_header "Cluster Operations"
    
    echo "Select operation:"
    echo "1. 🚀 Start Cluster"
    echo "2. ⏹️  Stop Cluster"
    echo "3. 🔄 Restart Cluster"
    echo "4. 📊 View Logs"
    echo "5. 🧹 Clean Restart"
    echo "6. 💾 Backup Database"
    echo "7. 🔄 Reset Replication"
    echo "0. ← Back to Main Menu"
    
    read -p "Enter your choice [0-7]: " op_choice
    
    case $op_choice in
        1)
            print_info "Starting cluster..."
            docker compose up -d
            print_success "Cluster start command executed"
            ;;
        2)
            print_info "Stopping cluster..."
            docker compose down
            print_success "Cluster stopped"
            ;;
        3)
            print_info "Restarting cluster..."
            docker compose restart
            print_success "Cluster restart command executed"
            ;;
        4)
            echo "Select service logs:"
            echo "1. All services"
            echo "2. ProxySQL"
            echo "3. MySQL Primary"
            echo "4. MySQL Replica"
            read -p "Enter choice [1-4]: " log_choice
            
            case $log_choice in
                1) docker compose logs -f ;;
                2) docker compose logs -f proxysql ;;
                3) docker compose logs -f mysql-primary ;;
                4) docker compose logs -f mysql-replica ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        5)
            read -p "This will delete all data. Are you sure? (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                print_info "Performing clean restart..."
                ./clean-restart.sh
                print_success "Clean restart completed"
            else
                print_info "Operation cancelled"
            fi
            ;;
        6)
            print_info "Creating backup..."
            ./backup.sh
            print_success "Backup completed"
            ;;
        7)
            print_info "Resetting replication..."
            docker compose exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "STOP SLAVE; RESET SLAVE ALL;"
            print_info "Please run deploy.sh to reconfigure replication"
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# 8. Load Testing
load_testing() {
    print_header "Load Testing"
    
    echo "Select load test type:"
    echo "1. 🔥 Quick Test (100 connections, 60 seconds)"
    echo "2. 💪 Standard Test (500 connections, 300 seconds)"
    echo "3. 🚀 Heavy Test (1000 connections, 600 seconds)"
    echo "4. 🏆 Maximum Test (1500 connections, 600 seconds)"
    echo "5. 📊 Custom Test"
    echo "0. ← Back to Main Menu"
    
    read -p "Enter your choice [0-5]: " test_choice
    
    case $test_choice in
        1)
            run_load_test 100 60 "Quick Test"
            ;;
        2)
            run_load_test 500 300 "Standard Test"
            ;;
        3)
            run_load_test 1000 600 "Heavy Test"
            ;;
        4)
            run_load_test 1500 600 "Maximum Test"
            ;;
        5)
            read -p "Enter number of connections: " connections
            read -p "Enter duration in seconds: " duration
            run_load_test $connections $duration "Custom Test"
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

run_load_test() {
    local connections=$1
    local duration=$2
    local test_name=$3
    
    print_info "Running $test_name ($connections connections, ${duration}s duration)..."
    
    # Prepare test
    docker compose exec -T proxysql sysbench oltp_read_write \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=$APP_USER \
        --mysql-password=$APP_PASS \
        --mysql-db=appdb \
        --tables=4 \
        --table_size=10000 \
        --threads=$connections \
        prepare 2>/dev/null && print_success "Test data prepared"
    
    # Run test
    print_info "Starting load test..."
    docker compose exec -T proxysql sysbench oltp_read_write \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=$APP_USER \
        --mysql-password=$APP_PASS \
        --mysql-db=appdb \
        --tables=4 \
        --table_size=10000 \
        --threads=$connections \
        --time=$duration \
        --report-interval=10 \
        run
    
    # Cleanup
    docker compose exec -T proxysql sysbench oltp_read_write \
        --mysql-host=127.0.0.1 \
        --mysql-port=6033 \
        --mysql-user=$APP_USER \
        --mysql-password=$APP_PASS \
        --mysql-db=appdb \
        --tables=4 \
        cleanup 2>/dev/null && print_success "Test data cleaned up"
}

# 9. GUI Management
gui_management() {
    print_header "GUI Management Interfaces"
    
    echo "Available GUI tools:"
    echo "1. 🎛️  Open ProxySQL Web UI"
    echo "2. 🌐 Open Custom Dashboard"
    echo "3. � Open ProxySQL Admin (MySQL CLI)"
    echo "4. 📋 Show All GUI URLs"
    echo "5. 🔍 Check GUI Services Status"
    echo "0. ← Back to Main Menu"
    
    read -p "Enter your choice [0-5]: " gui_choice
    
    case $gui_choice in
        1)
            print_info "Opening ProxySQL Web UI..."
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://192.168.11.122:8080"
            elif command -v open &> /dev/null; then
                open "http://192.168.11.122:8080"
            else
                print_info "ProxySQL Web UI: http://192.168.11.122:8080"
            fi
            ;;
        2)
            print_info "Opening Custom Dashboard..."
            if command -v xdg-open &> /dev/null; then
                xdg-open "http://192.168.11.122:8082"
            elif command -v open &> /dev/null; then
                open "http://192.168.11.122:8082"
            else
                print_info "Custom Dashboard: http://192.168.11.122:8082"
            fi
            ;;
        3)
            print_info "Opening ProxySQL Admin interface..."
            print_info "Use this command to connect to ProxySQL Admin:"
            echo "mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1!"
            ;;
        4)
            print_section "All GUI URLs"
            echo "🎛️  ProxySQL Web UI:    http://192.168.11.122:8080"
            echo "🌐 Custom Dashboard:   http://192.168.11.122:8082"
            echo "� ProxySQL Admin:     mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1!"
            echo "� Application Port:   mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123!"
            ;;
        5)
            print_section "GUI Services Status"
            
            # Check ProxySQL Web
            if docker compose ps | grep -q "proxysql-web.*Up"; then
                print_success "ProxySQL Web UI is running"
            else
                print_error "ProxySQL Web UI is not running"
            fi
            
            # Check Custom Dashboard
            if docker compose ps | grep -q "web-dashboard.*Up"; then
                print_success "Custom Dashboard is running"
            else
                print_error "Custom Dashboard is not running"
            fi
            
            # Check ProxySQL
            if docker compose ps | grep -q "proxysql.*Up"; then
                print_success "ProxySQL is running"
            else
                print_error "ProxySQL is not running"
            fi
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# 10. Documentation
show_documentation() {
    print_header "Documentation"
    
    echo "Available documentation:"
    echo "1. 📖 README.md - Main project overview"
    echo "2. 🚀 DEPLOYMENT.md - Step-by-step deployment"
    echo "3. 🚀 DEPLOYMENT-UPDATED.md - Comprehensive deployment guide"
    echo "4. ⚡ LARAVEL-INTEGRATION.md - Laravel framework integration"
    echo "5. 🔧 PRODUCTION-OPS.md - Production operations"
    echo "6. 📚 DOCUMENTATION-INDEX.md - Complete documentation index"
    echo "7. 🌐 Open documentation in browser"
    echo "0. ← Back to Main Menu"
    
    read -p "Enter your choice [0-7]: " doc_choice
    
    case $doc_choice in
        1) less README.md ;;
        2) less DEPLOYMENT.md ;;
        3) less DEPLOYMENT-UPDATED.md ;;
        4) less LARAVEL-INTEGRATION.md ;;
        5) less PRODUCTION-OPS.md ;;
        6) less DOCUMENTATION-INDEX.md ;;
        7)
            if command -v xdg-open &> /dev/null; then
                xdg-open README.md
            elif command -v open &> /dev/null; then
                open README.md
            else
                print_warning "Cannot open browser. Use 'cat' or 'less' to view files."
            fi
            ;;
        0) return ;;
        *) print_error "Invalid choice" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# 10. Troubleshooting
troubleshooting() {
    print_header "Troubleshooting"
    
    echo "Select troubleshooting action:"
    echo "1. 🔍 Run Full Diagnostic"
    echo "2. 🔧 Fix ProxySQL Routing"
    echo "3. 🔄 Fix Replication Issues"
    echo "4. 🌐 Test Network Connectivity"
    echo "5. 📊 Check Resource Usage"
    echo "6. 🔍 Analyze Error Logs"
    echo "7. 🧹 Clean Up Resources"
    echo "0. ← Back to Main Menu"
    
    read -p "Enter your choice [0-7]: " trouble_choice
    
    case $trouble_choice in
        1)
            run_full_diagnostic
            ;;
        2)
            fix_proxysql_routing
            ;;
        3)
            fix_replication
            ;;
        4)
            test_network_connectivity
            ;;
        5)
            check_resource_usage
            ;;
        6)
            analyze_error_logs
            ;;
        7)
            cleanup_resources
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

run_full_diagnostic() {
    print_info "Running full diagnostic..."
    
    # Check containers
    print_section "Container Status"
    docker compose ps
    
    # Check connectivity
    print_section "Connectivity Test"
    test_network_connectivity
    
    # Check logs for errors
    print_section "Error Analysis"
    analyze_error_logs
    
    # Check resources
    print_section "Resource Usage"
    check_resource_usage
    
    print_success "Full diagnostic completed"
}

fix_proxysql_routing() {
    print_info "Fixing ProxySQL routing..."
    
    docker compose exec proxysql mysql -h127.0.0.1 -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS << 'EOF'
DELETE FROM mysql_servers;
INSERT INTO mysql_servers(hostgroup_id, hostname, port, weight, max_connections) VALUES
(0, 'mysql-primary', 3306, 1000, 2000),
(1, 'mysql-replica', 3306, 1000, 2000);

DELETE FROM mysql_query_rules;
INSERT INTO mysql_query_rules(rule_id, active, match_pattern, destination_hostgroup, apply) VALUES
(1, 1, '^SELECT.*', 1, 1),
(2, 1, '^INSERT|UPDATE|DELETE.*', 0, 1);

LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
EOF

    print_success "ProxySQL routing rules updated"
}

fix_replication() {
    print_info "Fixing replication..."
    
    # Stop slave
    docker compose exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "STOP SLAVE;"
    
    # Reset slave
    docker compose exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "RESET SLAVE ALL;"
    
    # Get master position
    master_file=$(docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW MASTER STATUS\G" | grep "File:" | awk '{print $2}')
    master_pos=$(docker compose exec -T mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW MASTER STATUS\G" | grep "Position:" | awk '{print $2}')
    
    # Configure replication
    docker compose exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "
        CHANGE MASTER TO
        MASTER_HOST='mysql-primary',
        MASTER_USER='replicator',
        MASTER_PASSWORD='ReplPass123!',
        MASTER_AUTO_POSITION=1;
        START SLAVE;"
    
    print_success "Replication configuration updated"
}

test_network_connectivity() {
    print_info "Testing network connectivity..."
    
    # Test ProxySQL
    if docker compose exec -T proxysql ping -c 2 mysql-primary &>/dev/null; then
        print_success "ProxySQL can reach MySQL Primary"
    else
        print_error "ProxySQL cannot reach MySQL Primary"
    fi
    
    if docker compose exec -T proxysql ping -c 2 mysql-replica &>/dev/null; then
        print_success "ProxySQL can reach MySQL Replica"
    else
        print_error "ProxySQL cannot reach MySQL Replica"
    fi
    
    # Test database connections
    if docker compose exec -T proxysql mysql -hmysql-primary -P3306 -uroot -p$MYSQL_ROOT_PASS -e "SELECT 1;" &>/dev/null; then
        print_success "Database connection to Primary works"
    else
        print_error "Database connection to Primary failed"
    fi
    
    if docker compose exec -T proxysql mysql -hmysql-replica -P3306 -uroot -p$MYSQL_ROOT_PASS -e "SELECT 1;" &>/dev/null; then
        print_success "Database connection to Replica works"
    else
        print_error "Database connection to Replica failed"
    fi
}

check_resource_usage() {
    print_info "Checking resource usage..."
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ $mem_usage -gt 90 ]; then
        print_error "High memory usage: ${mem_usage}%"
    elif [ $mem_usage -gt 75 ]; then
        print_warning "Moderate memory usage: ${mem_usage}%"
    else
        print_success "Memory usage is normal: ${mem_usage}%"
    fi
    
    # Disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $disk_usage -gt 90 ]; then
        print_error "High disk usage: ${disk_usage}%"
    elif [ $disk_usage -gt 75 ]; then
        print_warning "Moderate disk usage: ${disk_usage}%"
    else
        print_success "Disk usage is normal: ${disk_usage}%"
    fi
    
    # Container resource usage
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

analyze_error_logs() {
    print_info "Analyzing error logs..."
    
    print_section "ProxySQL Errors"
    docker compose logs proxysql 2>&1 | grep -i error | tail -5 || print_info "No ProxySQL errors found"
    
    print_section "MySQL Primary Errors"
    docker compose logs mysql-primary 2>&1 | grep -i error | tail -5 || print_info "No MySQL Primary errors found"
    
    print_section "MySQL Replica Errors"
    docker compose logs mysql-replica 2>&1 | grep -i error | tail -5 || print_info "No MySQL Replica errors found"
}

cleanup_resources() {
    print_info "Cleaning up resources..."
    
    # Remove unused containers
    docker container prune -f
    
    # Remove unused images
    docker image prune -f
    
    # Remove unused volumes (be careful!)
    read -p "Remove unused volumes? This may delete data! (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        docker volume prune -f
    fi
    
    # Remove unused networks
    docker network prune -f
    
    print_success "Resource cleanup completed"
}

# Help function
show_help() {
    print_header "Help & Usage"
    
    echo "MySQL Cluster CLI Tool"
    echo "======================"
    echo ""
    echo "This tool provides a comprehensive interface for managing and monitoring"
    echo "your MySQL Cluster with ProxySQL load balancing."
    echo ""
    echo "Features:"
    echo "• Cluster status overview and monitoring"
    echo "• ProxySQL configuration and statistics"
    echo "• MySQL Primary and Replica status checking"
    echo "• Replication monitoring and testing"
    echo "• Performance monitoring and metrics"
    echo "• Load testing with various scenarios"
    echo "• Troubleshooting and diagnostic tools"
    echo "• Documentation access"
    echo ""
    echo "Usage:"
    echo "  ./cluster-cli.sh           # Interactive mode"
    echo "  ./cluster-cli.sh --help    # Show this help"
    echo "  ./cluster-cli.sh status    # Quick status check"
    echo ""
    echo "Requirements:"
    echo "• Docker and Docker Compose"
    echo "• MySQL client tools"
    echo "• Proper cluster configuration"
    echo ""
}

# Quick status check
quick_status() {
    print_header "Quick Status Check"
    
    # Check if containers are running
    if ! docker compose ps | grep -q "Up"; then
        print_error "Cluster is not running. Use 'docker compose up -d' to start."
        return 1
    fi
    
    # Quick connectivity test
    if docker compose exec -T proxysql mysql -h127.0.0.1 -P6033 -u$APP_USER -p$APP_PASS -e "SELECT 'OK';" &>/dev/null; then
        print_success "Cluster is running and accessible"
    else
        print_error "Cluster is running but not accessible"
    fi
    
    # Quick replication check
    local lag=$(docker compose exec -T mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G;" 2>/dev/null | grep "Seconds_Behind_Master" | awk '{print $2}')
    if [ "$lag" = "0" ]; then
        print_success "Replication is healthy"
    elif [ "$lag" = "NULL" ]; then
        print_error "Replication is not working"
    else
        print_warning "Replication lag: $lag seconds"
    fi
}

# Main execution
main() {
    case "${1:-interactive}" in
        --help|-h)
            show_help
            ;;
        status)
            quick_status
            ;;
        interactive|"")
            while true; do
                show_main_menu
                case $choice in
                    1) cluster_overview ;;
                    2) proxysql_status ;;
                    3) mysql_primary_status ;;
                    4) mysql_replica_status ;;
                    5) replication_status ;;
                    6) performance_monitoring ;;
                    7) cluster_operations ;;
                    8) load_testing ;;
                    9) gui_management ;;
                    10) show_documentation ;;
                    11) troubleshooting ;;
                    0)
                        print_info "Thank you for using MySQL Cluster CLI!"
                        exit 0
                        ;;
                    *)
                        print_error "Invalid option. Please try again."
                        sleep 2
                        ;;
                esac
            done
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run this script from the cluster directory."
    exit 1
fi

# Run main function
main "$@"
