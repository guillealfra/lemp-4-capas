#!/bin/bash

echo "--------------------------------------"
echo "---- COMENZANDO APROVISIONAMIENTO ----"
echo "--------------------------------------"

sudo apt update
sudo apt install nfs-kernel-server nginx php-fpm php-mysql git -y

git clone https://github.com/josejuansanchez/iaw-practica-lamp

sudo mkdir -p /var/www/crud

sudo cp -r /home/vagrant/iaw-practica-lamp/src/* /var/www/crud/

sudo cat <<EOF > /var/www/crud/config.php
<?php

define('DB_HOST', '192.168.20.10');
define('DB_NAME', 'users');
define('DB_USER', 'ejemplo_user');
define('DB_PASSWORD', 'oracle');

\$mysqli = mysqli_connect(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

?>
EOF

sudo chown -R www-data:www-data /var/www/crud

sudo cat <<EOF > /etc/nginx/sites-available/phpserver
server {
    listen 80;
    server_name _;
    root /var/www/crud;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
}
EOF

sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/phpserver /etc/nginx/sites-enabled/

sudo cat <<EOF >> /etc/exports
/var/www/crud 192.168.10.11(rw,sync,no_subtree_check)
/var/www/crud 192.168.10.12(rw,sync,no_subtree_check)
EOF

sudo exportfs -ra

sudo systemctl restart nfs-kernel-server
sudo systemctl restart nginx
sudo systemctl restart php8.2-fpm

sudo ip route del default
