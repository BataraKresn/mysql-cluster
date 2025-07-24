# 🚀 MySQL Cluster dengan ProxySQL - Production Ready

Implementasi MySQL Cluster dengan High Availability menggunakan Master-Slave Replication dan ProxySQL Load Balancer untuk aplikasi production dengan kapasitas 1500-2000 concurrent users.

## 🏗️ **Arsitektur Sistem**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Application   │    │  External Apps  │    │     Laravel     │
│   (Any Client)  │    │   (Navicat)     │    │   Framework     │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │      ProxySQL             │
                    │   (192.168.11.122:6033)  │
                    │   Load Balancer           │
                    │   Query Routing           │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │     Docker Network        │
                    │    (172.20.0.0/16)       │
                    └─────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼───────┐      ┌────────▼────────┐      ┌────────▼────────┐
│ MySQL Primary │      │ MySQL Replica   │      │   ProxySQL      │
│ (172.20.0.10) │◄────►│ (172.20.0.11)   │      │ (172.20.0.12)   │
│ WRITE Server  │      │ READ Server     │      │ Query Router    │
│ Port: 3306    │      │ Port: 3306      │      │ Port: 6033      │
└───────────────┘      └─────────────────┘      └─────────────────┘
```

## ✨ **Fitur Utama**

### 🔥 **High Availability & Performance**
- ✅ **MySQL 8.0.42** dengan GTID Replication
- ✅ **ProxySQL 2.0** untuk Load Balancing dan Query Routing
- ✅ **Automatic Read/Write Split**: SELECT → Replica, INSERT/UPDATE/DELETE → Primary
- ✅ **Connection Pooling** untuk optimasi koneksi
- ✅ **Health Monitoring** otomatis untuk failover

### 🛡️ **Security & Network**
- ✅ **No External MySQL Ports**: Semua akses melalui ProxySQL
- ✅ **Service Name Resolution**: Tidak hardcode IP address
- ✅ **Multiple Authentication**: mysql_native_password & caching_sha2_password
- ✅ **Isolated Docker Network** dengan custom subnet

### ⚡ **Load Testing Ready**
- ✅ **Tested untuk 1500-2000 concurrent users**
- ✅ **Automated deployment script** dengan load testing
- ✅ **Real-time monitoring** dengan resource tracking
- ✅ **Sysbench integration** untuk performance testing

### 🔧 **Production Features**
- ✅ **Docker Compose v2** dengan health checks
- ✅ **Persistent data storage** dengan volume mapping
- ✅ **Automated replication setup** dengan data sync
- ✅ **Clean restart capability** untuk maintenance
- ✅ **Comprehensive logging** dan monitoring

## 📦 **Quick Start**

### **1. Clone Repository**
```bash
git clone https://github.com/BataraKresn/mysql-cluster.git
cd mysql-cluster
```

### **2. Deploy Cluster (Otomatis)**
```bash
# Full deployment dengan load testing
./deploy.sh

# Atau hanya deployment tanpa testing
./deploy.sh --deploy-only
```

### **3. Clean Restart (Jika Diperlukan)**
```bash
# HATI-HATI: Ini akan menghapus semua data!
./clean-restart.sh
```

## 🔌 **Koneksi Database**

### **Untuk Aplikasi (Recommended)**
```bash
Host: 192.168.11.122
Port: 6033
Username: appuser
Password: AppPass123!
Database: appdb atau db-mpp
```

### **Untuk Laravel Framework**
```env
DB_CONNECTION=mysql
DB_HOST=192.168.11.122
DB_PORT=6033
DB_DATABASE=appdb
DB_USERNAME=appuser
DB_PASSWORD=AppPass123!
```

### **Untuk Tools (Navicat, phpMyAdmin, dll)**
```
Host: 192.168.11.122
Port: 6033
User: appuser atau root
Password: AppPass123! atau RootPass123!
```

## 📊 **Database Available**
- `appdb` - Database aplikasi utama
- `db-mpp` - Database untuk aplikasi MPP
- System databases (mysql, information_schema, dll)

## 🎯 **Query Routing Otomatis**
ProxySQL akan otomatis memisahkan query:
- **READ (SELECT)** → MySQL Replica (172.20.0.11)
- **WRITE (INSERT/UPDATE/DELETE)** → MySQL Primary (172.20.0.10)

## 📋 **Management Commands**

### **Monitoring Cluster**
```bash
# Real-time monitoring
./monitor_loadtest.sh

# Check container status
docker compose ps

