#!/bin/bash

echo "--------------------------------------"
echo "---- COMENZANDO APROVISIONAMIENTO ----"
echo "--------------------------------------"

sudo apt update
sudo apt install mariadb-server git -y

git clone https://github.com/josejuansanchez/iaw-practica-lamp

sudo systemctl stop mariadb

sudo cat <<EOF > /etc/mysql/mariadb.conf.d/60-galera.cnf
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "ClusterGuille"
wsrep_cluster_address    = gcomm://192.168.20.20,192.168.20.30
binlog_format            = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
wsrep_node_address       = 192.168.20.20
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
bind-address = 0.0.0.0
EOF

sudo galera_new_cluster
sleep 10

sudo mysql -e "
DROP DATABASE IF EXISTS users;
CREATE DATABASE users CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'ejemplo_user'@'192.168.20.%' IDENTIFIED BY 'oracle';
GRANT ALL PRIVILEGES ON users.* TO 'ejemplo_user'@'192.168.20.%';
CREATE USER IF NOT EXISTS 'haproxy'@'192.168.20.%';
FLUSH PRIVILEGES;
USE users;
SOURCE /home/vagrant/iaw-practica-lamp/db/database.sql;
"

echo "-------------------------------------------"
sudo mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
echo "-------------------------------------------"

sudo ip route del default
