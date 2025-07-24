#!/bin/bash
# MySQL Cluster Deployment & Load Testing Script
# Usage: ./deploy.sh [deploy|test|full]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MYSQL_ROOT_PASS="2fF2P7xqVtc4iCExR"
MYSQL_APP_USER="appuser"
MYSQL_APP_PASS="AppPass123!"
PROXYSQL_ADMIN_USER="superman"
PROXYSQL_ADMIN_PASS="Soleh1!"

# ProxySQL connection details
PROXYSQL_HOST="192.168.11.122"  # IP host server agar bisa diakses dari server lain
PROXYSQL_PORT="6033"
PROXYSQL_ADMIN_PORT="6032"

# Load test configuration
MIN_USERS=1500
MAX_USERS=2000
TEST_DURATION=300  # 5 minutes
READ_WRITE_RATIO="70:30"  # 70% read, 30% write

# Logging
LOG_DIR="$SCRIPT_DIR/logs"
DEPLOY_LOG="$LOG_DIR/deploy_$(date +%Y%m%d_%H%M%S).log"
TEST_LOG="$LOG_DIR/loadtest_$(date +%Y%m%d_%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}     MySQL Cluster Deployment & Load Test${NC}"
echo -e "${BLUE}================================================${NC}"
echo "Date: $(date)"
echo "Script Directory: $SCRIPT_DIR"
echo "Log Directory: $LOG_DIR"
echo

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$DEPLOY_LOG"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if docker compose works
docker_compose_exists() {
    docker compose version >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local service_name=$1
    local host=$2
    local port=$3
    local max_attempts=60
    local attempt=1

    log "Waiting for $service_name to be ready on $host:$port..."
    
    while [ $attempt -le $max_attempts ]; do
        if timeout 1 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            log "✓ $service_name is ready"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log "✗ $service_name failed to start within $(($max_attempts * 2)) seconds"
    return 1
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Docker
    if ! command_exists docker; then
        log "✗ Docker is not installed"
        exit 1
    fi
    log "✓ Docker is available: $(docker --version)"
    
    # Check Docker Compose
    if docker_compose_exists; then
        DOCKER_COMPOSE="docker compose"
        log "✓ Docker Compose is available (v2)"
    elif command_exists docker-compose; then
        DOCKER_COMPOSE="docker-compose"
        log "✓ Docker Compose is available (v1 - legacy)"
    else
        log "✗ Docker Compose is not installed"
        log "Please install Docker Compose v2 or legacy docker-compose"
        exit 1
    fi
    
    # Check MySQL client
    if ! command_exists mysql; then
        log "⚠ MySQL client not found. Installing..."
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y mysql-client
        elif command_exists yum; then
            sudo yum install -y mysql
        elif command_exists dnf; then
            sudo dnf install -y mysql
        else
            log "✗ Cannot install MySQL client automatically"
            exit 1
        fi
    fi
    log "✓ MySQL client is available"
    
    # Check sysbench for load testing
    if ! command_exists sysbench; then
        log "⚠ sysbench not found. Installing..."
        if command_exists apt-get; then
            sudo apt-get update && sudo apt-get install -y sysbench
        elif command_exists yum; then
            sudo yum install -y sysbench
        elif command_exists dnf; then
            sudo dnf install -y sysbench
        else
            log "✗ Cannot install sysbench automatically"
            exit 1
        fi
    fi
    log "✓ sysbench is available: $(sysbench --version)"
    
    # Check available memory
    AVAILABLE_MEM=$(free -m | awk 'NR==2{print $7}')
    if [ "$AVAILABLE_MEM" -lt 4000 ]; then
        log "⚠ Available memory is low: ${AVAILABLE_MEM}MB (recommended: 8GB+)"
    else
        log "✓ Available memory: ${AVAILABLE_MEM}MB"
    fi
    
    # Check disk space
    AVAILABLE_DISK=$(df -m . | awk 'NR==2{print $4}')
    if [ "$AVAILABLE_DISK" -lt 10000 ]; then
        log "⚠ Available disk space is low: ${AVAILABLE_DISK}MB (recommended: 20GB+)"
    else
        log "✓ Available disk space: ${AVAILABLE_DISK}MB"
    fi
}

