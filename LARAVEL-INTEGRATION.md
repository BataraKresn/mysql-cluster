# 🚀 Laravel Integration dengan MySQL Cluster

Panduan lengkap integrasi Laravel Framework dengan MySQL Cluster ProxySQL untuk High Availability dan Load Balancing.

## 🏗️ **Arsitektur Laravel + MySQL Cluster**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Laravel App   │    │  Laravel Queue  │    │ Laravel Horizon │
│   (Web Server)  │    │   (Background)  │    │  (Monitoring)   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │      ProxySQL             │
                    │   (192.168.11.122:6033)  │
                    │   ┌─────────────────────┐ │
                    │   │ Automatic Routing   │ │
                    │   │ SELECT → Replica    │ │
                    │   │ WRITE  → Primary    │ │
                    │   └─────────────────────┘ │
                    └─────────────┬─────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼───────┐      ┌────────▼────────┐      
│ MySQL Primary │      │ MySQL Replica   │      
│ (WRITE)       │◄────►│ (READ)          │      
│ appdb         │      │ appdb           │      
│ db-mpp        │      │ db-mpp          │      
└───────────────┘      └─────────────────┘      
```

## ⚙️ **Laravel Configuration**

### **1. Database Configuration (config/database.php)**

```php
<?php

return [
    'default' => env('DB_CONNECTION', 'mysql'),

    'connections' => [
        // ✅ RECOMMENDED: Single Connection via ProxySQL
        'mysql' => [
            'driver' => 'mysql',
            'host' => env('DB_HOST', '192.168.11.122'),
            'port' => env('DB_PORT', '6033'),  // ProxySQL port
            'database' => env('DB_DATABASE', 'appdb'),
            'username' => env('DB_USERNAME', 'appuser'),
            'password' => env('DB_PASSWORD', 'AppPass123!'),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
            'options' => extension_loaded('pdo_mysql') ? array_filter([
                PDO::MYSQL_ATTR_SSL_CA => env('MYSQL_ATTR_SSL_CA'),
                PDO::MYSQL_ATTR_INIT_COMMAND => 'SET sql_mode="STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION"',
                PDO::ATTR_TIMEOUT => 30,
                PDO::ATTR_PERSISTENT => false,
            ]) : [],
        ],

        // 🔧 ADVANCED: Manual Read/Write Split (Optional)
        'mysql_write' => [
            'driver' => 'mysql',
            'host' => env('DB_WRITE_HOST', '192.168.11.122'),
            'port' => env('DB_WRITE_PORT', '6033'),
            'database' => env('DB_DATABASE', 'appdb'),
            'username' => env('DB_USERNAME', 'appuser'),
            'password' => env('DB_PASSWORD', 'AppPass123!'),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
        ],

        'mysql_read' => [
            'driver' => 'mysql',
            'host' => env('DB_READ_HOST', '192.168.11.122'),
            'port' => env('DB_READ_PORT', '6033'),
            'database' => env('DB_DATABASE', 'appdb'),
            'username' => env('DB_USERNAME', 'appuser'),
            'password' => env('DB_PASSWORD', 'AppPass123!'),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
        ],

        // 📊 Database MPP untuk Analytics
        'mysql_mpp' => [
            'driver' => 'mysql',
            'host' => env('DB_MPP_HOST', '192.168.11.122'),
            'port' => env('DB_MPP_PORT', '6033'),
            'database' => env('DB_MPP_DATABASE', 'db-mpp'),
            'username' => env('DB_MPP_USERNAME', 'appuser'),
            'password' => env('DB_MPP_PASSWORD', 'AppPass123!'),
            'unix_socket' => env('DB_SOCKET', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_unicode_ci',
            'prefix' => '',
            'prefix_indexes' => true,
            'strict' => true,
            'engine' => null,
        ],
    ],

    // Redis untuk cache dan sessions
    'redis' => [
        'client' => env('REDIS_CLIENT', 'phpredis'),
        'options' => [
            'cluster' => env('REDIS_CLUSTER', 'redis'),
            'prefix' => env('REDIS_PREFIX', Str::slug(env('APP_NAME', 'laravel'), '_').'_database_'),
        ],
        'default' => [
            'url' => env('REDIS_URL'),
            'host' => env('REDIS_HOST', '127.0.0.1'),
            'password' => env('REDIS_PASSWORD', null),
            'port' => env('REDIS_PORT', '6379'),
            'database' => env('REDIS_DB', '0'),
        ],
    ],
];
```

### **2. Environment Configuration (.env)**

```env
# Application
APP_NAME="MyApp"
APP_ENV=production
APP_KEY=base64:your-app-key-here
APP_DEBUG=false
APP_URL=https://yourapp.com

# ✅ MySQL Cluster Configuration (Main Database)
DB_CONNECTION=mysql
DB_HOST=192.168.11.122
DB_PORT=6033
DB_DATABASE=appdb
DB_USERNAME=appuser
DB_PASSWORD=AppPass123!

# 📊 MPP Database Configuration (Analytics)
DB_MPP_HOST=192.168.11.122
DB_MPP_PORT=6033
DB_MPP_DATABASE=db-mpp
DB_MPP_USERNAME=appuser
DB_MPP_PASSWORD=AppPass123!

# 🔧 Advanced Read/Write Split (Optional)
DB_WRITE_HOST=192.168.11.122
DB_WRITE_PORT=6033
DB_READ_HOST=192.168.11.122
DB_READ_PORT=6033

# Cache & Sessions
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# Redis Configuration
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-host
MAIL_PORT=587
MAIL_USERNAME=your-username
MAIL_PASSWORD=your-password
MAIL_ENCRYPTION=tls

# Logging
LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

# Broadcasting
BROADCAST_DRIVER=pusher
PUSHER_APP_ID=your-pusher-app-id
PUSHER_APP_KEY=your-pusher-key
PUSHER_APP_SECRET=your-pusher-secret
PUSHER_APP_CLUSTER=mt1
```

## 🔧 **Laravel Service Implementations**

### **1. Database Service Provider**

```php
<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\DB;

class DatabaseServiceProvider extends ServiceProvider
{
    public function register()
    {
        // Register MPP database connection
        $this->app->singleton('mpp.database', function ($app) {
            return DB::connection('mysql_mpp');
        });
    }

    public function boot()
    {
        // Database connection debugging (development only)
        if (app()->environment('local')) {
            DB::listen(function ($query) {
                logger()->info('DB Query', [
                    'sql' => $query->sql,
                    'bindings' => $query->bindings,
                    'time' => $query->time,
                    'connection' => $query->connectionName,
                ]);
            });
        }

        // Connection health checks
        $this->healthChecks();
    }

    private function healthChecks()
    {
        try {
            // Test main database
            DB::connection('mysql')->select('SELECT 1');
            
            // Test MPP database
            DB::connection('mysql_mpp')->select('SELECT 1');
            
        } catch (\Exception $e) {
            logger()->error('Database connection failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString()
            ]);
        }
    }
}
```

### **2. Repository Pattern untuk Multiple Databases**

```php
<?php

