#!/bin/bash

echo "--------------------------------------"
echo "---- COMENZANDO APROVISIONAMIENTO ----"
echo "--------------------------------------"

sudo apt update
sudo apt install nginx -y

sudo cat <<EOF > /etc/nginx/sites-available/webapp
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://192.168.10.10;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/webapp /etc/nginx/sites-enabled/

sudo systemctl restart nginx

sudo ip route del default