# Function to prepare environment
prepare_environment() {
    log "Preparing environment..."
    
    # Create data directories
    mkdir -p primary-data replicat-data
    
    # Set proper permissions for MySQL data directories
    if [ "$(id -u)" -eq 0 ]; then
        chown -R 999:999 primary-data replicat-data
        # Fix config file permissions
        chmod 644 primary-cnf/my.cnf replicat-cnf/my.cnf
    else
        sudo chown -R 999:999 primary-data replicat-data
        # Fix config file permissions
        sudo chmod 644 primary-cnf/my.cnf replicat-cnf/my.cnf
    fi
    log "✓ Data directories and config files prepared"
    
    # Clean up any existing containers
    if [ "$($DOCKER_COMPOSE ps -q)" ]; then
        log "Cleaning up existing containers..."
        $DOCKER_COMPOSE down -v
        sleep 2
    fi
}

# Function to deploy cluster
deploy_cluster() {
    log "Deploying MySQL cluster..."
    
    # Start the cluster
    log "Starting MySQL cluster containers..."
    $DOCKER_COMPOSE up -d
    
    # Wait for MySQL Primary (check via docker exec since no external port)
    log "Waiting for MySQL Primary to be ready..."
    local max_attempts=60
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker exec mysql-primary mysqladmin ping --silent 2>/dev/null; then
            log "✓ MySQL Primary is ready"
            break
        fi
        echo -n "."
        sleep 2
        ((attempt++))
        if [ $attempt -gt $max_attempts ]; then
            log "✗ MySQL Primary failed to start within $(($max_attempts * 2)) seconds"
            exit 1
        fi
    done
    
    # Wait for ProxySQL
    wait_for_service "ProxySQL" "$PROXYSQL_HOST" "$PROXYSQL_PORT" || exit 1
    wait_for_service "ProxySQL Admin" "$PROXYSQL_HOST" "$PROXYSQL_ADMIN_PORT" || exit 1
    
    # Give replica time to sync
    log "Waiting for replication to initialize..."
    sleep 10
    
    # Check container status
    log "Container status:"
    $DOCKER_COMPOSE ps
    
    # Verify MySQL connections
    log "Testing MySQL connections..."
    
    # Note: MySQL Primary tidak expose port external, hanya bisa diakses via ProxySQL
    # Test via docker exec untuk memastikan MySQL Primary berjalan
    if docker exec mysql-primary mysql -uroot -p$MYSQL_ROOT_PASS -e "SELECT 'MySQL Primary OK' as status;" 2>/dev/null; then
        log "✓ MySQL Primary internal connection successful"
    else
        log "✗ MySQL Primary internal connection failed"
        exit 1
    fi
    
    # Test ProxySQL connection (ini yang utama untuk aplikasi)
    if mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$MYSQL_APP_USER -p$MYSQL_APP_PASS -e "SELECT 'ProxySQL OK' as status;" 2>/dev/null; then
        log "✓ ProxySQL connection successful"
    else
        log "✗ ProxySQL connection failed"
        exit 1
    fi
    
    # Setup and sync replication
    log "Setting up MySQL replication..."
    
    # Setup replication on replica
    docker exec mysql-replica bash -c 'mysql -p$MYSQL_ROOT_PASSWORD -e "
        STOP REPLICA;
        RESET REPLICA;
        CHANGE REPLICATION SOURCE TO
          SOURCE_HOST=\"mysql-primary\",
          SOURCE_USER=\"repl\",
          SOURCE_PASSWORD=\"replpass\",
          SOURCE_AUTO_POSITION=1;
    "' 2>/dev/null || true
    
    # Sync existing data from primary to replica
    log "Syncing existing data from Primary to Replica..."
    docker exec mysql-primary bash -c 'mysqldump -p$MYSQL_ROOT_PASSWORD --single-transaction --routines --triggers --all-databases --set-gtid-purged=OFF > /tmp/primary_sync.sql' 2>/dev/null
    docker cp mysql-primary:/tmp/primary_sync.sql ./temp_sync.sql
    docker cp ./temp_sync.sql mysql-replica:/tmp/replica_sync.sql
    docker exec mysql-replica bash -c 'mysql -p$MYSQL_ROOT_PASSWORD < /tmp/replica_sync.sql' 2>/dev/null
    rm -f ./temp_sync.sql
    
    # Start replication
    docker exec mysql-replica bash -c 'mysql -p$MYSQL_ROOT_PASSWORD -e "START REPLICA;"' 2>/dev/null
    
    # Check replication status
    log "Checking replication status..."
    REPL_STATUS=$(docker exec mysql-replica bash -c 'mysql -p$MYSQL_ROOT_PASSWORD -e "SHOW REPLICA STATUS\G"' 2>/dev/null | grep -E "(Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source)" || echo "")
    
    if echo "$REPL_STATUS" | grep -q "Slave_IO_Running: Yes" && echo "$REPL_STATUS" | grep -q "Slave_SQL_Running: Yes"; then
        log "✓ Replication is working"
        echo "$REPL_STATUS" | tee -a "$DEPLOY_LOG"
    else
        log "⚠ Replication may have issues"
        echo "$REPL_STATUS" | tee -a "$DEPLOY_LOG"
    fi
    
    # Check ProxySQL server status
    log "Checking ProxySQL server status..."
    PROXYSQL_STATUS=$(mysql -h$PROXYSQL_HOST -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "SELECT hostgroup,srv_host,srv_port,status,weight FROM mysql_servers;" 2>/dev/null || echo "")
    
    if echo "$PROXYSQL_STATUS" | grep -q "ONLINE"; then
        log "✓ ProxySQL servers are online"
        echo "$PROXYSQL_STATUS" | tee -a "$DEPLOY_LOG"
    else
        log "⚠ ProxySQL servers may have issues"
        echo "$PROXYSQL_STATUS" | tee -a "$DEPLOY_LOG"
    fi
    
    log "✅ MySQL cluster deployment completed successfully"
}

