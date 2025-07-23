-- Konfigurasi untuk replica MySQL
-- Script ini akan dijalankan saat container replica pertama kali dibuat

-- Tunggu sebentar agar primary sudah siap
-- Kemudian setup replication
CHANGE MASTER TO
  MASTER_HOST='mysql-primary',
  MASTER_USER='repl',
  MASTER_PASSWORD='replpass',
  MASTER_AUTO_POSITION=1;