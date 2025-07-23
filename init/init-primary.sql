-- Create databases if they don't exist
CREATE DATABASE IF NOT EXISTS appdb;
CREATE DATABASE IF NOT EXISTS `db-mpp`;

-- User untuk replikasi (buat hanya jika belum ada)
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- User untuk akses eksternal/aplikasi (buat hanya jika belum ada)
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED WITH mysql_native_password BY 'AppPass123!';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
GRANT ALL PRIVILEGES ON `db-mpp`.* TO 'appuser'@'%';

-- User untuk ProxySQL monitoring (buat hanya jika belum ada)
CREATE USER IF NOT EXISTS 'proxysql'@'%' IDENTIFIED WITH mysql_native_password BY 'ProxySQL123!';
GRANT USAGE ON *.* TO 'proxysql'@'%';

-- Update root user untuk bisa akses dari luar (hanya jika record ada)
UPDATE mysql.user SET Host='%' WHERE User='root' AND Host='localhost';
-- Jika tidak ada, buat user root dengan akses dari mana saja
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'RootPass123!';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;IF NOT EXISTS appdb;
CREATE DATABASE IF NOT EXISTS `db-mpp`;

-- User untuk replikasi
CREATE USER 'repl'@'%' IDENTIFIED WITH mysql_native_password BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';

-- User untuk akses eksternal (aplikasi)
CREATE USER 'appuser'@'%' IDENTIFIED WITH mysql_native_password BY 'AppPass123!';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
GRANT ALL PRIVILEGES ON `db-mpp`.* TO 'appuser'@'%';

-- Pastikan root bisa akses dari luar
UPDATE mysql.user SET Host='%' WHERE User='root' AND Host='localhost';

FLUSH PRIVILEGES;
