# MySQL Cluster Architecture Documentation

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Components](#components)
- [Network Configuration](#network-configuration)
- [Database Configuration](#datab# Start the cluster
docker compose up -d

# Verify deployment
docker compose ps
docker compose logsnfiguration)
- [Security](#security)
- [Deployment](#deployment)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Performance Tuning](#performance-tuning)

## 🏗️ Overview

This MySQL cluster setup implements a **Master-Slave Replication** architecture with **ProxySQL** as load balancer and connection router. The cluster is designed for high availability, read scalability, and automatic failover capabilities.

### Key Features:
- ✅ **High Availability**: Master-Slave replication with automatic failover
- ✅ **Load Balancing**: ProxySQL routes read/write queries intelligently
- ✅ **Scalability**: Read queries distributed to replica
- ✅ **Containerized**: Docker-based deployment for easy management
- ✅ **External Access**: Accessible from external servers
- ✅ **GTID Replication**: Global Transaction Identifier for consistent replication

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MySQL Cluster                           │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   Client    │    │   Client    │    │   Client    │        │
│  │ Application │    │ Application │    │ Application │        │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘        │
│         │                  │                  │               │
│         └──────────────────┼──────────────────┘               │
│                            │                                  │
│         ┌──────────────────▼──────────────────┐               │
│         │            ProxySQL                 │               │
│         │         (Load Balancer)             │               │
│         │       172.20.0.12:6033             │               │
│         │                                     │               │
│         │  ┌─────────────────────────────┐    │               │
│         │  │     Query Routing           │    │               │
│         │  │  • SELECT → Replica (HG20)  │    │               │
│         │  │  • INSERT/UPDATE → Primary  │    │               │
│         │  │    (HG10)                   │    │               │
│         │  └─────────────────────────────┘    │               │
│         └──────────────┬───────────┬──────────┘               │
│                        │           │                          │
│         ┌──────────────▼─┐       ┌─▼──────────────┐           │
│         │  MySQL Primary │       │ MySQL Replica  │           │
│         │  172.20.0.10   │──────▶│ 172.20.0.11    │           │
│         │  (Read/Write)  │       │ (Read Only)     │           │
│         │  Server ID: 1  │       │ Server ID: 2    │           │
│         └────────────────┘       └─────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

External Network: 0.0.0.0:3307, 0.0.0.0:6033, 0.0.0.0:6032
Internal Network: 172.20.0.0/16
```

## 🔧 Components

### 1. **MySQL Primary (Master)**
- **Container**: `mysql-primary`
- **Image**: `mysql:8.0.42`
- **Internal IP**: `172.20.0.10`
- **External Port**: `3307`
- **Role**: Read/Write operations, Binary logging for replication
- **Server ID**: `1`

**Key Configurations:**
```ini
server-id = 1
log_bin = mysql-bin
binlog_format = ROW
read_only = 0
bind-address = 0.0.0.0
```

### 2. **MySQL Replica (Slave)**
- **Container**: `mysql-replica`
- **Image**: `mysql:8.0.42`
- **Internal IP**: `172.20.0.11`
- **External Port**: Not exposed
- **Role**: Read-only operations, Replication slave
- **Server ID**: `2`

**Key Configurations:**
```ini
server-id = 2
relay_log = relay-log
read_only = 1
bind-address = 0.0.0.0
```

### 3. **ProxySQL (Load Balancer)**
- **Container**: `proxysql`
- **Image**: `severalnines/proxysql:2.0`
- **Internal IP**: `172.20.0.12`
- **External Ports**: 
  - `6033` (MySQL Protocol)
  - `6032` (Admin Interface)
- **Role**: Query routing, Load balancing, Connection pooling

**Query Routing Rules:**
```sql
-- Read queries → Replica (HostGroup 20)
SELECT statements → mysql-replica (172.20.0.11)

-- Write queries → Primary (HostGroup 10)  
INSERT/UPDATE/DELETE → mysql-primary (172.20.0.10)
```

## 🌐 Network Configuration

### Internal Docker Network
- **Network Name**: `mysqlnet`
- **Subnet**: `172.20.0.0/16`
- **Gateway**: `172.20.0.1`
- **Driver**: `bridge`

### IP Address Allocation
| Component | Internal IP | External Port | Purpose |
|-----------|-------------|---------------|---------|
| MySQL Primary | 172.20.0.10 | 3307 | Read/Write Database |
| MySQL Replica | 172.20.0.11 | - | Read-only Database |
| ProxySQL | 172.20.0.12 | 6033, 6032 | Load Balancer & Admin |

### External Access
```bash
# Application connections (via ProxySQL)
mysql -h<SERVER_IP> -P6033 -u<username> -p<password>

# Direct primary access (for admin)
mysql -h<SERVER_IP> -P3307 -u<username> -p<password>

# ProxySQL administration
mysql -h<SERVER_IP> -P6032 -usuperman -pSoleh1!
```

## 💾 Database Configuration

### Databases
- **appdb**: Main application database
- **db-mpp**: Secondary application database

### Users & Privileges

| Username | Password | Access | Privileges |
|----------|----------|--------|------------|
| `root` | `2fF2P7xqVtc4iCExR` | All hosts (%) | Full privileges |
| `appuser` | `AppPass123!` | All hosts (%) | appdb.*, db-mpp.* |
| `repl` | `replpass` | All hosts (%) | REPLICATION SLAVE |
| `superman` | `Soleh1!` | ProxySQL Admin | ProxySQL Admin |

### Replication Configuration
- **Type**: Master-Slave Asynchronous Replication
- **Method**: GTID (Global Transaction Identifier)
- **Binary Log Format**: ROW
- **Auto Position**: Enabled

```sql
-- Replication setup command
CHANGE MASTER TO
  MASTER_HOST='172.20.0.10',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpass',
  MASTER_AUTO_POSITION=1;
```

## 🔒 Security

### Network Security
- **Internal Communication**: All inter-container communication uses internal network
- **External Access**: Only necessary ports exposed to host
- **Firewall Rules**: Configure host firewall for ports 3307, 6033, 6032

### Authentication
- **MySQL Native Password**: Used for all MySQL users
- **Strong Passwords**: Complex passwords for all accounts
- **Limited Privileges**: Application users have restricted database access

### Recommended Firewall Rules
```bash
# Ubuntu/Debian
sudo ufw allow 3307/tcp
sudo ufw allow 6033/tcp
sudo ufw allow 6032/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=3307/tcp
sudo firewall-cmd --permanent --add-port=6033/tcp
sudo firewall-cmd --permanent --add-port=6032/tcp
sudo firewall-cmd --reload
```

## 🚀 Deployment

### Prerequisites
- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 8GB RAM (recommended for InnoDB buffer pool)
- SSD storage (recommended for database performance)

### Directory Structure
```
mysql-cluster/
├── docker-compose.yml          # Main orchestration file
├── init/
│   ├── init-primary.sql       # Primary initialization script
│   └── init-replica.sql       # Replica initialization script
├── primary-cnf/
│   └── my.cnf                 # Primary MySQL configuration
├── replicat-cnf/
│   └── my.cnf                 # Replica MySQL configuration
├── proxysql/
│   └── proxysql.cnf           # ProxySQL configuration
├── primary-data/              # Primary data directory (created automatically)
├── replicat-data/             # Replica data directory (created automatically)
└── README.md                  # This documentation
```

### Deployment Commands
```bash
# 1. Clone/prepare the cluster directory
cd /path/to/mysql-cluster

# 2. Create data directories (if not exists)
mkdir -p primary-data replicat-data

# 3. Start the cluster
docker compose up -d

# 4. Verify deployment
docker compose ps
docker compose logs

# 5. Test connections
mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT 'ProxySQL Connection OK'"
mysql -h127.0.0.1 -P3307 -uroot -p2fF2P7xqVtc4iCExR -e "SELECT 'Direct MySQL OK'"
```

### Health Checks
```bash
# Check container status
docker compose ps

# Check replication status
docker exec -it mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"

# Check ProxySQL statistics
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_connection_pool;"
```

## 📊 Monitoring

### Key Metrics to Monitor

#### MySQL Metrics
```sql
-- Replication lag
SHOW SLAVE STATUS\G

-- Connection count
SHOW STATUS LIKE 'Threads_connected';

-- Query performance
SHOW STATUS LIKE 'Questions';
SHOW STATUS LIKE 'Slow_queries';

-- InnoDB metrics
SHOW STATUS LIKE 'Innodb_buffer_pool_pages_data';
SHOW STATUS LIKE 'Innodb_buffer_pool_pages_free';
```

#### ProxySQL Metrics
```sql
-- Connection statistics
SELECT * FROM stats_mysql_connection_pool;

-- Query statistics
SELECT * FROM stats_mysql_query_rules;

-- Server health
SELECT * FROM mysql_servers;
```

### Monitoring Commands
```bash
# Monitor MySQL processes
docker exec -it mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW PROCESSLIST;"

# Monitor ProxySQL routing
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_commands_counters WHERE Total_cnt > 0;"

# Check container resources
docker stats mysql-primary mysql-replica proxysql
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Replication Not Working
```bash
# Check replication status
docker exec -it mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW SLAVE STATUS\G"

# Check master status
docker exec -it mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "SHOW MASTER STATUS\G"

# Reset replication (if needed)
docker exec -it mysql-replica mysql -uroot -p2fF2P7xqVtc4iCExR -e "STOP SLAVE; RESET SLAVE ALL;"
```

#### 2. ProxySQL Connection Issues
```bash
# Check ProxySQL logs
docker logs proxysql

# Verify ProxySQL configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"

# Reload ProxySQL configuration
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK;"
```

#### 3. Performance Issues
```bash
# Check slow query log
docker exec -it mysql-primary tail -f /var/lib/mysql/mysql-slow.log

# Monitor connection pool
docker exec -it proxysql mysql -h127.0.0.1 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_connection_pool ORDER BY Queries DESC;"
```

### Log Locations
```bash
# MySQL logs
docker logs mysql-primary
docker logs mysql-replica

# ProxySQL logs
docker logs proxysql

# MySQL error logs (inside container)
/var/lib/mysql/error.log

# MySQL slow query logs (inside container)
/var/lib/mysql/mysql-slow.log
```

## ⚡ Performance Tuning

### MySQL Configuration Highlights

#### Connection & Memory
```ini
max_connections = 2000              # Adjust based on application needs
innodb_buffer_pool_size = 8G        # 70-80% of available RAM
innodb_buffer_pool_instances = 8    # Number of CPU cores
thread_cache_size = 128             # Connection thread caching
```

#### InnoDB Performance
```ini
innodb_flush_log_at_trx_commit = 2  # Balance between performance and durability
innodb_io_capacity = 1000           # Adjust based on storage IOPS
innodb_io_capacity_max = 2000       # Maximum IOPS for background tasks
innodb_flush_method = O_DIRECT      # Bypass OS file cache
```

#### Replication Performance
```ini
binlog_format = ROW                 # Most efficient for replication
sync_binlog = 1                     # Sync binary log to disk
max_binlog_size = 100M              # Rotate binary logs at 100MB
```

### ProxySQL Tuning
```ini
threads = 4                         # Number of worker threads
max_connections = 2048              # Maximum concurrent connections
```

### Monitoring Performance
```sql
-- Check buffer pool efficiency
SELECT 
  (1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests)) * 100 
  AS buffer_pool_hit_ratio
FROM information_schema.global_status 
WHERE variable_name IN ('Innodb_buffer_pool_reads', 'Innodb_buffer_pool_read_requests');

-- Check query cache hit ratio (if enabled)
SHOW STATUS LIKE 'Qcache_hits';
SHOW STATUS LIKE 'Qcache_inserts';
```

## 📞 Support & Maintenance

### Backup Strategy
```bash
# Full backup using mysqldump
docker exec mysql-primary mysqldump -uroot -p2fF2P7xqVtc4iCExR --all-databases --master-data=2 --single-transaction > backup_$(date +%Y%m%d_%H%M%S).sql

# Binary log backup for point-in-time recovery
docker exec mysql-primary mysqlbinlog mysql-bin.000001 > binlog_backup.sql
```

### Maintenance Tasks
```bash
# Update cluster
docker compose pull
docker compose up -d

# Clean old binary logs (keep 30 days)
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "PURGE BINARY LOGS BEFORE DATE(NOW() - INTERVAL 30 DAY);"

# Optimize tables
docker exec mysql-primary mysql -uroot -p2fF2P7xqVtc4iCExR -e "OPTIMIZE TABLE appdb.table_name;"
```

### Version Information
- **MySQL**: 8.0.42
- **ProxySQL**: 2.0
- **Docker Compose**: v2.0+
- **Documentation Version**: 1.0
- **Last Updated**: July 23, 2025

---

**For technical support, please refer to the troubleshooting section or contact the database administrator.**
