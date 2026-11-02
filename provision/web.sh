#!/usr/bin/env bash
# Runs the Flask app under Gunicorn as a systemd service, reachable only from the load balancer.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq python3-venv

id app > /dev/null 2>&1 || useradd --system --create-home --shell /usr/sbin/nologin app

mkdir -p /opt/app
cp /vagrant/app/app.py /vagrant/app/requirements.txt /opt/app/
python3 -m venv /opt/app/venv
/opt/app/venv/bin/pip install --quiet --disable-pip-version-check -r /opt/app/requirements.txt

install -m 640 -o root -g app /dev/null /etc/app.env
cat > /etc/app.env <<EOF
DB_HOST=$DB_IP
DB_PASSWORD=$DB_PASSWORD
EOF

cat > /etc/systemd/system/app.service <<'EOF'
[Unit]
Description=Visit counter (Flask + Gunicorn)
After=network-online.target
Wants=network-online.target

[Service]
User=app
EnvironmentFile=/etc/app.env
WorkingDirectory=/opt/app
ExecStart=/opt/app/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:8000 app:app
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --quiet app
systemctl restart app

ufw allow 22/tcp > /dev/null
ufw allow from "$LB_IP" to any port 8000 proto tcp > /dev/null
ufw --force enable > /dev/null
