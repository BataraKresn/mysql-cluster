<?php
/**
 * Laravel Database Configuration untuk MySQL Cluster dengan ProxySQL
 * File: config/database.php
 */

return [
    'default' => env('DB_CONNECTION', 'mysql'),

    'connections' => [
        // Single connection via ProxySQL (Recommended)
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
            ]) : [],
        ],

        // Alternative: Separate Read/Write connections (Manual routing)
        'mysql_write' => [
            'driver' => 'mysql',
            'host' => env('DB_WRITE_HOST', '192.168.11.122'),
            'port' => env('DB_WRITE_PORT', '6033'),  // ProxySQL akan route ke Primary
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
            'port' => env('DB_READ_PORT', '6033'),  // ProxySQL akan route ke Replica untuk SELECT
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
    ],
];
