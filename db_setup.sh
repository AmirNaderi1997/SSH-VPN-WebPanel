#!/usr/bin/env bash

# Install MariaDB (Debian/Ubuntu) and set up the vpn_manager database
set -e

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Update package list and install MariaDB server
apt-get update -y
apt-get install -y mariadb-server

# Secure installation (set root password to empty for local use)
# You may want to run `mysql_secure_installation` manually afterwards

# Create database and user
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS vpn_manager CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON vpn_manager.* TO 'vpn_admin'@'localhost' IDENTIFIED BY 'vpnadmin123';
FLUSH PRIVILEGES;
SQL

# Import schema
mysql -u vpn_admin -pvpnadmin123 vpn_manager < "$(dirname "$0")/db_init.sql"

echo "Database vpn_manager created and schema imported."
