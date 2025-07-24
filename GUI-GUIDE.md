# 🖥️ GUI Management Interfaces untuk MySQL Cluster

Comprehensive web-based management interfaces untuk MySQL Cluster dengan ProxySQL load balancing.

## 🌐 **Available GUI Tools**

### **1. 🎛️ ProxySQL Web UI**
**URL:** http://192.168.11.122:8080  
**Purpose:** ProxySQL configuration dan monitoring  
**Features:**
- Real-time ProxySQL statistics
- MySQL servers management
- Query rules configuration
- Connection pool monitoring
- User management

### **2. 🗄️ phpMyAdmin**
**URL:** http://192.168.11.122:8081  
**Login:** appuser / AppPass123!  
**Purpose:** Database management interface  
**Features:**
- Database browsing dan editing
- SQL query execution
- Import/Export data
- Table management
- Database administration

### **3. 📊 Grafana Dashboards**
**URL:** http://192.168.11.122:3000  
**Login:** admin / admin123  
**Purpose:** Advanced monitoring dan analytics  
**Features:**
- Real-time metrics visualization
- Custom dashboards
- Alert management
- Historical data analysis
- Performance trending

### **4. 📈 Prometheus Metrics**
**URL:** http://192.168.11.122:9090  
**Purpose:** Metrics collection dan querying  
**Features:**
- Raw metrics browsing
- PromQL query interface
- Target monitoring
- Alert rules management

### **5. 🌐 Custom Dashboard**
**URL:** http://192.168.11.122:8082  
**Purpose:** Unified cluster overview  
**Features:**
- All-in-one cluster status
- Quick access to all GUI tools
- Architecture overview
- One-click operations

## 🚀 **Quick Start**

### **Deploy with GUI**
```bash
# Deploy cluster with all GUI tools
./deploy.sh

# Or use CLI tool
./cluster-cli.sh
# Select: 9 (GUI Management)
```

### **Access URLs**
Setelah deployment selesai, akses GUI tools melalui:
- **Main Dashboard:** http://192.168.11.122:8082
- **ProxySQL UI:** http://192.168.11.122:8080
- **Database Admin:** http://192.168.11.122:8081
- **Monitoring:** http://192.168.11.122:3000

## 🎛️ **ProxySQL Web UI Guide**

### **Navigation**
- **Dashboard:** Overview status ProxySQL
- **Servers:** MySQL backend servers configuration
- **Rules:** Query routing rules
- **Users:** Database users management
- **Stats:** Real-time statistics

### **Key Features**
```
📊 Connection Pool Stats
├── Active connections per backend
├── Connection errors tracking
├── Query distribution
└── Response time metrics

🔧 Configuration Management
├── Add/remove MySQL servers
├── Modify query routing rules
├── User permissions management
└── Real-time configuration reload

📈 Performance Monitoring
├── Queries per second
├── Response time distribution
├── Error rate tracking
└── Backend health status
```

## 🗄️ **phpMyAdmin Usage**

### **Login Process**
1. Go to http://192.168.11.122:8081
2. Server: `proxysql` (auto-filled)
3. Username: `appuser`
4. Password: `AppPass123!`

### **Database Management**
```
📁 Database Operations
├── Browse appdb (main application database)
├── Browse db-mpp (analytics database)
├── Create/modify tables
└── Import/export data

🔍 Query Operations
├── SQL query execution
├── Query history
├── Result export (CSV, SQL, etc.)
└── Query optimization hints

👥 User Management (limited)
├── View user privileges
├── Change passwords
└── View connection info
```

### **Best Practices**
- ✅ Use for development dan staging
- ✅ Readonly operations in production
- ⚠️ Limited write operations in production
- ❌ Avoid structural changes in production

## 📊 **Grafana Dashboard Setup**

### **Initial Setup**
1. Access http://192.168.11.122:3000
2. Login: `admin` / `admin123`
3. Change default password (recommended)
4. Import pre-configured dashboards

