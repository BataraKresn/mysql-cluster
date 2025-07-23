# 🚀 MySQL Cluster Deployment Guide - Updated

Panduan lengkap untuk deployment MySQL Cluster dengan ProxySQL dalam environment production.

## 📋 **Prerequisites**

### **Sistem Requirements**
- Ubuntu 20.04+ atau CentOS 8+
- Docker 24.0+ dan Docker Compose v2
- Minimum 16GB RAM, 100GB storage
- MySQL Client dan sysbench terinstall

### **Network Requirements**
- Port 6033 (ProxySQL) accessible dari aplikasi
- Port 6032 (ProxySQL Admin) untuk management
- Internal Docker network untuk komunikasi antar service

## 🔧 **Installation Steps**

### **1. System Preparation**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y docker.io docker-compose-v2 mysql-client sysbench

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
mysql --version
sysbench --version
```

### **2. Clone & Setup Project**
```bash
# Clone repository
git clone https://github.com/BataraKresn/mysql-cluster.git
cd mysql-cluster

# Set permissions
chmod +x *.sh

# Create data directories (akan otomatis dibuat by deploy script)
sudo mkdir -p primary-data replicat-data
sudo chown -R 999:999 primary-data replicat-data
```

### **3. Configuration Review**

#### **Network Configuration**
File: `deploy.sh`
```bash
# Update IP host sesuai server Anda
PROXYSQL_HOST="192.168.11.122"  # Ganti dengan IP server Anda
```

#### **MySQL Configuration**
Files: `primary-cnf/my.cnf`, `replicat-cnf/my.cnf`
- GTID enabled untuk replication
- Performance tuning untuk 2000+ connections
- Security hardening

#### **ProxySQL Configuration**
File: `proxysql/proxysql.cnf`
- Load balancing rules
- Query routing (SELECT → Replica, WRITE → Primary)
- Connection pooling
- Monitoring setup

### **4. Deployment Options**

#### **Option A: Full Deployment dengan Load Testing**
```bash
./deploy.sh
```
Includes:
- ✅ Prerequisites check
- ✅ Container deployment
- ✅ Replication setup dengan auto-sync
- ✅ Load testing 1500-2000 users
- ✅ Performance monitoring
- ✅ Report generation

#### **Option B: Deploy Only (Tanpa Testing)**
```bash
./deploy.sh --deploy-only
```

#### **Option C: Load Test Only (Cluster sudah running)**
```bash
./deploy.sh --load-test-only
```

#### **Option D: Clean Restart (Reset semua data)**
```bash
./clean-restart.sh
```
⚠️ **WARNING: Ini akan menghapus semua data MySQL!**

## 🔍 **Post-Deployment Verification**

### **1. Container Status**
```bash
docker compose ps
```
Expected output:
```
NAME            IMAGE                       STATUS
mysql-primary   mysql:8.0.42                Up
mysql-replica   mysql:8.0.42                Up  
proxysql        severalnines/proxysql:2.0   Up
```

### **2. Replication Status**
```bash
docker exec mysql-replica mysql -pRootPass123! -e "SHOW REPLICA STATUS\G" | grep -E "(Replica_IO_Running|Replica_SQL_Running|Seconds_Behind_Source)"
```
Expected:
```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Seconds_Behind_Source: 0
```

### **3. Database Sync Verification**
```bash
# Test write di Primary
docker exec mysql-primary mysql -pRootPass123! -e "USE appdb; INSERT INTO test_table (name) VALUES ('sync_test');"

# Check di Replica
docker exec mysql-replica mysql -pRootPass123! -e "USE appdb; SELECT * FROM test_table WHERE name='sync_test';"
```

### **4. ProxySQL Connection Test**
```bash
# Test from application perspective
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "
SELECT 'ProxySQL Connection OK' as status;
SHOW DATABASES;
"
```

### **5. Query Routing Test**
```bash
# Test read query (should go to replica)
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "SELECT @@hostname as server, 'READ_QUERY' as type;"

# Check ProxySQL stats
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_connection_pool;"
```

## 📊 **Monitoring Setup**

### **Real-time Monitoring**
```bash
# Start monitoring dashboard
./monitor_loadtest.sh
```

### **Health Checks**
```bash
# Automated health check
./health_check.sh

# Manual checks
docker logs proxysql --tail 50
docker logs mysql-primary --tail 50
docker logs mysql-replica --tail 50
```

### **Performance Monitoring**
```bash
# Container resource usage
docker stats

# MySQL performance
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "
SELECT * FROM stats_mysql_query_digest 
ORDER BY sum_time DESC LIMIT 10;
"
```

## 🚨 **Troubleshooting**

### **Common Issues & Solutions**

#### **1. Replication Not Working**
```bash
# Symptoms: Replica_IO_Running: No atau Replica_SQL_Running: No

# Solution:
docker exec mysql-replica mysql -pRootPass123! -e "
STOP REPLICA;
RESET REPLICA;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql-primary',
  SOURCE_USER='repl',
  SOURCE_PASSWORD='replpass',
  SOURCE_AUTO_POSITION=1;
START REPLICA;
"

# Re-sync data
./deploy.sh  # Will auto-sync existing data
```

#### **2. ProxySQL Connection Denied**
```bash
# Symptoms: ERROR 1045 (28000): Access denied

# Check ProxySQL users
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_users;"

# Refresh user config
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
"
```

#### **3. Container Won't Start**
```bash
# Check logs
docker logs mysql-primary
docker logs mysql-replica
docker logs proxysql

# Check permissions
sudo chown -R 999:999 primary-data replicat-data

# Restart containers
docker compose restart
```

#### **4. Database Not Synced**
```bash
# Manual sync existing data
docker exec mysql-primary mysqldump -pRootPass123! --single-transaction --all-databases > /tmp/backup.sql
docker cp mysql-primary:/tmp/backup.sql ./manual_sync.sql
docker cp ./manual_sync.sql mysql-replica:/tmp/restore.sql
docker exec mysql-replica mysql -pRootPass123! < /tmp/restore.sql
```

## 🔧 **Customization**

### **Changing IP Address**
1. Update `PROXYSQL_HOST` in `deploy.sh`
2. Update connection strings in application
3. Restart cluster

### **Adding More Replicas**
1. Add new service in `docker-compose.yml`
2. Update ProxySQL configuration
3. Add to monitoring scripts

### **Performance Tuning**
1. Adjust `my.cnf` parameters
2. Update ProxySQL connection limits
3. Optimize query rules

## 📈 **Production Deployment Checklist**

- [ ] Server resources adequate (16GB+ RAM, 100GB+ storage)
- [ ] Network security configured (firewall, VPN if needed)
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured
- [ ] Load testing completed successfully
- [ ] Disaster recovery plan documented
- [ ] Team trained on operational procedures

## 🔄 **Maintenance Procedures**

### **Regular Backups**
```bash
./backup.sh
```

### **Health Monitoring**
```bash
# Run weekly
./health_check.sh > health_$(date +%Y%m%d).log
```

### **Performance Reviews**
```bash
# Run monthly
./monitor_loadtest.sh > performance_$(date +%Y%m%d).log
```

---

**Deployment berhasil! Cluster siap untuk production dengan 1500-2000 concurrent users.** 🚀
