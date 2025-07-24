# 🎛️ MySQL Cluster CLI Management Tool

Interactive command-line interface untuk comprehensive management dan monitoring MySQL Cluster dengan ProxySQL.

## 🚀 **Quick Start**

```bash
# Make executable
chmod +x cluster-cli.sh

# Launch interactive mode
./cluster-cli.sh

# Quick status check
./cluster-cli.sh status

# Show help
./cluster-cli.sh --help
```

## 📋 **Features Overview**

### **1. 📊 Cluster Status Overview**
- Container status dan health check
- Network configuration
- Quick connectivity test ke semua services
- Summary kesehatan cluster

### **2. 🔍 ProxySQL Status & Configuration**
- ProxySQL server status dan version
- MySQL servers configuration
- Connection pool statistics
- Query routing rules
- User management
- Real-time connection metrics

### **3. 🗄️ MySQL Primary Status**
- Server information dan configuration
- Master status dan binary logs
- Database list dengan size information
- Current connections dan performance metrics
- Error log analysis

### **4. 🗄️ MySQL Replica Status**
- Server information dan configuration
- Slave status detailed information
- Replication lag monitoring
- Database synchronization check
- Error log analysis

### **5. 🔗 Replication Status**
- GTID status comparison (Primary vs Replica)
- Detailed replication health check
- Automatic replication testing
- Lag monitoring dan analysis
- Replication troubleshooting

### **6. 📈 Performance Monitoring**
- System resource usage (CPU, Memory, Disk)
- Docker container resource metrics
- MySQL performance statistics
- ProxySQL query statistics
- Slow query analysis
- Connection pool performance

### **7. 🔧 Cluster Operations**
- Start/Stop/Restart cluster
- View logs (selective atau all services)
- Clean restart dengan data deletion
- Database backup operations
- Replication reset
- Service management

### **8. 🚀 Load Testing**
- Quick Test: 100 connections, 60 seconds
- Standard Test: 500 connections, 300 seconds
- Heavy Test: 1000 connections, 600 seconds
- Maximum Test: 1500 connections, 600 seconds
- Custom Test: User-defined parameters
- Automatic test data preparation dan cleanup

### **9. 📚 Documentation**
- Built-in documentation viewer
- Direct access ke semua markdown files
- Browser integration untuk dokumentasi
- Quick reference guide

### **10. 🔧 Troubleshooting**
- Full diagnostic scan
- ProxySQL routing fixes
- Replication issue resolution
- Network connectivity testing
- Resource usage analysis
- Error log analysis
- Resource cleanup utilities

## 🎯 **Interactive Menu Navigation**

### **Main Menu Options**
```
1.  📊 Cluster Status Overview
2.  🔍 ProxySQL Status & Configuration  
3.  🗄️  MySQL Primary Status
4.  🗄️  MySQL Replica Status
5.  🔗 Replication Status
6.  📈 Performance Monitoring
7.  🔧 Cluster Operations
8.  🚀 Load Testing
9.  📚 Documentation
10. 🔧 Troubleshooting
0.  ❌ Exit
```

### **Navigation Tips**
- Gunakan angka untuk memilih menu
- Tekan **Enter** untuk melanjutkan setelah output
- Pilih **0** untuk kembali ke menu utama
- **Ctrl+C** untuk exit emergency

## 🔧 **Detailed Feature Guide**

### **Cluster Status Overview**
```bash
./cluster-cli.sh
# Pilih: 1
```
**Output:**
- Status semua containers (Up/Down/Restart)
- Network configuration details
- Quick health check ke ProxySQL, Primary, Replica
- Color-coded status indicators

### **ProxySQL Status & Configuration**
```bash
./cluster-cli.sh  
# Pilih: 2
```
**Output:**
- ProxySQL version dan admin access
- MySQL servers list dengan status
- Connection pool statistics (Used/Free/OK/Error)
- Query routing rules configuration
- User configuration dan permissions

### **MySQL Primary Status**
```bash
./cluster-cli.sh
# Pilih: 3
```
**Output:**
- MySQL version, server_id, read_only status
- Master position dan binary log files
- Database sizes dan table count
- Current connections vs max_connections
- Recent error analysis

### **MySQL Replica Status**
```bash
./cluster-cli.sh
# Pilih: 4
```
**Output:**
- MySQL version, server_id, read_only status
- Complete slave status information
- Replication lag calculation
- Database synchronization status
- Error log monitoring

### **Replication Status**
```bash
./cluster-cli.sh
# Pilih: 5
```
**Output:**
- GTID executed comparison
- Detailed replication health metrics
- Automatic replication test dengan real data
- Lag analysis dan recommendations
- Troubleshooting suggestions

### **Performance Monitoring**
```bash
./cluster-cli.sh
# Pilih: 6
```
**Output:**
- System resources (Memory, Disk, CPU)
- Docker container resource usage
- MySQL performance counters
- ProxySQL query statistics
- Top 5 slowest queries
- Performance recommendations

### **Cluster Operations**
```bash
./cluster-cli.sh
# Pilih: 7
```
**Sub-menu:**
```
1. 🚀 Start Cluster
2. ⏹️  Stop Cluster  
3. 🔄 Restart Cluster
4. 📊 View Logs
5. 🧹 Clean Restart
6. 💾 Backup Database
7. 🔄 Reset Replication
```