namespace App\Repositories;

use Illuminate\Support\Facades\DB;

class BaseRepository
{
    protected $connection = 'mysql';
    protected $table;

    public function __construct()
    {
        $this->db = DB::connection($this->connection);
    }

    public function find($id)
    {
        return $this->db->table($this->table)->find($id);
    }

    public function create(array $data)
    {
        return $this->db->table($this->table)->insert($data);
    }

    public function update($id, array $data)
    {
        return $this->db->table($this->table)->where('id', $id)->update($data);
    }

    public function delete($id)
    {
        return $this->db->table($this->table)->where('id', $id)->delete();
    }
}

// User Repository (Main Database)
class UserRepository extends BaseRepository
{
    protected $connection = 'mysql';
    protected $table = 'users';
}

// Analytics Repository (MPP Database)
class AnalyticsRepository extends BaseRepository
{
    protected $connection = 'mysql_mpp';
    protected $table = 'analytics_data';

    public function getDailyStats($date)
    {
        return $this->db->table($this->table)
            ->where('date', $date)
            ->groupBy('metric_type')
            ->selectRaw('metric_type, SUM(value) as total')
            ->get();
    }
}
```

### **3. Manual Read/Write Split Service**

```php
<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class DatabaseRoutingService
{
    /**
     * Force query to write database (Primary)
     */
    public static function write(callable $callback)
    {
        return DB::connection('mysql_write')->transaction($callback);
    }

    /**
     * Force query to read database (Replica)
     */
    public static function read(callable $callback)
    {
        return DB::connection('mysql_read')->transaction($callback);
    }

    /**
     * Heavy analytics queries to MPP database
     */
    public static function analytics(callable $callback)
    {
        return DB::connection('mysql_mpp')->transaction($callback);
    }
}

