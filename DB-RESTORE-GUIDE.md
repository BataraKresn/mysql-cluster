# Database Restore Documentation - db-mpp

## Overview
Dokumentasi lengkap untuk restore database `dp_mpp-24072025.sql` ke MySQL Cluster dengan nama database `db-mpp` melalui ProxySQL.

## File Information
- **Source File**: `dp_mpp-24072025.sql`
- **File Size**: 7.1GB
- **Target Database**: `db-mpp`
- **Restore Method**: Via ProxySQL Load Balancer

## Network Configuration
- **ProxySQL Host**: 192.168.11.122
- **ProxySQL MySQL Port**: 6033
- **ProxySQL Admin Port**: 6032

## Connection Details
```bash
# MySQL Connection via ProxySQL
Host: 192.168.11.122
Port: 6033
Database: db-mpp
Username: root
Password: 2fF2P7xqVtc4iCExR
```

## Scripts Created

### 1. Main Restore Script
**File**: `simple-restore-db-mpp.sh`
- Drops existing `db-mpp` database if exists
- Creates new `db-mpp` database with UTF8MB4 charset
- Processes large SQL file with optimized settings
- Provides progress feedback and verification

### 2. Advanced Restore Script  
**File**: `restore-db-mpp.sh`
- Includes backup functionality for existing database
- Configures ProxySQL query routing rules
- Comprehensive error handling and logging
- Connection examples generation

### 3. Progress Monitor
**File**: `monitor-restore.sh`
- Real-time monitoring of restore progress
- Shows table count and database size
- Displays active processes

## Restore Process Steps

### Step 1: Prepare Environment
```bash
# Make scripts executable
chmod +x simple-restore-db-mpp.sh
chmod +x restore-db-mpp.sh  
chmod +x monitor-restore.sh
```

### Step 2: Execute Restore
```bash
# Start restore (background process for large files)
./simple-restore-db-mpp.sh
```

### Step 3: Monitor Progress
```bash
# In another terminal, monitor progress
./monitor-restore.sh
```

### Step 4: Verify Completion
```bash
# Check table count
mysql -h 192.168.11.122 -P 6033 -u root -p'2fF2P7xqVtc4iCExR' \
  -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='db-mpp';"

# Check database size
mysql -h 192.168.11.122 -P 6033 -u root -p'2fF2P7xqVtc4iCExR' \
  -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb 
      FROM information_schema.tables WHERE table_schema = 'db-mpp';"
```

## ProxySQL Query Routing

### Current Hostgroup Configuration
- **Hostgroup 10**: mysql-primary (Write operations)
- **Hostgroup 20**: mysql-replica (Read operations)

### Query Routing Rules
- **SELECT queries** → Routed to mysql-replica (Read)
- **INSERT/UPDATE/DELETE** → Routed to mysql-primary (Write)
- **DDL statements** → Routed to mysql-primary (Write)

## Connection Examples

### Command Line
```bash
mysql -h 192.168.11.122 -P 6033 -u root -p db-mpp
```

### PHP PDO
```php
$pdo = new PDO(
    'mysql:host=192.168.11.122;port=6033;dbname=db-mpp;charset=utf8mb4',
    'root',
    '2fF2P7xqVtc4iCExR',
    [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false
    ]
);
```

### Laravel .env
```env
DB_CONNECTION=mysql
DB_HOST=192.168.11.122
DB_PORT=6033
DB_DATABASE=db-mpp
DB_USERNAME=root
DB_PASSWORD=2fF2P7xqVtc4iCExR
```

### Python PyMySQL
```python
import pymysql
connection = pymysql.connect(
    host='192.168.11.122',
    port=6033,
    user='root',
    password='2fF2P7xqVtc4iCExR',
    database='db-mpp',
    charset='utf8mb4'
)
```

### Node.js MySQL2
```javascript
const mysql = require('mysql2/promise');
const connection = await mysql.createConnection({
    host: '192.168.11.122',
    port: 6033,
    user: 'root',
    password: '2fF2P7xqVtc4iCExR',
    database: 'db-mpp'
});
```

## Performance Optimization

### Large File Restore Settings
The restore script uses optimized MySQL settings:
- `SET FOREIGN_KEY_CHECKS=0;` - Disable FK checks during restore
- `SET UNIQUE_CHECKS=0;` - Disable unique checks during restore  
- `SET AUTOCOMMIT=0;` - Use manual transaction control
- Single transaction for entire restore
- Manual commit at the end

### Expected Performance
- **File Size**: 7.1GB
- **Estimated Time**: 15-45 minutes (depending on hardware)
- **Memory Usage**: Optimized for large datasets
- **Network**: All operations via ProxySQL load balancer

## Troubleshooting

### Common Issues

1. **Connection Timeout**
   - Increase MySQL timeout settings
   - Check network connectivity to 192.168.11.122

2. **Memory Issues**
   - Monitor MySQL container memory usage
   - Consider splitting large tables if needed

3. **ProxySQL Routing Issues**
   - Verify hostgroup configuration
   - Check ProxySQL logs for routing errors

### Monitoring Commands
```bash
# Check ProxySQL status
mysql -h 192.168.11.122 -P 6032 -u superman -p'Soleh1!' \
  -e "SELECT hostgroup_id,hostname,port,status FROM mysql_servers;"

# Check active connections
mysql -h 192.168.11.122 -P 6033 -u root -p'2fF2P7xqVtc4iCExR' \
  -e "SHOW PROCESSLIST;"

# Check container status
docker compose ps
```

## Replication Verification

After restore completion, verify replication is working:

```bash
# Check replication lag
mysql -h 192.168.11.122 -P 6032 -u superman -p'Soleh1!' \
  -e "SELECT * FROM stats_mysql_connection_pool;"

# Verify data consistency between primary and replica
# (This is automatically handled by MySQL replication)
```

## Backup Strategy

### Before Restore
- Original database: `dp_mpp-24072025.sql` (Source)
- Target database: `db-mpp` (New empty database)

### After Restore
- Create regular backups of `db-mpp` database
- Use ProxySQL read queries for backup operations to reduce primary load

### Backup Command
```bash
mysqldump -h 192.168.11.122 -P 6033 -u root -p'2fF2P7xqVtc4iCExR' \
  --single-transaction --routines --triggers --events \
  db-mpp > backup_db-mpp_$(date +%Y%m%d_%H%M%S).sql
```

---

**Generated**: $(date)
**Status**: Restore in progress - Monitor with `./monitor-restore.sh`
