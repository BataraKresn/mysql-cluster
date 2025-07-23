# MySQL Cluster - Scripts & Utilities

## 📜 Available Scripts

### 1. Health Check Script
**File**: `health_check.sh`
**Purpose**: Comprehensive cluster health monitoring

```bash
# Run health check
./health_check.sh

# Schedule periodic checks (add to crontab)
*/5 * * * * /path/to/mysql-cluster/health_check.sh >> /var/log/mysql-cluster-health.log 2>&1
```

**Checks performed**:
- ✅ Container status
- ✅ MySQL connectivity
- ✅ Replication status & lag
- ✅ ProxySQL server status
- ✅ Connection counts
- ✅ Disk space usage
- ✅ Performance metrics
- ✅ Resource usage

### 2. Backup Script
**File**: `backup.sh`
**Purpose**: Automated backup with compression and verification

```bash
# Full backup (recommended for daily)
./backup.sh full

# Incremental backup (binary logs)
./backup.sh incremental

# Schedule backups (add to crontab)
0 2 * * * /path/to/mysql-cluster/backup.sh full >> /var/log/mysql-backup.log 2>&1
0 */6 * * * /path/to/mysql-cluster/backup.sh incremental >> /var/log/mysql-backup.log 2>&1
```

**Features**:
- ✅ Full database backup with compression
- ✅ Binary log backup for point-in-time recovery
- ✅ MD5 checksum verification
- ✅ Automatic cleanup of old backups (30 days)
- ✅ Replication status capture

## 🔧 Quick Commands Reference

### Cluster Management
```bash
# Start cluster
docker-compose up -d

# Stop cluster
docker-compose down

# Restart specific service
docker-compose restart mysql-primary
docker-compose restart mysql-replica
docker-compose restart proxysql

# View logs
docker-compose logs -f mysql-primary
docker-compose logs -f mysql-replica
docker-compose logs -f proxysql

# Check status
docker-compose ps
```

### Direct MySQL Access
```bash
# Connect to Primary
docker exec -it mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR

# Connect to Replica
docker exec -it mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR

# Connect via ProxySQL
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123!

# ProxySQL Admin
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1!
```

### Monitoring Commands
```bash
# Check replication status
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"

# Check master status
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW MASTER STATUS\G"

# Check ProxySQL servers
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"

# Monitor connections
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_connection_pool;"

# Resource usage
docker stats mysql-primary mysql-replica proxysql
```

## 📊 Monitoring Queries

### MySQL Performance Queries
```sql
-- Connection count
SHOW STATUS LIKE 'Threads_connected';

-- Query statistics
SHOW STATUS LIKE 'Questions';
SHOW STATUS LIKE 'Slow_queries';

-- InnoDB buffer pool efficiency
SELECT 
  ROUND((SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') - 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_reads')) / 
        (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='Innodb_buffer_pool_read_requests') * 100, 2) 
  AS 'Buffer Pool Hit Ratio %';

-- Top queries by execution time
SELECT 
    ROUND(SUM_TIMER_WAIT/1000000000000,6) AS exec_time_s,
    COUNT_STAR AS calls,
    ROUND(SUM_TIMER_WAIT/1000000000000/COUNT_STAR,6) AS avg_time_s,
    DIGEST_TEXT
FROM performance_schema.events_statements_summary_by_digest 
ORDER BY SUM_TIMER_WAIT DESC 
LIMIT 10;

-- Process list
SHOW PROCESSLIST;

-- Binary log status
SHOW BINARY LOGS;
```

### ProxySQL Monitoring Queries
```sql
-- Server status
SELECT hostgroup,srv_host,srv_port,status,weight,compression,max_connections,ConnUsed,ConnFree,ConnOK,ConnERR FROM mysql_servers;

-- Connection pool statistics
SELECT * FROM stats_mysql_connection_pool;

-- Query rule statistics
SELECT rule_id,match_digest,match_pattern,destination_hostgroup,apply,hits FROM stats_mysql_query_rules ORDER BY hits DESC;

-- User statistics
SELECT username,frontend_connections,frontend_max_connections FROM stats_mysql_users;

-- Command statistics
SELECT Command,Total_cnt,Total_time_us FROM stats_mysql_commands_counters WHERE Total_cnt > 0 ORDER BY Total_cnt DESC;
```

