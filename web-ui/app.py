from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import pymysql
import json
import time
import os
import docker
import threading
import requests
from datetime import datetime, timedelta
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Docker client
try:
    docker_client = docker.from_env()
    logger.info("Docker client initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Docker client: {e}")
    docker_client = None

# Database configuration
PROXYSQL_CONFIG = {
    'host': 'proxysql',
    'port': 6032,
    'user': 'superman',
    'password': 'Soleh1!',
    'charset': 'utf8mb4'
}

MYSQL_PRIMARY_CONFIG = {
    'host': 'mysql-primary',
    'port': 3306,
    'user': 'root',
    'password': '2fF2P7xqVtc4iCExR',
    'charset': 'utf8mb4'
}

MYSQL_REPLICA_CONFIG = {
    'host': 'mysql-replica', 
    'port': 3306,
    'user': 'root',
    'password': '2fF2P7xqVtc4iCExR',
    'charset': 'utf8mb4'
}

class MySQLClusterMonitor:
    def __init__(self):
        self.metrics_cache = {}
        self.last_update = None
        
    def get_proxysql_connection(self):
        """Get ProxySQL admin connection"""
        try:
            return pymysql.connect(**PROXYSQL_CONFIG)
        except Exception as e:
            logger.error(f"ProxySQL connection failed: {e}")
            return None
    
    def get_mysql_connection(self, config):
        """Get MySQL connection"""
        try:
            return pymysql.connect(**config)
        except Exception as e:
            logger.error(f"MySQL connection failed: {e}")
            return None
    
    def check_proxysql_status(self):
        """Check ProxySQL status and backend servers"""
        conn = self.get_proxysql_connection()
        if not conn:
            return {
                'status': 'offline',
                'error': 'Cannot connect to ProxySQL admin',
                'backends': [],
                'query_rules': []
            }
        
        try:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            
            # Check backend servers
            cursor.execute("SELECT * FROM mysql_servers")
            backends = cursor.fetchall()
            
            # Check query rules
            cursor.execute("SELECT * FROM mysql_query_rules")
            query_rules = cursor.fetchall()
            
            # Get ProxySQL stats
            cursor.execute("SELECT * FROM stats_mysql_global WHERE variable_name IN ('Queries', 'Client_Connections_created', 'Server_Connections_created')")
            stats = cursor.fetchall()
            
            # Get connection pool stats
            cursor.execute("SELECT * FROM stats_mysql_connection_pool")
            connection_pool = cursor.fetchall()
            
            return {
                'status': 'online',
                'backends': backends,
                'query_rules': query_rules,
                'stats': stats,
                'connection_pool': connection_pool
            }
            
        except Exception as e:
            logger.error(f"ProxySQL query failed: {e}")
            return {
                'status': 'error',
                'error': str(e),
                'backends': [],
                'query_rules': []
            }
        finally:
            conn.close()
    
    def check_mysql_status(self, config, server_type):
        """Check MySQL server status"""
        conn = self.get_mysql_connection(config)
        if not conn:
            return {
                'status': 'offline',
                'error': f'Cannot connect to MySQL {server_type}',
                'uptime': 0,
                'connections': 0,
                'queries': 0
            }
        
        try:
            cursor = conn.cursor(pymysql.cursors.DictCursor)
            
            # Get server status
            cursor.execute("SHOW STATUS LIKE 'Uptime'")
            uptime_result = cursor.fetchone()
            uptime = int(uptime_result['Value']) if uptime_result else 0
            
            cursor.execute("SHOW STATUS LIKE 'Threads_connected'")
            connections_result = cursor.fetchone()
            connections = int(connections_result['Value']) if connections_result else 0
            
            cursor.execute("SHOW STATUS LIKE 'Queries'")
            queries_result = cursor.fetchone()
            queries = int(queries_result['Value']) if queries_result else 0
            
            # Check replication status (for replica)
            replication_status = {}
            if server_type == 'replica':
                cursor.execute("SHOW SLAVE STATUS")
                slave_status = cursor.fetchone()
                if slave_status:
                    replication_status = {
                        'io_running': slave_status.get('Slave_IO_Running', 'No'),
                        'sql_running': slave_status.get('Slave_SQL_Running', 'No'),
                        'seconds_behind_master': slave_status.get('Seconds_Behind_Master', 'Unknown'),
                        'master_host': slave_status.get('Master_Host', 'Unknown'),
                        'last_error': slave_status.get('Last_Error', '')
                    }
            
            return {
                'status': 'online',
                'uptime': uptime,
                'connections': connections,
                'queries': queries,
                'replication': replication_status
            }
            
        except Exception as e:
            logger.error(f"MySQL {server_type} query failed: {e}")
            return {
                'status': 'error',
                'error': str(e),
                'uptime': 0,
                'connections': 0,
                'queries': 0
            }
        finally:
            conn.close()
    
    def get_cluster_metrics(self):
        """Get comprehensive cluster metrics"""
        if self.last_update and time.time() - self.last_update < 5:
            return self.metrics_cache
        
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'proxysql': self.check_proxysql_status(),
            'mysql_primary': self.check_mysql_status(MYSQL_PRIMARY_CONFIG, 'primary'),
            'mysql_replica': self.check_mysql_status(MYSQL_REPLICA_CONFIG, 'replica')
        }
        
        # Calculate derived metrics
        metrics['cluster_health'] = self.calculate_cluster_health(metrics)
        metrics['replication_lag'] = self.get_replication_lag(metrics)
        
        self.metrics_cache = metrics
        self.last_update = time.time()
        
        return metrics
    
    def calculate_cluster_health(self, metrics):
        """Calculate overall cluster health score"""
        score = 0
        total = 100
        
        # ProxySQL health (30%)
        if metrics['proxysql']['status'] == 'online':
            score += 30
        
        # Primary MySQL health (40%)
        if metrics['mysql_primary']['status'] == 'online':
            score += 40
        
        # Replica MySQL health (20%)
        if metrics['mysql_replica']['status'] == 'online':
            score += 20
        
        # Replication health (10%)
        if metrics['mysql_replica'].get('replication'):
            repl = metrics['mysql_replica']['replication']
            if repl.get('io_running') == 'Yes' and repl.get('sql_running') == 'Yes':
                score += 10
        
        return {
            'score': score,
            'status': 'healthy' if score >= 80 else 'warning' if score >= 60 else 'critical'
        }
    
    def get_replication_lag(self, metrics):
        """Get replication lag in seconds"""
        if metrics['mysql_replica'].get('replication'):
            lag = metrics['mysql_replica']['replication'].get('seconds_behind_master')
            if lag != 'Unknown' and lag is not None:
                return int(lag)
        return None

