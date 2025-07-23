# 🚀 Quick Start Guide - MySQL Cluster Load Testing

## 📋 TL;DR - One Command Deployment

```bash
# Deploy cluster + Run 1500-2000 concurrent user load test
./deploy.sh

# Monitor real-time (terminal kedua)
./monitor_loadtest.sh
```

## 🎯 What This Script Does

### 1. **Automated Deployment**
- ✅ Checks prerequisites (Docker, MySQL client, sysbench)
- ✅ Deploys MySQL Primary + Replica + ProxySQL
- ✅ Verifies all connections and replication
- ✅ Sets up test database dengan 10K initial records

### 2. **Comprehensive Load Testing**
- ✅ **1500 concurrent users** (3 min) - Custom workload
- ✅ **2000 concurrent users** (3 min) - Custom workload  
- ✅ **sysbench read-only** (1000 threads, 2 min)
- ✅ **sysbench read-write** (1000 threads, 2 min)
- ✅ **sysbench mixed** (1500 threads, 3 min)

### 3. **Performance Monitoring**
- ✅ Real-time connection pool monitoring
- ✅ Query routing statistics (read vs write)
- ✅ Replication lag tracking
- ✅ Resource usage monitoring
- ✅ Automated performance reports

## 🔥 Load Test Specifications

### Connection Flow:
```
1500-2000 Users → ProxySQL (6033) → MySQL Primary/Replica
                     ↓
            70% SELECT → Replica (Read)
            30% INSERT/UPDATE → Primary (Write)
```

### Expected Performance:
```bash
Throughput:     10,000+ queries/second
Response Time:  < 100ms (95th percentile)  
Error Rate:     < 0.1%
Replication Lag: < 1 second
Connection Efficiency: > 95%
```

## 📊 Test Scenarios

### Custom User Simulation:
```sql
-- Read Operations (70%):
SELECT u.*, s.session_token FROM users u 
LEFT JOIN sessions s ON u.id = s.user_id 
WHERE u.status = 'active' LIMIT 10;

-- Write Operations (30%):
UPDATE users SET login_count = login_count + 1, 
last_login = NOW() WHERE id = ?;

INSERT INTO transactions (user_id, amount, type) 
VALUES (?, RAND()*1000, 'credit');
```

### sysbench Tests:
```bash
oltp_read_only:    Pure SELECT workload
oltp_read_write:   Mixed CRUD operations  
oltp_mixed:        Balanced transactional workload
```

## 🛠️ Available Commands

```bash
# Full deployment + load testing (default)
./deploy.sh
./deploy.sh full

# Deploy cluster only (no testing)
./deploy.sh deploy

# Run load tests only (cluster must be running)
./deploy.sh test

# Real-time monitoring (separate terminal)
./monitor_loadtest.sh

# Health check after deployment
./health_check.sh

# Manual backup
./backup.sh full
```

## 📈 Monitoring During Tests

### Real-time Metrics:
```bash
# ProxySQL Connection Pool:
- Active connections per hostgroup
- Query routing statistics
- Error rates per server

# MySQL Performance:
- Connection count
- Query counters (SELECT/INSERT/UPDATE)
- Slow query detection

# Replication Status:
- IO/SQL thread status
- Replication lag in seconds
- Binary log position

# System Resources:
- CPU usage per container
- Memory consumption
- Network I/O
```

## 📝 Log Files & Reports

### Generated Files:
```bash
logs/deploy_YYYYMMDD_HHMMSS.log          # Deployment log
logs/loadtest_YYYYMMDD_HHMMSS.log        # Load test details
logs/performance_report_YYYYMMDD_HHMMSS.txt  # Final report
```

### Performance Report Includes:
- Container status dan health metrics
- Replication status dan lag history
- ProxySQL connection pool efficiency
- Query routing success rates
- MySQL performance counters
- Resource utilization summary

## ⚡ Quick Validation

### Verify Deployment Success:
```bash
# Check containers
docker compose ps

# Test ProxySQL connection
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT 'ProxySQL OK';"

# Check replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G" | grep Running

# Verify ProxySQL routing
mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"
```

### Manual Load Test:
```bash
# Single connection test
time mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "
SELECT COUNT(*) FROM loadtest.users WHERE status='active';"

# Verify write routing to primary
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "
INSERT INTO loadtest.users (username, email) 
VALUES ('test_user', 'test@example.com');"
```

## 🚨 Troubleshooting

### If Deployment Fails:
```bash
# Check prerequisites
docker --version && docker compose version
mysql --version && sysbench --version

# Check system resources
free -h && df -h

# Clean start
docker compose down -v
sudo rm -rf primary-data/* replicat-data/*
./deploy.sh deploy
```

### If Load Tests Fail:
```bash
# Check cluster health first
./health_check.sh

# Verify ProxySQL
mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"

# Check connection limits
# Direct ke Primary (port 3307)
# Check connection limits
mysql -h127.0.0.1 -P3307 -uroot -p2fF2P7xqVtc4iCExR -e "SHOW VARIABLES LIKE 'max_connections';"

# Run individual test
./deploy.sh test
```

## 🎯 Success Indicators

✅ **All 5 containers running** (primary, replica, proxysql)  
✅ **Replication lag < 1 second**  
✅ **All load tests complete** without connection errors  
✅ **ProxySQL routing** correctly (reads→replica, writes→primary)  
✅ **Performance targets met** (10K+ QPS, <100ms response)  
✅ **Resource usage normal** (<80% CPU, <70% memory)  

---

**Ready to test your MySQL cluster at scale? Run `./deploy.sh` and watch the magic happen! 🚀**
