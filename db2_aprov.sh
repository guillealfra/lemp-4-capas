#!/bin/bash

echo "--------------------------------------"
echo "---- COMENZANDO APROVISIONAMIENTO ----"
echo "--------------------------------------"

sudo apt update
sudo apt install mariadb-server -y

sudo systemctl stop mariadb

sudo cat <<EOF > /etc/mysql/mariadb.conf.d/60-galera.cnf
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "ClusterGuille"
wsrep_cluster_address    = gcomm://192.168.20.20,192.168.20.30
binlog_format            = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
wsrep_node_address       = 192.168.20.30
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
bind-address = 0.0.0.0
EOF

sudo systemctl start mariadb
sleep 10

echo "-------------------------------------------"
sudo mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
echo "-------------------------------------------"

sudo ip route del default
