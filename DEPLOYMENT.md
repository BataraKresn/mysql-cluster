# MySQL Cluster Deployment Guide

## 🚀 Quick Start

### Prerequisites Check
```bash
# Check Docker version
docker --version
# Required: Docker Engine 20.10+

# Check Docker Compose version  
docker compose version
# Required: Docker Compose 2.0+

# Check available disk space
df -h
# Recommended: At least 20GB free space

# Check available RAM
free -h
# Recommended: At least 8GB RAM
```

### Step-by-Step Deployment

#### 1. Prepare Environment
```bash
# Navigate to cluster directory
cd /mnt/mysql-new/mysql-cluster

# Create data directories (if not exists)
mkdir -p primary-data replicat-data

# Set proper permissions
sudo chown -R 999:999 primary-data replicat-data
```

#### 2. Configure Environment Variables (Optional)
```bash
# Create .env file for custom settings
cat > .env << EOF
MYSQL_ROOT_PASSWORD=2fF2P7xqVtc4iCExR
MYSQL_APP_PASSWORD=AppPass123!
MYSQL_REPL_PASSWORD=replpass
PROXYSQL_ADMIN_PASSWORD=Soleh1!
EOF
```

#### 3. Start Cluster
```bash
# Start all services
docker compose up -d

# Verify all containers are running
docker compose ps

# Expected output:
# NAME            IMAGE                         STATUS
# mysql-primary   mysql:8.0.42                 Up
# mysql-replica   mysql:8.0.42                 Up  
# proxysql        severalnines/proxysql:2.0    Up
```

#### 4. Verify Deployment
```bash
# Test ProxySQL connection
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT 'ProxySQL OK' as status;"

# Test direct MySQL connection
mysql -h127.0.0.1 -P3307 -uroot -p2fF2P7xqVtc4iCExR -e "SELECT 'MySQL OK' as status;"

# Check replication status
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)"
```

## 🔄 Operational Commands

### Daily Operations
```bash
# Check cluster health
docker compose ps
docker compose logs --tail=50

# Monitor resource usage
docker stats mysql-primary mysql-replica proxysql

# Check replication lag
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master
```

### Maintenance Commands
```bash
# Stop cluster
docker compose down

# Start cluster
docker compose up -d

# Restart specific service
docker compose restart mysql-primary
docker compose restart mysql-replica
docker compose restart proxysql

# View logs
docker compose logs mysql-primary
docker compose logs mysql-replica
docker compose logs proxysql
```

### Backup & Recovery
```bash
# Create full backup
docker exec mysql-primary mysqldump \
  -uroot -p2fF2P7xqVtc4iCExR \
  --all-databases \
  --master-data=2 \
  --single-transaction \
  --routines \
  --triggers > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
docker exec -i mysql-primary mysql \
  -uroot -p2fF2P7xqVtc4iCExR < backup_file.sql
```

## 🔧 Configuration Management

### Update MySQL Configuration
```bash
# Edit configuration
nano primary-cnf/my.cnf
nano replicat-cnf/my.cnf

# Apply changes (requires restart)
docker compose restart mysql-primary
docker compose restart mysql-replica
```

### Update ProxySQL Configuration
```bash
# Edit configuration
nano proxysql/proxysql.cnf

# Apply changes
docker compose restart proxysql

# Or reload configuration without restart
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;
"
```

## 📊 Monitoring & Alerts

### Health Check Script
```bash
#!/bin/bash
# save as health_check.sh

echo "=== MySQL Cluster Health Check ==="
echo "Date: $(date)"
echo

# Check container status
echo "1. Container Status:"
docker compose ps

echo
echo "2. Replication Status:"
REPL_STATUS=$(docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)")
echo "$REPL_STATUS"

echo
echo "3. ProxySQL Server Status:"
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT hostgroup,srv_host,srv_port,status,weight FROM mysql_servers;" 2>/dev/null

echo
echo "4. Connection Count:"
PRIMARY_CONN=$(docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}')
echo "Primary connections: $PRIMARY_CONN"

REPLICA_CONN=$(docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | tail -1 | awk '{print $2}')
echo "Replica connections: $REPLICA_CONN"

echo
echo "=== Health Check Complete ==="
```

