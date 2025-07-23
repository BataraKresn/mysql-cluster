# MySQL Cluster Configuration Summary

## 🏗️ Architecture Overview

```
External Clients
       │
       ▼
┌─────────────────┐
│    ProxySQL     │ ← Load Balancer & Query Router
│  172.20.0.12    │   - Port 6033 (MySQL Protocol)
│  Port 6033      │   - Port 6032 (Admin Interface)
└─────────┬───────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌─────────┐ ┌─────────┐
│Primary  │ │Replica  │
│Master   │─┤Slave    │ ← Replication
│172.20.  │ │172.20.  │
│0.10     │ │0.11     │
│Port 3306│ │Read Only│
└─────────┘ └─────────┘
```

## 📊 Component Matrix

| Component | Container | IP | Ports | Role | Status |
|-----------|-----------|-------|-------|------|--------|
| **MySQL Primary** | mysql-primary | 172.20.0.10 | 3306 | Read/Write Master | ✅ Active |
| **MySQL Replica** | mysql-replica | 172.20.0.11 | Internal | Read-Only Slave | ✅ Active |
| **ProxySQL** | proxysql | 172.20.0.12 | 6033, 6032 | Load Balancer | ✅ Active |

## 🔧 Key Configurations

### MySQL Settings
```ini
# Primary (mysql-primary)
server-id = 1
log_bin = mysql-bin
read_only = 0
bind-address = 0.0.0.0

# Replica (mysql-replica)  
server-id = 2
relay_log = relay-log
read_only = 1
bind-address = 0.0.0.0
```

### ProxySQL Routing
```sql
-- HostGroup 10: Write operations → Primary
-- HostGroup 20: Read operations → Replica

# Query Rules:
SELECT statements → Replica (172.20.0.11)
INSERT/UPDATE/DELETE → Primary (172.20.0.10)
```

## 🔐 Access Credentials

### Database Users
```sql
-- Root user (full access)
Username: root
Password: 2fF2P7xqVtc4iCExR
Access: All databases

-- Application user  
Username: appuser
Password: AppPass123!
Access: appdb, db-mpp databases

-- Replication user
Username: repl
Password: replpass
Access: Replication only
```

### ProxySQL Admin
```sql
Username: superman
Password: Soleh1!
Port: 6032
```

## 🌐 Connection Strings

### Production Applications
```bash
# Via ProxySQL (Recommended)
mysql -h<SERVER_IP> -P6033 -uappuser -pAppPass123!

# Connection String Format:
# mysql://appuser:AppPass123!@<SERVER_IP>:6033/appdb
```

### Administration
```bash
# Direct MySQL Access
mysql -h<SERVER_IP> -P3306 -uroot -p2fF2P7xqVtc4iCExR

# ProxySQL Administration
mysql -h<SERVER_IP> -P6032 -usuperman -pSoleh1!
```

## 📈 Performance Specs

### Hardware Recommendations
- **CPU**: 4+ cores
- **RAM**: 8GB+ (InnoDB buffer pool: 8GB configured)
- **Storage**: SSD recommended
- **Network**: 1Gbps+

### Current Limits
- **Max Connections**: 2000 (MySQL), 2048 (ProxySQL)
- **Buffer Pool**: 8GB
- **Max Packet Size**: 256MB
- **Query Cache**: Disabled (MySQL 8.0 default)

## 🔄 Backup & Recovery

### Backup Commands
```bash
# Full backup
docker exec mysql-primary mysqldump -uroot -p2fF2P7xqVtc4iCExR \
  --all-databases --master-data=2 --single-transaction \
  > backup_$(date +%Y%m%d).sql

# Binary log backup
docker exec mysql-primary mysqlbinlog mysql-bin.000001 > binlog.sql
```

### Recovery Commands
```bash
# Restore full backup
docker exec -i mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR < backup.sql

# Point-in-time recovery
docker exec -i mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR < binlog.sql
```

## 📊 Monitoring Queries

### Replication Status
```sql
-- Check on replica
SHOW SLAVE STATUS\G

-- Key fields to monitor:
-- Slave_IO_Running: Yes
-- Slave_SQL_Running: Yes  
-- Seconds_Behind_Master: 0 (or low number)
```

### Performance Monitoring
```sql
-- Connection count
SHOW STATUS LIKE 'Threads_connected';

-- Query statistics
SHOW STATUS LIKE 'Questions';
SHOW STATUS LIKE 'Slow_queries';

-- Buffer pool efficiency
SELECT 
  ROUND((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') - 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_reads')) / 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') * 100, 2) 
  AS 'Buffer Pool Hit Ratio %';
```

### ProxySQL Statistics
```sql
-- Connection pool stats
SELECT * FROM stats_mysql_connection_pool;

-- Query routing stats  
SELECT * FROM stats_mysql_query_rules;

-- Server health
SELECT hostgroup,srv_host,srv_port,status,weight FROM mysql_servers;
```

## 🚨 Alert Thresholds

### Critical Alerts
- Replication lag > 60 seconds
- Slave_IO_Running = No
- Slave_SQL_Running = No
- Container down
- Disk space < 10%

### Warning Alerts
- Connection count > 1500
- Buffer pool hit ratio < 95%
- Slow queries > 100/hour
- Replication lag > 10 seconds

## 🛠️ Quick Commands Reference

```bash
# Cluster management
docker-compose up -d              # Start cluster
docker-compose down               # Stop cluster
docker-compose restart <service>  # Restart service
docker-compose ps                 # Check status
docker-compose logs <service>     # View logs

# Health checks
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"
docker stats mysql-primary mysql-replica proxysql

# ProxySQL admin
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"

# Backup
docker exec mysql-primary mysqldump -uroot -p2fF2P7xqVtc4iCExR --all-databases > backup.sql

# Test connections
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT 'OK'"
mysql -h127.0.0.1 -P3306 -uroot -p2fF2P7xqVtc4iCExR -e "SELECT 'OK'"
```

---

**Last Updated**: July 23, 2025  
**Version**: 1.0  
**Maintainer**: Database Administrator
