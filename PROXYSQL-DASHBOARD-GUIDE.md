# ProxySQL Port Explanation dan MySQL Cluster Dashboard

## Mengapa Port 6032 ProxySQL Menghasilkan ERR_INVALID_HTTP_RESPONSE?

### Port 6032 - ProxySQL Admin SQL Interface
- **Tujuan**: Interface SQL untuk administrasi ProxySQL
- **Protokol**: MySQL Wire Protocol (bukan HTTP)
- **Akses**: Menggunakan MySQL client
- **Error di Browser**: `ERR_INVALID_HTTP_RESPONSE` karena browser mencoba HTTP request ke protokol MySQL

### Port 6080/8080 - ProxySQL Web UI (HTTP)
- **Tujuan**: Web interface untuk monitoring ProxySQL
- **Protokol**: HTTP
- **Akses**: Browser web
- **Fitur**: Grafik, statistik, konfigurasi visual

### Port 6033 - ProxySQL MySQL Proxy
- **Tujuan**: Koneksi aplikasi ke MySQL cluster
- **Protokol**: MySQL Wire Protocol
- **Akses**: Aplikasi menggunakan MySQL driver
- **Routing**: Otomatis ke Primary/Replica berdasarkan query

## Cara Mengakses ProxySQL Admin (Port 6032)

```bash
# Menggunakan MySQL client
mysql -h localhost -P 6032 -u admin -padmin

# Contoh perintah admin ProxySQL
SELECT * FROM mysql_servers;
SELECT * FROM mysql_query_rules;
SELECT * FROM stats_mysql_global;
```

## MySQL Cluster Dashboard Architecture

```
┌─────────────────┐
│   Applications  │
└─────────┬───────┘
          │ MySQL Protocol
          ▼
┌─────────────────┐    Port 6032 (Admin SQL)
│    ProxySQL     │◄─── MySQL Client Admin
│  Load Balancer  │    Port 6080 (Web UI)
└─────┬─────┬─────┘    Port 6033 (MySQL Proxy)
      │     │
      ▼     ▼
┌──────────┐ ┌──────────┐
│  MySQL   │ │  MySQL   │
│ Primary  │ │ Replica  │
│(Read/Write)│ │(Read Only)│
└──────────┘ └──────────┘
```

## Dashboard Features

### 🏥 Real-time Health Monitoring
- **Cluster Health Score**: Algoritma scoring berdasarkan status semua komponen
- **Service Status**: Online/Offline status untuk ProxySQL, Primary, Replica
- **Replication Monitoring**: IO/SQL thread status, replication lag
- **Connection Metrics**: Active connections, queries per second

### 📊 ProxySQL Metrics
- **Backend Servers**: Status dan health check MySQL servers
- **Query Rules**: Routing rules untuk read/write separation
- **Connection Pool**: Connection utilization dan performance
- **Query Statistics**: QPS, slow queries, error rates

### ⚡ Quick Actions
- **Health Check**: Instant cluster status verification
- **Service Restart**: Safe restart dengan konfirmasi
- **Database Backup**: Automated mysqldump dengan compression
- **Log Monitoring**: Real-time log viewing untuk troubleshooting

### 🔧 Management Tools Integration
- **ProxySQL Web UI**: Native interface di port 6080
- **Admin SQL Access**: Connection information untuk MySQL client
- **Dashboard**: Centralized monitoring di port 5000

## Implementation Details

### Backend Flask API
```python
# ProxySQL Admin Connection
PROXYSQL_CONFIG = {
    'host': 'proxysql',
    'port': 6032,        # SQL Admin Port
    'user': 'admin',
    'password': 'admin'
}

# Real-time Metrics Collection
def check_proxysql_status():
    conn = pymysql.connect(**PROXYSQL_CONFIG)
    cursor.execute("SELECT * FROM mysql_servers")
    backends = cursor.fetchall()
    return backends
```

### Frontend Real-time Updates
- **Auto-refresh**: 30 detik interval (configurable)
- **WebSocket**: Untuk real-time updates (future enhancement)
- **Responsive Design**: Mobile-friendly interface
- **Dark/Light Theme**: User preference support

### Security Considerations
- **Internal Network**: Dashboard hanya accessible dalam Docker network
- **Admin Credentials**: Stored dalam environment variables
- **Action Confirmation**: Destructive operations require confirmation
- **Audit Log**: All administrative actions logged

## Deployment

### Quick Start
```bash
# Build dan start dashboard
cd web-ui
docker-compose up -d

# Access dashboard
http://localhost:5000
```

### Port Mapping
- **5000**: MySQL Cluster Dashboard (Flask)
- **6032**: ProxySQL Admin SQL (MySQL Protocol)
- **6033**: ProxySQL MySQL Proxy (Application Connection)
- **6080**: ProxySQL Web UI (HTTP)
- **8080**: Additional Web Interface (Nginx)

### Monitoring Endpoints
- **Health Check**: `GET /health`
- **Metrics API**: `GET /api/metrics`
- **Service Restart**: `GET /api/actions/restart/<service>`
- **Backup**: `GET /api/actions/backup`
- **Logs**: `GET /api/logs/<service>`

## Best Practices

### Production Deployment
1. **Resource Limits**: Set appropriate CPU/memory limits
2. **Log Rotation**: Configure log rotation untuk disk space
3. **Backup Strategy**: Automated backup dengan retention policy
4. **Monitoring**: Integrate dengan external monitoring (Prometheus/Grafana)
5. **Security**: Use HTTPS, authentication, network isolation

### Troubleshooting
1. **Connection Issues**: Check network connectivity antara containers
2. **Permission Errors**: Verify MySQL user privileges
3. **High Replication Lag**: Monitor disk I/O dan network latency
4. **ProxySQL Errors**: Check admin interface untuk backend status

### Scaling Considerations
- **Read Replicas**: Add additional read replicas through ProxySQL
- **Connection Pooling**: Optimize ProxySQL connection pool settings
- **Query Optimization**: Monitor slow queries dan optimize
- **Hardware Resources**: Scale CPU/RAM berdasarkan monitoring data