# Function to prepare test database
prepare_test_database() {
    log "Preparing test database and tables..."
    
    # Create test database and tables
    mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$MYSQL_APP_USER -p$MYSQL_APP_PASS << EOF
CREATE DATABASE IF NOT EXISTS loadtest;
USE loadtest;

-- Create users table for testing
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status ENUM('active', 'inactive') DEFAULT 'active',
    login_count INT DEFAULT 0,
    last_login TIMESTAMP NULL,
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Create sessions table for testing
CREATE TABLE IF NOT EXISTS sessions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_user_id (user_id),
    INDEX idx_session_token (session_token),
    INDEX idx_expires_at (expires_at),
    INDEX idx_is_active (is_active),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Create transactions table for testing
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    transaction_type ENUM('credit', 'debit') NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    description TEXT,
    reference_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
    INDEX idx_user_id (user_id),
    INDEX idx_transaction_type (transaction_type),
    INDEX idx_created_at (created_at),
    INDEX idx_status (status),
    INDEX idx_reference_id (reference_id),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Insert initial test data
INSERT INTO users (username, email, first_name, last_name, status, login_count) 
SELECT 
    CONCAT('user_', LPAD(seq, 6, '0')),
    CONCAT('user_', LPAD(seq, 6, '0'), '@example.com'),
    CONCAT('FirstName', seq),
    CONCAT('LastName', seq),
    CASE WHEN seq % 10 = 0 THEN 'inactive' ELSE 'active' END,
    FLOOR(RAND() * 100)
FROM (
    SELECT @rownum := @rownum + 1 AS seq
    FROM information_schema.tables t1
    CROSS JOIN information_schema.tables t2
    CROSS JOIN (SELECT @rownum := 0) r
    LIMIT 10000
) numbers;

-- Update statistics
ANALYZE TABLE users, sessions, transactions;
EOF

    if [ $? -eq 0 ]; then
        log "✓ Test database and tables prepared"
    else
        log "✗ Failed to prepare test database"
        exit 1
    fi
}

# Function to run sysbench load test
run_sysbench_test() {
    local test_type=$1
    local threads=$2
    local duration=$3
    
    log "Running sysbench $test_type test with $threads threads for $duration seconds..."
    
    # Prepare sysbench test
    sysbench oltp_${test_type} \
        --mysql-host=$PROXYSQL_HOST \
        --mysql-port=$PROXYSQL_PORT \
        --mysql-user=$MYSQL_APP_USER \
        --mysql-password=$MYSQL_APP_PASS \
        --mysql-db=loadtest \
        --tables=4 \
        --table-size=100000 \
        --threads=$threads \
        prepare >> "$TEST_LOG" 2>&1
    
    if [ $? -ne 0 ]; then
        log "✗ Failed to prepare sysbench $test_type test"
        return 1
    fi
    
    # Run the test
    log "Executing $test_type test..."
    sysbench oltp_${test_type} \
        --mysql-host=$PROXYSQL_HOST \
        --mysql-port=$PROXYSQL_PORT \
        --mysql-user=$MYSQL_APP_USER \
        --mysql-password=$MYSQL_APP_PASS \
        --mysql-db=loadtest \
        --tables=4 \
        --table-size=100000 \
        --threads=$threads \
        --time=$duration \
        --report-interval=10 \
        run | tee -a "$TEST_LOG"
    
    # Cleanup
    sysbench oltp_${test_type} \
        --mysql-host=$PROXYSQL_HOST \
        --mysql-port=$PROXYSQL_PORT \
        --mysql-user=$MYSQL_APP_USER \
        --mysql-password=$MYSQL_APP_PASS \
        --mysql-db=loadtest \
        --tables=4 \
        cleanup >> "$TEST_LOG" 2>&1
    
    log "✓ $test_type test completed"
}

