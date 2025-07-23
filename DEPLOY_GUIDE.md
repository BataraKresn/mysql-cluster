# MySQL Cluster Deployment & Load Testing Script

## 📋 Overview

Script `deploy.sh` adalah solusi otomatis untuk deployment MySQL cluster dan load testing dengan 1500-2000 concurrent users melalui ProxySQL. Script ini menggabungkan deployment, konfigurasi, dan stress testing dalam satu perintah.

## 🚀 Features

### Deployment Features:
- ✅ **Automated deployment** MySQL cluster dengan ProxySQL
- ✅ **Prerequisites checking** (Docker, MySQL client, sysbench)
- ✅ **Health verification** setelah deployment
- ✅ **Replication status monitoring**
- ✅ **ProxySQL configuration verification**

### Load Testing Features:
- ✅ **Custom concurrent user simulation** (1500-2000 users)
- ✅ **sysbench integration** untuk standardized testing
- ✅ **Mixed workload testing** (70% read, 30% write)
- ✅ **Real-time monitoring** selama testing
- ✅ **Performance reporting** otomatis

## 📊 Load Test Specifications

### Test Configuration:
- **Concurrent Users**: 1500-2000 simultaneous connections
- **Test Duration**: 3-5 minutes per test
- **Read/Write Ratio**: 70% read operations, 30% write operations
- **Connection Method**: Melalui ProxySQL (port 6033)
- **Database Engine**: MySQL 8.0.42 dengan InnoDB

### Test Scenarios:
1. **Custom Load Test 1**: 1500 concurrent users (3 minutes)
2. **Custom Load Test 2**: 2000 concurrent users (3 minutes)
3. **sysbench Read-Only**: 1000 threads (2 minutes)
4. **sysbench Read-Write**: 1000 threads (2 minutes)
5. **sysbench Mixed Workload**: 1500 threads (3 minutes)

## 🔧 Prerequisites

### System Requirements:
```bash
# Minimum requirements
RAM: 8GB+ (recommended 16GB)
CPU: 4+ cores
Disk: 20GB+ free space
Network: 1Gbps+ untuk optimal performance
```

### Software Requirements:
```bash
# Auto-installed by script jika belum ada
- Docker Engine 20.10+
- Docker Compose 2.0+
- MySQL client
- sysbench (load testing tool)
```

## 📖 Usage

### 1. Full Deployment + Load Testing (Recommended)
```bash
# Deploy cluster dan jalankan semua load tests
./deploy.sh

# Atau eksplisit
./deploy.sh full
```

### 2. Deployment Only
```bash
# Hanya deploy cluster tanpa load testing
./deploy.sh deploy
```

### 3. Load Testing Only
```bash
# Jalankan load tests pada cluster yang sudah running
./deploy.sh test
```

### 4. Real-time Monitoring (Terminal kedua)
```bash
# Monitor metrics real-time selama load test
./monitor_loadtest.sh
```

## 📈 Load Test Details

### Custom Concurrent User Test
Script mensimulasikan user behavior realistis:

```bash
# Per user operations (random):
# 70% Read Operations:
- SELECT dengan JOIN antara users, sessions, transactions
- Query dengan filtering dan LIMIT
- Index-optimized queries

# 30% Write Operations:  
- UPDATE user login statistics
- INSERT new transactions
- UPDATE dengan WHERE clause
```

### sysbench Tests
Menggunakan sysbench built-in workloads:

```bash
# oltp_read_only: SELECT-heavy workload
# oltp_read_write: Mixed SELECT/INSERT/UPDATE/DELETE
# oltp_mixed: Balanced workload dengan transactions
```

## 📊 Test Database Schema

Script otomatis membuat test database dengan struktur:

```sql
-- Database: loadtest
-- Tables:
users          - 10,000 initial records
sessions       - User session tracking  
transactions   - Financial transactions

-- Indexes dioptimasi untuk query performance
-- Foreign keys untuk referential integrity
```

