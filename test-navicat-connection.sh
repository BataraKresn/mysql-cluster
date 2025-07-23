#!/bin/bash
# Test script untuk debugging koneksi dari server Navicat
# Jalankan dari server dimana Navicat diinstall

echo "Testing MySQL Cluster Connection from Navicat Server..."
echo "=============================================="

# Test basic connectivity
echo "1. Testing basic connectivity..."
telnet 192.168.11.122 6033 <<EOF
quit
EOF

echo "2. Testing MySQL connection..."
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "SELECT 'Connection from Navicat Server OK' as status;"

echo "3. Testing database access..."
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "SHOW DATABASES;"

echo "4. Testing specific database..."
mysql -h192.168.11.122 -P6033 -uappuser -pAppPass123! -e "USE appdb; SHOW TABLES;"

echo "Test completed!"