# Function to run custom concurrent test
run_custom_load_test() {
    local num_users=$1
    local duration=$2
    
    log "Running custom load test with $num_users concurrent users for $duration seconds..."
    
    # Create custom load test script
    cat > /tmp/mysql_load_test.sh << 'EOFSCRIPT'
#!/bin/bash
PROXYSQL_HOST=$1
PROXYSQL_PORT=$2
MYSQL_APP_USER=$3
MYSQL_APP_PASS=$4
USER_ID=$5
DURATION=$6

end_time=$(($(date +%s) + DURATION))

while [ $(date +%s) -lt $end_time ]; do
    # Random operation (70% read, 30% write)
    if [ $((RANDOM % 100)) -lt 70 ]; then
        # Read operations
        mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$MYSQL_APP_USER -p$MYSQL_APP_PASS -e "
        SELECT u.id, u.username, u.email, u.login_count, s.session_token 
        FROM loadtest.users u 
        LEFT JOIN loadtest.sessions s ON u.id = s.user_id 
        WHERE u.id = $((RANDOM % 10000 + 1)) AND u.status = 'active' 
        LIMIT 10;" >/dev/null 2>&1
    else
        # Write operations
        mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$MYSQL_APP_USER -p$MYSQL_APP_PASS -e "
        UPDATE loadtest.users 
        SET login_count = login_count + 1, last_login = NOW() 
        WHERE id = $((RANDOM % 10000 + 1));
        
        INSERT INTO loadtest.transactions (user_id, transaction_type, amount, description, reference_id) 
        VALUES ($((RANDOM % 10000 + 1)), 
                CASE WHEN $((RANDOM % 2)) = 0 THEN 'credit' ELSE 'debit' END,
                ROUND(RAND() * 1000, 2),
                'Load test transaction',
                CONCAT('REF_', $USER_ID, '_', UNIX_TIMESTAMP(), '_', $RANDOM));" >/dev/null 2>&1
    fi
    
    # Small random delay to simulate real usage
    sleep 0.$((RANDOM % 10))
done
EOFSCRIPT
    
    chmod +x /tmp/mysql_load_test.sh
    
    # Start concurrent users
    log "Starting $num_users concurrent users..."
    for i in $(seq 1 $num_users); do
        /tmp/mysql_load_test.sh "$PROXYSQL_HOST" "$PROXYSQL_PORT" "$MYSQL_APP_USER" "$MYSQL_APP_PASS" "$i" "$duration" &
        
        # Start users in batches to avoid overwhelming the system
        if [ $((i % 50)) -eq 0 ]; then
            sleep 1
        fi
    done
    
    log "All users started. Test will run for $duration seconds..."
    
    # Monitor during test
    for i in $(seq 1 $((duration / 10))); do
        sleep 10
        ACTIVE_CONNECTIONS=$(mysql -h$PROXYSQL_HOST -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "SELECT SUM(ConnUsed) as active_connections FROM stats_mysql_connection_pool;" 2>/dev/null | tail -1)
        log "Active connections: $ACTIVE_CONNECTIONS"
    done
    
    # Wait for all background jobs to complete
    wait
    
    # Cleanup
    rm -f /tmp/mysql_load_test.sh
    
    log "✓ Custom load test completed"
}