# Check replication status
docker exec mysql-replica mysql -pRootPass123! -e "SHOW REPLICA STATUS\G"
```

### **ProxySQL Admin**
```bash
# Connect to ProxySQL admin
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1!

# Check connection pool
SELECT * FROM stats_mysql_connection_pool;

# Check query routing
SELECT * FROM stats_mysql_query_digest ORDER BY sum_time DESC LIMIT 10;
```

### **Health Checks**
```bash
# Test connections
./health_check.sh

# Test from another server
./test-navicat-connection.sh
```

## 🚀 **Load Testing**

Deploy script sudah include load testing untuk:
- **1500-2000 concurrent users**
- **Multiple test scenarios** (read-only, write-heavy, mixed)
- **Real-time monitoring** selama testing
- **Performance reports** otomatis

## 📁 **Struktur Project**

```
mysql-cluster/
├── 📄 docker-compose.yml          # Container orchestration
├── 📁 primary-cnf/
│   └── my.cnf                    # MySQL Primary configuration
├── 📁 replicat-cnf/
│   └── my.cnf                    # MySQL Replica configuration
├── 📁 proxysql/
│   └── proxysql.cnf              # ProxySQL configuration
├── 📁 init/
│   ├── init-primary.sql          # Primary initialization
│   └── init-replica.sql          # Replica initialization
├── 📁 primary-data/              # Primary data volume
├── 📁 replicat-data/             # Replica data volume
├── 🚀 deploy.sh                  # Main deployment script
├── 🔄 clean-restart.sh           # Clean restart script
├── 📊 monitor_loadtest.sh        # Real-time monitoring
├── 🏥 health_check.sh            # Health check script
├── 🔧 backup.sh                  # Backup script
├── 📋 test-navicat-connection.sh # Connection test
├── 📄 laravel-database-config.php # Laravel config
├── 📄 laravel-env-example        # Laravel .env example
├── 📄 phpmyadmin-config.inc.php  # phpMyAdmin config
└── 📚 docs/                      # Documentation
    ├── README.md
    ├── DEPLOYMENT.md
    ├── CONFIG_SUMMARY.md
    ├── QUICKSTART.md
    ├── DEPLOY_GUIDE.md
    └── OPERATIONS.md
```

## 🔧 **Troubleshooting**

### **Replication Issues**
```bash
# Check replication status
docker exec mysql-replica mysql -pRootPass123! -e "SHOW REPLICA STATUS\G"

# Restart replication if needed
docker exec mysql-replica mysql -pRootPass123! -e "STOP REPLICA; START REPLICA;"

# Manual sync if data not in sync
./deploy.sh  # Will auto-sync existing data
```

### **Connection Issues**
```bash
# Test ProxySQL connection
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "SELECT 'OK' as status;"

# Check ProxySQL admin
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM mysql_servers;"

# Check container logs
docker logs proxysql
docker logs mysql-primary
docker logs mysql-replica
```

### **Performance Issues**
```bash
# Check resource usage
docker stats

# Monitor ProxySQL stats
mysql -h192.168.11.122 -P6032 -usuperman -pSoleh1! -e "SELECT * FROM stats_mysql_connection_pool;"

# Run load test
./deploy.sh --load-test-only
```

## 🚨 **Important Notes**

### **Security**
- MySQL Primary tidak expose port eksternal untuk keamanan
- Semua koneksi harus melalui ProxySQL (port 6033)
- User passwords sudah dikonfigurasi dengan strong password

### **Data Persistence**
- Data MySQL disimpan di `primary-data/` dan `replicat-data/`
- Backup otomatis dapat dijalankan dengan `./backup.sh`
- Clean restart akan menghapus semua data!

### **Network**
- Cluster menggunakan custom Docker network (172.20.0.0/16)
- Service name resolution untuk komunikasi antar container
- ProxySQL accessible dari IP host server (192.168.11.122)

## 📖 **Documentation Links**

- [📋 Deployment Guide](docs/DEPLOY_GUIDE.md) - Langkah detail deployment
- [⚙️ Configuration Summary](docs/CONFIG_SUMMARY.md) - Ringkasan konfigurasi
- [🚀 Quick Start Guide](docs/QUICKSTART.md) - Panduan cepat
- [🔧 Operations Manual](docs/OPERATIONS.md) - Manual operasional

## 🆘 **Support**

Jika mengalami masalah:
1. Cek logs container: `docker logs <container_name>`
2. Jalankan health check: `./health_check.sh`
3. Test koneksi: `./test-navicat-connection.sh`
4. Monitor real-time: `./monitor_loadtest.sh`

---

**Cluster MySQL Production Ready dengan 1500-2000 concurrent users support!** 🚀