### Performance Monitoring Script
```bash
#!/bin/bash
# save as performance_monitor.sh

echo "=== MySQL Cluster Performance Monitor ==="
echo "Date: $(date)"
echo

# MySQL Performance Metrics
echo "1. MySQL Primary Performance:"
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "
SELECT 
  ROUND((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') - 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_reads')) / 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') * 100, 2) 
  AS 'Buffer Pool Hit Ratio %';

SHOW STATUS LIKE 'Questions';
SHOW STATUS LIKE 'Slow_queries';
SHOW STATUS LIKE 'Threads_connected';
" 2>/dev/null

echo
echo "2. ProxySQL Query Statistics:"
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
SELECT hostgroup,srv_host,srv_port,status,ConnUsed,ConnFree,ConnOK,ConnERR,Queries,Bytes_data_sent,Bytes_data_recv FROM stats_mysql_connection_pool;
" 2>/dev/null

echo
echo "3. Docker Resource Usage:"
docker stats --no-stream mysql-primary mysql-replica proxysql

echo
echo "=== Performance Monitor Complete ==="
```

## 🚨 Troubleshooting Guide

### Common Issues & Solutions

#### Issue 1: Replication Stopped
```bash
# Symptoms
SHOW SLAVE STATUS\G; # Shows IO_Running: No or SQL_Running: No

# Solutions
# 1. Check error logs
docker logs mysql-replica

# 2. Reset replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
  MASTER_HOST='172.20.0.10',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpass',
  MASTER_AUTO_POSITION=1;
START SLAVE;
"

# 3. Verify replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"
```

#### Issue 2: ProxySQL Connection Refused
```bash
# Symptoms
ERROR 2003 (HY000): Can't connect to MySQL server on 'localhost' (111)

# Solutions
# 1. Check ProxySQL status
docker logs proxysql

# 2. Verify ProxySQL configuration
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
SELECT * FROM mysql_servers;
SELECT * FROM mysql_users;
"

# 3. Reload configuration
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
"
```

#### Issue 3: High Memory Usage
```bash
# Symptoms
docker stats shows high memory usage

# Solutions
# 1. Check InnoDB buffer pool size
# Edit my.cnf files and reduce innodb_buffer_pool_size

# 2. Monitor queries
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW PROCESSLIST;"

# 3. Check for memory leaks
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "
SHOW STATUS LIKE 'Innodb_buffer_pool%';
"
```

### Emergency Procedures

#### Complete Cluster Reset
```bash
# WARNING: This will delete all data!

# 1. Stop cluster
docker compose down

# 2. Remove data
sudo rm -rf primary-data/* replicat-data/*

# 3. Start fresh
docker compose up -d

# 4. Verify deployment
./health_check.sh
```

#### Failover to Replica (Manual)
```bash
# 1. Stop writes to primary
# - Update application configuration to stop writes
# - Or stop primary container: docker compose stop mysql-primary

# 2. Promote replica to master
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "
STOP SLAVE;
RESET SLAVE ALL;
SET GLOBAL read_only = 0;
"

# 3. Update ProxySQL to point to new master
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
UPDATE mysql_servers SET hostgroup_id=10 WHERE srv_host='172.20.0.11';
UPDATE mysql_servers SET hostgroup_id=20 WHERE srv_host='172.20.0.10';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
"
```

## 📞 Support Contacts

- **Database Administrator**: [Your contact info]
- **System Administrator**: [Your contact info]  
- **Emergency Contact**: [Your contact info]

## 📋 Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-07-23 | 1.0 | Initial deployment guide |

---

**Note**: Always test procedures in a non-production environment first.