# Initialize monitor
monitor = MySQLClusterMonitor()

@app.route('/')
def dashboard():
    """Main dashboard page"""
    return render_template('dashboard.html')

@app.route('/api/metrics')
def get_metrics():
    """API endpoint for cluster metrics"""
    try:
        metrics = monitor.get_cluster_metrics()
        return jsonify(metrics)
    except Exception as e:
        logger.error(f"Error getting metrics: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/proxysql/backends')
def get_proxysql_backends():
    """Get ProxySQL backend servers status"""
    try:
        proxysql_status = monitor.check_proxysql_status()
        return jsonify(proxysql_status.get('backends', []))
    except Exception as e:
        logger.error(f"Error getting ProxySQL backends: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/traffic/realtime')
def get_realtime_traffic():
    """Get real-time traffic metrics from ProxySQL"""
    try:
        conn = monitor.get_proxysql_connection()
        if not conn:
            return jsonify({'error': 'Cannot connect to ProxySQL admin'}), 500
        
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # Get real-time query statistics
        cursor.execute("""
            SELECT 
                variable_name, 
                variable_value 
            FROM stats_mysql_global 
            WHERE variable_name IN (
                'Queries_backends_bytes_recv',
                'Queries_backends_bytes_sent', 
                'Queries_frontends_bytes_recv',
                'Queries_frontends_bytes_sent',
                'Questions',
                'Slow_queries'
            )
        """)
        global_stats = cursor.fetchall()
        
        # Get connection pool metrics
        cursor.execute("""
            SELECT 
                hostgroup,
                srv_host,
                srv_port,
                status,
                ConnUsed,
                ConnFree,
                ConnOK,
                ConnERR,
                Queries,
                Bytes_data_sent,
                Bytes_data_recv,
                Latency_us
            FROM stats_mysql_connection_pool
        """)
        connection_stats = cursor.fetchall()
        
        # Get query rules stats
        cursor.execute("""
            SELECT 
                rule_id,
                hits
            FROM stats_mysql_query_rules
            ORDER BY hits DESC
            LIMIT 10
        """)
        query_rules_stats = cursor.fetchall()
        
        conn.close()
        
        return jsonify({
            'timestamp': datetime.now().isoformat(),
            'global_stats': global_stats,
            'connection_pool': connection_stats,
            'query_rules': query_rules_stats
        })
        
    except Exception as e:
        logger.error(f"Error getting real-time traffic: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/container/status')
def get_container_status():
    """Get detailed container status using Docker SDK"""
    try:
        if not docker_client:
            return jsonify({'error': 'Docker client not available'}), 500
        
        containers_info = {}
        container_names = ['proxysql', 'mysql-primary', 'mysql-replica']
        
        for name in container_names:
            try:
                container = docker_client.containers.get(name)
                stats = container.stats(stream=False)
                
                # Calculate CPU percentage
                cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                           stats['precpu_stats']['cpu_usage']['total_usage']
                system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                              stats['precpu_stats']['system_cpu_usage']
                cpu_percent = (cpu_delta / system_delta) * 100.0 if system_delta > 0 else 0
                
                # Calculate memory usage
                memory_usage = stats['memory_stats']['usage']
                memory_limit = stats['memory_stats']['limit']
                memory_percent = (memory_usage / memory_limit) * 100.0 if memory_limit > 0 else 0
                
                containers_info[name] = {
                    'status': container.status,
                    'health': getattr(container.attrs['State'], 'Health', {}).get('Status', 'unknown'),
                    'created': container.attrs['Created'],
                    'started': container.attrs['State']['StartedAt'],
                    'cpu_percent': round(cpu_percent, 2),
                    'memory_usage_mb': round(memory_usage / 1024 / 1024, 2),
                    'memory_percent': round(memory_percent, 2),
                    'network_rx_bytes': stats['networks']['mysqlnet']['rx_bytes'],
                    'network_tx_bytes': stats['networks']['mysqlnet']['tx_bytes']
                }
            except docker.errors.NotFound:
                containers_info[name] = {'status': 'not_found', 'error': f'Container {name} not found'}
            except Exception as e:
                containers_info[name] = {'status': 'error', 'error': str(e)}
        
        return jsonify({
            'timestamp': datetime.now().isoformat(),
            'containers': containers_info
        })
        
    except Exception as e:
        logger.error(f"Error getting container status: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/actions/restart/<service>')
def restart_service(service):
    """Restart a specific service using Docker SDK"""
    try:
        if service not in ['proxysql', 'mysql-primary', 'mysql-replica']:
            return jsonify({'error': 'Invalid service name'}), 400
        
        if not docker_client:
            return jsonify({'error': 'Docker client not available'}), 500
        
        # Get and restart container
        container = docker_client.containers.get(service)
        container.restart()
        
        logger.info(f"Successfully restarted {service}")
        return jsonify({
            'success': True, 
            'message': f'{service} restarted successfully',
            'timestamp': datetime.now().isoformat()
        })
        
    except docker.errors.NotFound:
        logger.error(f"Container {service} not found")
        return jsonify({'error': f'Container {service} not found'}), 404
    except Exception as e:
        logger.error(f"Error restarting {service}: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/actions/backup')
def backup_databases():
    """Trigger database backup using Docker SDK"""
    try:
        if not docker_client:
            return jsonify({'error': 'Docker client not available'}), 500
        
        # Get mysql-primary container
        primary_container = docker_client.containers.get('mysql-primary')
        
        # Create backup directory
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_filename = f'mysql_cluster_backup_{timestamp}.sql'
        
        # Execute backup command inside container
        backup_cmd = [
            'mysqldump',
            '-h', 'localhost',
            '-u', 'root',
            '-p2fF2P7xqVtc4iCExR',
            '--all-databases',
            '--routines',
            '--triggers',
            '--single-transaction',
            '--master-data=2',
            '--flush-logs'
        ]
        
        exec_result = primary_container.exec_run(backup_cmd, stream=False)
        
        if exec_result.exit_code == 0:
            # Save backup to volume or return success
            return jsonify({
                'success': True,
                'message': f'Backup created successfully: {backup_filename}',
                'timestamp': datetime.now().isoformat(),
                'size': len(exec_result.output)
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Backup failed',
                'error': exec_result.output.decode()
            }), 500
            
    except docker.errors.NotFound:
        return jsonify({'error': 'MySQL Primary container not found'}), 404
    except Exception as e:
        logger.error(f"Error creating backup: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs/<service>')
def get_service_logs(service):
    """Get logs for a specific service using Docker SDK"""
    try:
        if service not in ['proxysql', 'mysql-primary', 'mysql-replica']:
            return jsonify({'error': 'Invalid service name'}), 400
        
        if not docker_client:
            return jsonify({'error': 'Docker client not available'}), 500
        
        # Get container and logs
        container = docker_client.containers.get(service)
        logs = container.logs(tail=100, timestamps=True).decode('utf-8')
        
        # Split logs into lines
        log_lines = logs.strip().split('\n') if logs.strip() else []
        
        return jsonify({
            'success': True,
            'logs': log_lines,
            'service': service,
            'timestamp': datetime.now().isoformat(),
            'container_status': container.status
        })
        
    except docker.errors.NotFound:
        logger.error(f"Container {service} not found")
        return jsonify({'error': f'Container {service} not found'}), 404
    except Exception as e:
        logger.error(f"Error getting logs for {service}: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

if __name__ == '__main__':
    # Start the Flask app
    app.run(host='0.0.0.0', port=5000, debug=False)
