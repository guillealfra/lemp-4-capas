#!/bin/bash

echo "--------------------------------------"
echo "---- COMENZANDO APROVISIONAMIENTO ----"
echo "--------------------------------------"

sudo apt update
sudo apt install nginx -y

sudo cat <<EOF > /etc/nginx/sites-available/balanceador
upstream backend_servers {
    server 192.168.10.11;
    server 192.168.10.12;
}

server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/balanceador /etc/nginx/sites-enabled/

sudo systemctl restart nginx
