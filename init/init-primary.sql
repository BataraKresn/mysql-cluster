CREATE DATABASE IF NOT EXISTS appdb;
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