### **Pre-configured Dashboards**
```
🏠 MySQL Cluster Overview
├── Cluster health status
├── Connection metrics
├── Query performance
└── Replication status

🎛️ ProxySQL Dashboard
├── Backend server status
├── Query routing statistics
├── Connection pool metrics
└── Error rate tracking

📈 Performance Analytics
├── Resource utilization
├── Slow query analysis
├── Capacity planning metrics
└── Historical trends
```

### **Custom Dashboard Creation**
```
1. Data Sources
   ├── Prometheus (metrics)
   ├── MySQL (direct queries)
   └── JSON APIs (custom data)

2. Panel Types
   ├── Time series graphs
   ├── Stat panels
   ├── Tables
   └── Alert panels

3. Variables
   ├── Time ranges
   ├── Server selection
   ├── Database selection
   └── Query filters
```

## 📈 **Prometheus Monitoring**

### **Available Metrics**
```
🗄️ MySQL Metrics
├── mysql_global_status_threads_connected
├── mysql_global_status_queries
├── mysql_slave_seconds_behind_master
└── mysql_global_status_slow_queries

🎛️ ProxySQL Metrics
├── proxysql_connection_pool_conn_used
├── proxysql_connection_pool_conn_free
├── proxysql_query_rules_hits
└── proxysql_backend_status

🖥️ System Metrics
├── node_memory_usage
├── node_cpu_usage
├── node_disk_usage
└── node_network_io
```

### **Query Examples**
```promql
# Current connections
mysql_global_status_threads_connected

# Query rate per second
rate(mysql_global_status_queries[5m])

# Replication lag
mysql_slave_seconds_behind_master

# ProxySQL connection usage
proxysql_connection_pool_conn_used / 
(proxysql_connection_pool_conn_used + proxysql_connection_pool_conn_free) * 100
```

## 🌐 **Custom Dashboard Features**

### **Main Interface**
```
🏠 Header Section
├── Cluster status overview
├── Quick health indicators
├── Real-time metrics
└── Architecture diagram

🔗 GUI Tools Section
├── One-click access to all tools
├── Tool descriptions
├── Status indicators
└── Direct links

💻 CLI Integration
├── Command examples
├── Quick actions
└── Help links
```

### **Interactive Features**
- **Real-time Metrics:** Auto-refresh every 5 seconds
- **Quick Actions:** Button-based operations
- **Status Indicators:** Color-coded health status
- **Responsive Design:** Mobile-friendly interface

## 🔧 **Configuration & Customization**

### **Port Configuration**
Default ports yang digunakan:
```
6033  - ProxySQL (application connection)
6032  - ProxySQL (admin interface)
8080  - ProxySQL Web UI
8081  - phpMyAdmin
3000  - Grafana
9090  - Prometheus
9104  - MySQL Exporter
8082  - Custom Dashboard
```

### **Security Configuration**
```
🔐 Authentication
├── ProxySQL: superman / Soleh1!
├── phpMyAdmin: appuser / AppPass123!
├── Grafana: admin / admin123
└── MySQL: appuser / AppPass123!

🌐 Network Access
├── All services accessible on host network
├── Internal Docker networking
├── Firewall configuration recommended
└── SSL/TLS support (configurable)
```

### **Customization Options**
```
🎨 UI Customization
├── Grafana theme dan branding
├── Custom dashboard styling
├── Logo dan color schemes
└── Layout modifications

🔧 Configuration
├── Metric collection intervals
├── Alert thresholds
├── Data retention policies
└── User access controls
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **GUI Not Accessible**
```bash
# Check container status
docker compose ps

# Check specific service
docker compose logs grafana
docker compose logs phpmyadmin

# Restart GUI services
docker compose restart grafana phpmyadmin
```

#### **Login Issues**
```bash
# Reset Grafana password
docker compose exec grafana grafana-cli admin reset-admin-password admin123