# Function to generate performance report
generate_performance_report() {
    log "Generating performance report..."
    
    REPORT_FILE="$LOG_DIR/performance_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
MySQL Cluster Performance Report
Generated: $(date)
================================

CLUSTER STATUS:
EOF
    
    # Container status
    echo "Container Status:" >> "$REPORT_FILE"
    $DOCKER_COMPOSE ps >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    
    # Replication status
    echo "Replication Status:" >> "$REPORT_FILE"
    docker exec mysql-replica mysql -uroot -p$MYSQL_ROOT_PASS -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)" >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    
    # ProxySQL statistics
    echo "ProxySQL Connection Pool Statistics:" >> "$REPORT_FILE"
    mysql -h$PROXYSQL_HOST -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "SELECT * FROM stats_mysql_connection_pool;" 2>/dev/null >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    
    echo "ProxySQL Query Rules Statistics:" >> "$REPORT_FILE"
    mysql -h$PROXYSQL_HOST -P$PROXYSQL_ADMIN_PORT -u$PROXYSQL_ADMIN_USER -p$PROXYSQL_ADMIN_PASS -e "SELECT rule_id,hits,destination_hostgroup FROM stats_mysql_query_rules WHERE hits > 0;" 2>/dev/null >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    
    # MySQL performance metrics
    echo "MySQL Primary Performance Metrics:" >> "$REPORT_FILE"
    mysql -h127.0.0.1 -P3307 -uroot -p$MYSQL_ROOT_PASS -e "
    SELECT 'Connections' as Metric, VARIABLE_VALUE as Value FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Threads_connected'
    UNION ALL
    SELECT 'Questions', VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Questions'
    UNION ALL
    SELECT 'Slow_queries', VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Slow_queries'
    UNION ALL
    SELECT 'Uptime', VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Uptime';
    " 2>/dev/null >> "$REPORT_FILE"
    
    log "✓ Performance report generated: $REPORT_FILE"
    echo
    echo -e "${CYAN}Performance Report Location: $REPORT_FILE${NC}"
    echo -e "${CYAN}Test Log Location: $TEST_LOG${NC}"
}

# Function to run load tests
run_load_tests() {
    log "Starting comprehensive load tests..."
    
    # Prepare test database
    prepare_test_database
    
    # Test with minimum users
    log "=== Test 1: $MIN_USERS Concurrent Users (Custom Test) ==="
    run_custom_load_test $MIN_USERS 180
    
    sleep 30  # Cool down period
    
    # Test with maximum users
    log "=== Test 2: $MAX_USERS Concurrent Users (Custom Test) ==="
    run_custom_load_test $MAX_USERS 180
    
    sleep 30  # Cool down period
    
    # Sysbench read-only test
    log "=== Test 3: Sysbench Read-Only Test ==="
    run_sysbench_test "read_only" 1000 120
    
    sleep 30  # Cool down period
    
    # Sysbench read-write test
    log "=== Test 4: Sysbench Read-Write Test ==="
    run_sysbench_test "read_write" 1000 120
    
    sleep 30  # Cool down period
    
    # Mixed workload test
    log "=== Test 5: Mixed Workload Test ==="
    run_sysbench_test "mixed" 1500 180
    
    # Generate performance report
    generate_performance_report
    
    log "✅ All load tests completed successfully"
}

# Main script logic
main() {
    local action=${1:-full}
    
    case $action in
        "deploy")
            echo -e "${YELLOW}=== DEPLOYMENT ONLY ===${NC}"
            check_prerequisites
            prepare_environment
            deploy_cluster
            ;;
        "test")
            echo -e "${YELLOW}=== LOAD TESTING ONLY ===${NC}"
            if ! mysql -h$PROXYSQL_HOST -P$PROXYSQL_PORT -u$MYSQL_APP_USER -p$MYSQL_APP_PASS -e "SELECT 1;" >/dev/null 2>&1; then
                log "✗ MySQL cluster is not running or not accessible"
                exit 1
            fi
            run_load_tests
            ;;
        "full")
            echo -e "${YELLOW}=== FULL DEPLOYMENT + LOAD TESTING ===${NC}"
            check_prerequisites
            prepare_environment
            deploy_cluster
            echo
            echo -e "${YELLOW}Waiting 30 seconds before starting load tests...${NC}"
            sleep 30
            run_load_tests
            ;;
        *)
            echo "Usage: $0 [deploy|test|full]"
            echo "  deploy - Deploy MySQL cluster only"
            echo "  test   - Run load tests only (requires running cluster)"
            echo "  full   - Deploy cluster and run load tests (default)"
            exit 1
            ;;
    esac
    
    echo
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}              OPERATION COMPLETED${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo
    echo "Logs saved to:"
    echo "  Deployment: $DEPLOY_LOG"
    echo "  Load Test: $TEST_LOG"
    echo
    echo -e "${CYAN}🖥️  GUI Management Interfaces:${NC}"
    echo "  🎛️  ProxySQL Web UI:    http://192.168.11.122:8080"
    echo "  🌐 Custom Dashboard:   http://192.168.11.122:8082"
    echo
    echo -e "${CYAN}💻 Command Line Tools:${NC}"
    echo "  Interactive CLI: ./cluster-cli.sh"
    echo "  Quick Status: ./cluster-cli.sh status"
    echo "  Health Check: ./health_check.sh"
    echo "  View Logs: docker compose logs -f"
    echo "  Stop Cluster: docker compose down"
}

# Run main function
main "$@"