// Usage examples:
// DatabaseRoutingService::write(function () {
//     return User::create(['name' => 'John', 'email' => 'john@example.com']);
// });

// DatabaseRoutingService::read(function () {
//     return User::where('active', true)->paginate(20);
// });

// DatabaseRoutingService::analytics(function () {
//     return DB::table('user_activities')
//         ->selectRaw('DATE(created_at) as date, COUNT(*) as activity_count')
//         ->groupBy('date')
//         ->orderBy('date', 'desc')
//         ->limit(30)
//         ->get();
// });
```

## 🚀 **Laravel Artisan Commands**

### **1. Database Health Check Command**

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class DatabaseHealthCheck extends Command
{
    protected $signature = 'db:health-check';
    protected $description = 'Check MySQL Cluster health via ProxySQL';

    public function handle()
    {
        $this->info('🔍 Checking MySQL Cluster Health...');

        $connections = ['mysql', 'mysql_mpp'];
        $healthy = true;

        foreach ($connections as $connection) {
            try {
                $start = microtime(true);
                $result = DB::connection($connection)->select('SELECT 1 as health_check');
                $time = round((microtime(true) - $start) * 1000, 2);

                if ($result && $result[0]->health_check == 1) {
                    $this->info("✅ {$connection}: OK ({$time}ms)");
                } else {
                    $this->error("❌ {$connection}: FAILED");
                    $healthy = false;
                }
            } catch (\Exception $e) {
                $this->error("❌ {$connection}: ERROR - " . $e->getMessage());
                $healthy = false;
            }
        }

        if ($healthy) {
            $this->info('🎉 All database connections are healthy!');
            return 0;
        } else {
            $this->error('⚠️  Some database connections have issues!');
            return 1;
        }
    }
}
```

### **2. ProxySQL Stats Command**

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class ProxySQLStats extends Command
{
    protected $signature = 'proxysql:stats';
    protected $description = 'Show ProxySQL statistics';

    public function handle()
    {
        try {
            // Connect to ProxySQL admin
            $config = [
                'driver' => 'mysql',
                'host' => '192.168.11.122',
                'port' => 6032,
                'username' => 'superman',
                'password' => 'Soleh1!',
                'database' => '',
            ];

            config(['database.connections.proxysql_admin' => $config]);

            $this->info('📊 ProxySQL Connection Pool Stats:');
            $stats = DB::connection('proxysql_admin')
                ->select('SELECT srv_host, srv_port, status, ConnUsed, ConnFree, ConnOK, ConnERR FROM stats_mysql_connection_pool');

            $this->table(['Host', 'Port', 'Status', 'Used', 'Free', 'OK', 'Errors'], 
                collect($stats)->map(function ($stat) {
                    return [
                        $stat->srv_host,
                        $stat->srv_port,
                        $stat->status,
                        $stat->ConnUsed,
                        $stat->ConnFree,
                        $stat->ConnOK,
                        $stat->ConnERR,
                    ];
                })->toArray()
            );

        } catch (\Exception $e) {
            $this->error('❌ Failed to connect to ProxySQL admin: ' . $e->getMessage());
        }
    }
}
```

## 📊 **Performance Monitoring**

### **1. Database Query Monitoring Middleware**

```php
<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class DatabaseQueryMonitoring
{
    public function handle($request, Closure $next)
    {
        if (app()->environment('production')) {
            $startTime = microtime(true);
            $queries = [];

            DB::listen(function ($query) use (&$queries) {
                $queries[] = [
                    'sql' => $query->sql,
                    'time' => $query->time,
                    'connection' => $query->connectionName,
                ];
            });

            $response = $next($request);

            $totalTime = round((microtime(true) - $startTime) * 1000, 2);
            $queryCount = count($queries);
            $totalQueryTime = array_sum(array_column($queries, 'time'));

            // Log slow requests
            if ($totalTime > 1000 || $queryCount > 50) {
                Log::warning('Slow Request Detected', [
                    'url' => $request->fullUrl(),
                    'method' => $request->method(),
                    'total_time' => $totalTime,
                    'query_count' => $queryCount,
                    'query_time' => $totalQueryTime,
                    'user_id' => auth()->id(),
                ]);
            }

            return $response;
        }

        return $next($request);
    }
}
```

### **2. Health Check Route**

```php
<?php