## 🚨 Emergency Procedures

### 1. Replication Failure Recovery
```bash
# Stop replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "STOP SLAVE;"

# Reset replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "RESET SLAVE ALL;"

# Reconfigure replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "
CHANGE MASTER TO
  MASTER_HOST='172.20.0.10',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpass',
  MASTER_AUTO_POSITION=1;
START SLAVE;"

# Verify replication
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"
```

### 2. Manual Failover (Promote Replica to Master)
```bash
# Step 1: Stop writes to current master
# (Update application or stop primary container)

# Step 2: Ensure replica is caught up
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G" | grep Seconds_Behind_Master

# Step 3: Promote replica to master
docker exec mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "
STOP SLAVE;
RESET SLAVE ALL;
SET GLOBAL read_only = 0;"

# Step 4: Update ProxySQL to point to new master
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
UPDATE mysql_servers SET hostgroup_id=10 WHERE srv_host='172.20.0.11';
UPDATE mysql_servers SET hostgroup_id=20 WHERE srv_host='172.20.0.10';
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;"
```

### 3. Complete Cluster Reset
```bash
# WARNING: This will delete all data!

# Stop cluster
docker-compose down

# Remove all data
sudo rm -rf primary-data/* replicat-data/*

# Start fresh cluster
docker-compose up -d

# Verify cluster
./health_check.sh
```

### 4. Recovery from Backup
```bash
# Stop cluster
docker-compose down

# Remove corrupted data
sudo rm -rf primary-data/* replicat-data/*

# Start only primary
docker-compose up -d mysql-primary

# Restore from backup
gunzip -c /var/backups/mysql-cluster/full_backup_YYYYMMDD_HHMMSS.sql.gz | \
docker exec -i mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR

# Start replica
docker-compose up -d mysql-replica

# Start ProxySQL
docker-compose up -d proxysql

# Verify cluster
./health_check.sh
```

## 🔧 Configuration Reload

### MySQL Configuration Changes
```bash
# Edit configuration files
nano primary-cnf/my.cnf
nano replicat-cnf/my.cnf

# Restart containers to apply changes
docker-compose restart mysql-primary
docker-compose restart mysql-replica
```

### ProxySQL Configuration Changes
```bash
# Edit configuration
nano proxysql/proxysql.cnf

# Option 1: Restart container
docker-compose restart proxysql

# Option 2: Reload without restart (for some settings)
docker exec proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "
LOAD MYSQL SERVERS TO RUNTIME;
LOAD MYSQL USERS TO RUNTIME;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
SAVE MYSQL USERS TO DISK;
SAVE MYSQL QUERY RULES TO DISK;"
```

## 📝 Maintenance Schedule

### Daily Tasks
- [ ] Run health check: `./health_check.sh`
- [ ] Check disk space
- [ ] Monitor replication lag
- [ ] Review error logs

### Weekly Tasks
- [ ] Full backup: `./backup.sh full`
- [ ] Review slow query log
- [ ] Check ProxySQL statistics
- [ ] Monitor resource usage trends

### Monthly Tasks
- [ ] Review and optimize MySQL configuration
- [ ] Clean up old binary logs
- [ ] Update security patches
- [ ] Performance review and tuning

### Quarterly Tasks
- [ ] Disaster recovery testing
- [ ] Documentation review and updates
- [ ] Security audit
- [ ] Capacity planning review

## 🔗 Useful Resources

- [MySQL 8.0 Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/)
- [ProxySQL Documentation](https://proxysql.com/documentation/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MySQL Replication Best Practices](https://dev.mysql.com/doc/refman/8.0/en/replication-howto.html)

---

**Last Updated**: July 23, 2025  
**Version**: 1.0
