# MySQL Cluster Dashboard - README

## Overview

Dashboard web komprehensif untuk monitoring MySQL Cluster dengan ProxySQL yang menyediakan real-time monitoring, management tools, dan quick actions untuk administrasi cluster.

![Dashboard Architecture](https://via.placeholder.com/800x400?text=MySQL+Cluster+Dashboard+Architecture)

## Features

### 🏥 Real-time Cluster Monitoring
- **Health Score**: Algoritma scoring untuk cluster health
- **Service Status**: Live status ProxySQL, MySQL Primary, MySQL Replica
- **Replication Monitoring**: IO/SQL thread status, lag monitoring
- **Performance Metrics**: Connections, QPS, uptime tracking

### 📊 ProxySQL Integration
- **Backend Servers**: Real-time status dari MySQL backend servers
- **Query Rules**: Monitoring routing rules untuk read/write separation
- **Connection Pool**: Statistics dan utilization metrics
- **Admin Interface**: Integration dengan ProxySQL admin commands

### ⚡ Quick Actions
- **Health Check**: Instant cluster verification
- **Service Management**: Restart ProxySQL, Primary, Replica dengan safety checks
- **Backup System**: Automated database backup dengan compression
- **Log Monitoring**: Real-time log viewing untuk troubleshooting

### 🛠️ Management Tools
- **ProxySQL Web UI**: Direct access ke native ProxySQL interface
- **Admin SQL**: Connection info untuk MySQL client admin
- **API Endpoints**: RESTful API untuk integration
- **Mobile Responsive**: Optimized untuk semua device sizes

## Architecture Overview

```
┌─────────────────┐
│   Applications  │ ──┐
└─────────────────┘   │
                      │ MySQL Protocol (Port 6033)
┌─────────────────┐   │
│   Dashboard     │   │
│  (Port 5000)    │   │
└─────────────────┘   │
          │           │
          │ Admin SQL │
          ▼ (6032)    ▼
┌─────────────────────┐
│      ProxySQL       │
│   Load Balancer     │
└─────┬─────────┬─────┘
      │         │
      ▼         ▼
┌──────────┐ ┌──────────┐
│  MySQL   │ │  MySQL   │
│ Primary  │ │ Replica  │
│(R/W)     │ │(Read)    │
└──────────┘ └──────────┘
```

## Port Configuration

| Port | Service | Protocol | Purpose |
|------|---------|----------|---------|
| 5000 | Dashboard | HTTP | Web interface dan API |
| 6032 | ProxySQL Admin | MySQL | SQL administration |
| 6033 | ProxySQL Proxy | MySQL | Application connections |
| 6080 | ProxySQL Web | HTTP | Native ProxySQL UI |

## Quick Start

### 1. Deploy Dashboard
```bash
# Deploy dengan script otomatis
./deploy-dashboard.sh

# Atau manual deployment
cd web-ui
docker-compose up -d
```

### 2. Access Dashboard
```bash
# Web Dashboard
http://localhost:5000

# ProxySQL Web UI  
http://localhost:6080

# ProxySQL Admin (MySQL client required)
mysql -h localhost -P 6032 -u admin -padmin
```

### 3. Connect Applications
```bash
# Application connection via ProxySQL
mysql -h localhost -P 6033 -u your_user -pyour_password

# Automatic routing:
# - SELECT → Replica (read)
# - INSERT/UPDATE/DELETE → Primary (write)
```

## API Endpoints

### Monitoring
- `GET /health` - Dashboard health check
- `GET /api/metrics` - Comprehensive cluster metrics
- `GET /api/proxysql/backends` - ProxySQL backend servers

### Management
- `GET /api/actions/restart/<service>` - Restart service
- `GET /api/actions/backup` - Create database backup
- `GET /api/logs/<service>` - View service logs

### Example API Usage
```bash
# Get cluster metrics
curl http://localhost:5000/api/metrics

# Restart ProxySQL
curl http://localhost:5000/api/actions/restart/proxysql

# View ProxySQL logs
curl http://localhost:5000/api/logs/proxysql
```

## Configuration

### Environment Variables
Copy dan customize environment file:
```bash
cp web-ui/.env.example web-ui/.env
```

Key configurations:
```env
MYSQL_ROOT_PASSWORD=2fF2P7xqVtc4iCExR
PROXYSQL_ADMIN_USER=admin
PROXYSQL_ADMIN_PASSWORD=admin
AUTO_REFRESH_INTERVAL=30
```

### ProxySQL Admin Access
Dashboard menggunakan port 6032 untuk admin queries:
```sql
-- Check backend servers
SELECT * FROM mysql_servers;

-- Monitor query rules
SELECT * FROM mysql_query_rules;

-- View statistics
SELECT * FROM stats_mysql_global;
```

## Troubleshooting

### Common Issues

#### 1. ERR_INVALID_HTTP_RESPONSE pada Port 6032
**Penyebab**: Port 6032 adalah MySQL protocol, bukan HTTP
**Solusi**: Gunakan MySQL client, bukan browser
```bash
mysql -h localhost -P 6032 -u admin -padmin
```

#### 2. Dashboard Connection Failed
**Penyebab**: MySQL cluster belum ready
**Solusi**: 
```bash
# Check cluster status
docker ps | grep mysql

# Restart cluster jika perlu
docker-compose restart mysql-primary mysql-replica proxysql
```

#### 3. High Replication Lag
**Penyebab**: Network latency atau high load
**Solusi**: Monitor melalui dashboard dan optimize queries

### Debug Commands
```bash
# View dashboard logs
docker-compose logs mysql-dashboard

# Check container connectivity
docker exec mysql-dashboard ping proxysql

# Test ProxySQL admin connection
docker exec mysql-dashboard mysql -h proxysql -P 6032 -u admin -padmin -e "SELECT 1"
```

## Production Deployment

### Security Considerations
1. **Network Isolation**: Use internal Docker networks
2. **Authentication**: Implement proper MySQL user management
3. **HTTPS**: Configure reverse proxy dengan SSL
4. **Monitoring**: Integrate dengan external monitoring systems

### Performance Optimization
1. **Resource Limits**: Set appropriate CPU/memory limits
2. **Connection Pooling**: Optimize ProxySQL pool settings
3. **Query Optimization**: Monitor slow queries
4. **Backup Strategy**: Automated backup dengan retention

### Scaling
1. **Read Replicas**: Add multiple read replicas
2. **Load Balancing**: Configure ProxySQL weights
3. **Monitoring**: Scale monitoring infrastructure
4. **High Availability**: Multi-zone deployment

## Development

### Local Development
```bash
# Install dependencies
cd web-ui
pip install -r requirements.txt

# Run development server
export FLASK_ENV=development
python app.py
```

### Adding Features
1. **Backend**: Extend Flask API dalam `app.py`
2. **Frontend**: Modify `templates/dashboard.html`
3. **Monitoring**: Add new metrics collection
4. **Actions**: Implement new management actions

## Contributing

1. Fork repository
2. Create feature branch
3. Implement changes dengan tests
4. Submit pull request

## License

MIT License - See LICENSE file for details

---

**Note**: Dashboard ini dirancang khusus untuk MySQL Cluster dengan ProxySQL. Untuk database lain, modifikasi konfigurasi connection sesuai kebutuhan.
