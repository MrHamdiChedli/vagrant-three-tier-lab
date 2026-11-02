#!/usr/bin/env bash
# Nginx shares traffic between the web servers and skips any server that stops answering.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq nginx

cat > /etc/nginx/sites-available/app <<EOF
upstream web {
    server $WEB1_IP:8000 max_fails=1 fail_timeout=10s;
    server $WEB2_IP:8000 max_fails=1 fail_timeout=10s;
}

server {
    listen 80 default_server;

    location / {
        proxy_pass http://web;
        proxy_connect_timeout 2s;
        proxy_next_upstream error timeout http_502 http_503;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t -q
systemctl enable --quiet nginx
systemctl reload-or-restart nginx