### **Load Testing**
```bash
./cluster-cli.sh
# Pilih: 8
```
**Test Options:**
- **Quick Test:** 100 connections, 60s - Development testing
- **Standard Test:** 500 connections, 300s - Staging validation  
- **Heavy Test:** 1000 connections, 600s - Production simulation
- **Maximum Test:** 1500 connections, 600s - Capacity testing
- **Custom Test:** User-defined parameters

**Load Test Features:**
- Automatic test data preparation
- Real-time progress monitoring
- Performance metrics collection
- Automatic cleanup after test
- Results analysis dan recommendations

### **Documentation Access**
```bash
./cluster-cli.sh
# Pilih: 9
```
**Available Docs:**
- README.md - Project overview
- DEPLOYMENT.md - Step-by-step deployment  
- DEPLOYMENT-UPDATED.md - Comprehensive guide
- LARAVEL-INTEGRATION.md - Laravel setup
- PRODUCTION-OPS.md - Operations guide
- DOCUMENTATION-INDEX.md - Complete index

### **Troubleshooting**
```bash
./cluster-cli.sh
# Pilih: 10
```
**Troubleshooting Options:**
```
1. 🔍 Run Full Diagnostic
2. 🔧 Fix ProxySQL Routing
3. 🔄 Fix Replication Issues  
4. 🌐 Test Network Connectivity
5. 📊 Check Resource Usage
6. 🔍 Analyze Error Logs
7. 🧹 Clean Up Resources
```

## 🎨 **Color Coding System**

- 🟢 **Green (Success):** ✅ Operations completed successfully
- 🟡 **Yellow (Warning):** ⚠️ Issues that need attention
- 🔴 **Red (Error):** ❌ Critical issues requiring immediate action
- 🔵 **Blue (Info):** ℹ️ Informational messages
- 🟣 **Purple (Header):** Section headers dan titles
- 🔷 **Cyan (Section):** Sub-section identifiers

## 🔧 **Configuration**

### **Default Settings**
```bash
# ProxySQL Configuration
PROXYSQL_HOST="127.0.0.1"
PROXYSQL_PORT="6033"
PROXYSQL_ADMIN_PORT="6032"
PROXYSQL_ADMIN_USER="superman"
PROXYSQL_ADMIN_PASS="Soleh1!"

# MySQL Configuration  
MYSQL_ROOT_PASS="RootPass123!"
APP_USER="appuser"
APP_PASS="AppPass123!"
```

### **Customization**
Edit file `cluster-cli.sh` bagian "Configuration" untuk menyesuaikan:
- Connection parameters
- Password credentials
- Timeout settings
- Default test parameters

## 🚀 **Advanced Usage**

### **Command Line Arguments**
```bash
# Interactive mode (default)
./cluster-cli.sh

# Quick status check
./cluster-cli.sh status

# Show help information
./cluster-cli.sh --help
```

### **Integration dengan Scripts Lain**
```bash
# Gunakan dalam automation
if ./cluster-cli.sh status | grep -q "Cluster is running"; then
    echo "Cluster healthy, proceeding with deployment"
else
    echo "Cluster issue detected, running diagnostics"
    ./cluster-cli.sh # Launch interactive mode for debugging
fi
```

### **Batch Operations**
```bash
# Multiple quick checks
./cluster-cli.sh status
sleep 5
./cluster-cli.sh status

# Integration dengan monitoring
watch -n 30 "./cluster-cli.sh status"
```

## 🔍 **Troubleshooting CLI Issues**

### **Permission Issues**
```bash
# Make sure script is executable
chmod +x cluster-cli.sh

# Check file permissions
ls -la cluster-cli.sh
```

### **Docker Connection Issues**
```bash
# Verify Docker is running
docker --version
docker compose --version

# Check if in correct directory
ls -la docker-compose.yml
```

### **MySQL Client Issues**
```bash
# Install MySQL client if missing
sudo apt install mysql-client

# Or use via Docker
docker compose exec proxysql mysql --version
```

## 📊 **Performance Tips**

### **Optimal Usage**
- Gunakan **Quick Status** untuk monitoring rutin
- **Full Diagnostic** hanya saat troubleshooting
- **Load Testing** di environment terpisah
- **Performance Monitoring** secara berkala

### **Resource Management**
- CLI menggunakan minimal system resources
- Database queries dioptimasi untuk speed
- Output dibatasi untuk readability
- Connection pooling untuk efficiency

## 🎯 **Best Practices**

### **Daily Operations**
1. **Morning Check:** `./cluster-cli.sh status`
2. **Performance Review:** Menu option 6 (weekly)
3. **Load Testing:** Menu option 8 (sebelum deployment)
4. **Backup Verification:** Menu option 7 → 6

### **Troubleshooting Workflow**
1. **Quick Status:** Identify issue scope
2. **Full Diagnostic:** Comprehensive analysis
3. **Specific Fixes:** Target specific issues
4. **Verification:** Confirm resolution

### **Monitoring Integration**
```bash
# Cron job untuk monitoring
*/5 * * * * /path/to/cluster-cli.sh status >> /var/log/cluster-status.log

# Alert on failures
./cluster-cli.sh status || mail -s "Cluster Alert" admin@company.com
```

## 📚 **Related Documentation**

- **[README.md](README.md)** - Main project overview
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Deployment procedures  
- **[PRODUCTION-OPS.md](PRODUCTION-OPS.md)** - Production operations
- **[DOCUMENTATION-INDEX.md](DOCUMENTATION-INDEX.md)** - Complete documentation index

---

**🎛️ MySQL Cluster CLI Tool - Complete management solution untuk MySQL Cluster operations!** 🚀