## 📝 Monitoring & Logging

### Log Files:
```bash
logs/deploy_YYYYMMDD_HHMMSS.log      # Deployment log
logs/loadtest_YYYYMMDD_HHMMSS.log    # Load test detailed log
logs/performance_report_YYYYMMDD_HHMMSS.txt  # Performance summary
```

### Real-time Monitoring:
```bash
./monitor_loadtest.sh
# Monitors:
- ProxySQL connection pool usage
- MySQL connection count
- Query statistics (SELECT/INSERT/UPDATE)
- Replication lag
- Container resource usage
```

## 🎯 Expected Performance Results

### Target Metrics:
```bash
# 1500-2000 Concurrent Users:
✅ Response time: < 100ms (95th percentile)
✅ Throughput: 10,000+ queries/second
✅ Error rate: < 0.1%
✅ ProxySQL connection efficiency: > 95%
✅ Replication lag: < 1 second

# Resource Usage:
✅ CPU: < 80% average
✅ Memory: < 70% of allocated
✅ Network: Saturated during peak load
```

### Performance Report Output:
```bash
# Automatic report includes:
- Container status dan health
- Replication status dan lag metrics
- ProxySQL connection pool statistics  
- Query routing statistics (read vs write)
- MySQL performance counters
- Error rates dan response times
```

## 🚨 Troubleshooting

### Common Issues:

#### 1. Memory Insufficient
```bash
# Symptoms: Container crashes, slow performance
# Solution: 
- Increase system RAM
- Reduce load test concurrency
- Adjust InnoDB buffer pool size
```

#### 2. Connection Limits Reached
```bash
# Symptoms: Connection refused errors
# Solution:
- Check max_connections in my.cnf
- Monitor ProxySQL connection pool
- Adjust connection timeout settings
```

#### 3. Slow Performance
```bash
# Symptoms: High response times
# Solution:
- Check disk I/O (use SSD)
- Monitor replication lag
- Review slow query log
- Optimize database indexes
```

#### 4. ProxySQL Issues
```bash
# Symptoms: Query routing failures
# Solution:
- Check ProxySQL server status
- Verify MySQL server health in ProxySQL
- Review ProxySQL error logs
```

## 🔄 Script Flow

### Deployment Phase:
1. **Prerequisites Check** → Docker, MySQL client, sysbench
2. **Environment Prep** → Data directories, permissions
3. **Cluster Deployment** → MySQL Primary, Replica, ProxySQL
4. **Health Verification** → Connections, replication, ProxySQL
5. **Service Readiness** → Wait for all services online

### Load Testing Phase:
1. **Test Database Setup** → Create schema, initial data
2. **Custom Load Test 1** → 1500 users, mixed workload
3. **Custom Load Test 2** → 2000 users, mixed workload  
4. **sysbench Tests** → Read-only, Read-write, Mixed
5. **Performance Report** → Generate comprehensive report

## 📞 Advanced Usage

### Custom Configuration:
```bash
# Edit script variables:
MIN_USERS=1500          # Minimum concurrent users
MAX_USERS=2000          # Maximum concurrent users
TEST_DURATION=300       # Test duration in seconds
READ_WRITE_RATIO="70:30" # Read:Write ratio
```

### Manual Testing:
```bash
# Test specific components:
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT COUNT(*) FROM loadtest.users;"

# Check ProxySQL routing:
mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_query_rules;"
```

## 🎯 Success Criteria

Script deployment dianggap sukses jika:

✅ **All containers running** dan healthy  
✅ **Replication working** (IO & SQL threads running)  
✅ **ProxySQL routing** queries correctly  
✅ **Load tests complete** without major errors  
✅ **Performance targets** achieved  
✅ **Reports generated** successfully  

---

**Last Updated**: July 24, 2025  
**Version**: 1.0  
**Tested On**: MySQL 8.0.42, ProxySQL 2.0, Docker Compose V2