// routes/api.php
Route::get('/health/database', function () {
    try {
        $checks = [];
        
        // Test main database
        $start = microtime(true);
        DB::connection('mysql')->select('SELECT 1');
        $checks['mysql'] = [
            'status' => 'ok',
            'response_time' => round((microtime(true) - $start) * 1000, 2)
        ];

        // Test MPP database
        $start = microtime(true);
        DB::connection('mysql_mpp')->select('SELECT 1');
        $checks['mysql_mpp'] = [
            'status' => 'ok',
            'response_time' => round((microtime(true) - $start) * 1000, 2)
        ];

        return response()->json([
            'status' => 'healthy',
            'checks' => $checks,
            'timestamp' => now()->toISOString(),
        ]);

    } catch (\Exception $e) {
        return response()->json([
            'status' => 'unhealthy',
            'error' => $e->getMessage(),
            'timestamp' => now()->toISOString(),
        ], 500);
    }
});
```

## 🔧 **Deployment & Migration**

### **1. Migration for Multiple Databases**

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateUsersTable extends Migration
{
    public function up()
    {
        // Main database
        Schema::connection('mysql')->create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->rememberToken();
            $table->timestamps();
        });

        // MPP database - Analytics table
        Schema::connection('mysql_mpp')->create('user_analytics', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('user_id');
            $table->string('event_type');
            $table->json('event_data')->nullable();
            $table->timestamp('created_at');
            
            $table->index(['user_id', 'event_type']);
            $table->index('created_at');
        });
    }

    public function down()
    {
        Schema::connection('mysql')->dropIfExists('users');
        Schema::connection('mysql_mpp')->dropIfExists('user_analytics');
    }
}
```

### **2. Deployment Script**

```bash
#!/bin/bash
# Laravel deployment script untuk MySQL Cluster

echo "🚀 Deploying Laravel with MySQL Cluster..."

# Environment setup
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Database operations
echo "📊 Running database migrations..."
php artisan migrate --force

# Check database health
echo "🔍 Checking database health..."
php artisan db:health-check

if [ $? -eq 0 ]; then
    echo "✅ Database health check passed!"
else
    echo "❌ Database health check failed!"
    exit 1
fi

# Clear caches
php artisan config:clear
php artisan cache:clear

# Queue workers (if using)
php artisan queue:restart

echo "🎉 Laravel deployment completed successfully!"
```

## 📈 **Best Practices**

### **1. Connection Pooling**
```php
// config/database.php - Optimize connection pooling
'options' => [
    PDO::ATTR_PERSISTENT => false, // Disable persistent connections
    PDO::ATTR_TIMEOUT => 30,
    PDO::MYSQL_ATTR_USE_BUFFERED_QUERY => true,
]
```

### **2. Query Optimization**
```php
// Use Eloquent efficiently
User::with('posts')->where('active', true)->paginate(20);

// Raw queries for complex operations
DB::raw('SELECT ... FROM ... WHERE ...');

// Use transactions for write operations
DB::transaction(function () {
    // Multiple database operations
});
```

### **3. Error Handling**
```php
try {
    DB::connection('mysql')->transaction(function () {
        // Database operations
    });
} catch (\Illuminate\Database\QueryException $e) {
    // Handle database errors
    Log::error('Database error: ' . $e->getMessage());
    
    // Failover logic if needed
    return redirect()->back()->with('error', 'Database temporarily unavailable');
}
```

---

**Laravel integration dengan MySQL Cluster selesai! Aplikasi siap untuk production dengan High Availability.** 🚀