# Check phpMyAdmin connection
docker compose exec proxysql mysql -h127.0.0.1 -P6033 -uappuser -pAppPass123! -e "SELECT 1"
```

#### **Performance Issues**
```bash
# Check resource usage
docker stats

# Optimize Grafana
docker compose exec grafana grafana-cli plugins list-remote

# Clean up Prometheus data
docker volume prune
```

### **Health Checks**
```bash
# Automated GUI health check
./cluster-cli.sh
# Select: 9 (GUI Management) → 7 (Check GUI Services Status)

# Manual checks
curl -f http://192.168.11.122:8082 || echo "Custom Dashboard down"
curl -f http://192.168.11.122:3000 || echo "Grafana down"
curl -f http://192.168.11.122:8081 || echo "phpMyAdmin down"
```

## 📊 **Performance Optimization**

### **Resource Allocation**
```
🗄️ Database Containers
├── mysql-primary: 2-4GB RAM
├── mysql-replica: 1-3GB RAM
└── proxysql: 512MB-1GB RAM

🖥️ GUI Containers
├── grafana: 512MB RAM
├── prometheus: 1-2GB RAM
├── phpmyadmin: 256MB RAM
└── nginx: 128MB RAM
```

### **Optimization Tips**
- ✅ Configure Grafana data retention
- ✅ Optimize Prometheus scrape intervals
- ✅ Use persistent volumes for data
- ✅ Enable container restart policies
- ✅ Monitor resource usage regularly

## 🔄 **Backup & Maintenance**

### **GUI Data Backup**
```bash
# Backup Grafana dashboards
docker compose exec grafana curl -X GET http://admin:admin123@localhost:3000/api/dashboards/db/mysql-cluster

# Backup Prometheus data
docker run --rm -v prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz /data

# Backup custom configurations
tar czf gui-configs-backup.tar.gz grafana/ prometheus/ web-ui/
```

### **Regular Maintenance**
```bash
# Update GUI services
docker compose pull
docker compose up -d

# Clean up old data
docker system prune -f

# Check for updates
docker images | grep -E "(grafana|prometheus|phpmyadmin)"
```

## 📚 **Integration Examples**

### **API Integration**
```javascript
// Fetch Prometheus metrics
fetch('http://192.168.11.122:9090/api/v1/query?query=mysql_global_status_threads_connected')
  .then(response => response.json())
  .then(data => console.log(data));

// Grafana API example
fetch('http://admin:admin123@192.168.11.122:3000/api/dashboards/db/mysql-cluster')
  .then(response => response.json())
  .then(dashboard => console.log(dashboard));
```

### **Automation Scripts**
```bash
#!/bin/bash
# Check all GUI services
for service in grafana phpmyadmin web-dashboard prometheus; do
    if docker compose ps $service | grep -q "Up"; then
        echo "✅ $service is running"
    else
        echo "❌ $service is down"
        docker compose restart $service
    fi
done
```

## 🎯 **Best Practices**

### **Development Environment**
- ✅ Use all GUI tools for learning
- ✅ Experiment with configurations
- ✅ Create custom dashboards
- ✅ Test different scenarios

### **Production Environment**
- ✅ Restrict GUI access (VPN/firewall)
- ✅ Use readonly accounts where possible
- ✅ Monitor GUI resource usage
- ✅ Regular backup of configurations
- ✅ Enable HTTPS/SSL encryption

### **Security**
- ✅ Change default passwords
- ✅ Use strong authentication
- ✅ Limit network access
- ✅ Regular security updates
- ✅ Monitor access logs

---

**🖥️ Comprehensive GUI management untuk MySQL Cluster - Complete web-based administration!** 🚀

## 📋 **Quick Reference**

```bash
# Deploy with GUI
./deploy.sh

# Access main dashboard
open http://192.168.11.122:8082

# CLI GUI management
./cluster-cli.sh
# Select: 9 (GUI Management)

# Check GUI status
./cluster-cli.sh
# Select: 9 → 7 (Check GUI Services Status)
```
