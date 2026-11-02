#!/usr/bin/env bash
# Installs PostgreSQL and only lets the two web servers reach it.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq postgresql

CONF_DIR="/etc/postgresql/$(ls /etc/postgresql)/main"
sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "$CONF_DIR/postgresql.conf"

for ip in "$WEB1_IP" "$WEB2_IP"; do
  rule="host appdb app $ip/32 scram-sha-256"
  grep -qxF "$rule" "$CONF_DIR/pg_hba.conf" || echo "$rule" >> "$CONF_DIR/pg_hba.conf"
done
systemctl restart postgresql

# Each command checks first, so running this script twice changes nothing.
as_postgres() { sudo -u postgres psql -v ON_ERROR_STOP=1 -tA "$@"; }
[ "$(as_postgres -c "SELECT 1 FROM pg_roles WHERE rolname='app'")" = "1" ] \
  || as_postgres -c "CREATE ROLE app LOGIN"
as_postgres -c "ALTER ROLE app PASSWORD '$DB_PASSWORD'" > /dev/null
[ "$(as_postgres -c "SELECT 1 FROM pg_database WHERE datname='appdb'")" = "1" ] \
  || as_postgres -c "CREATE DATABASE appdb OWNER app"
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U app -d appdb -v ON_ERROR_STOP=1 -q -f /vagrant/app/schema.sql

ufw allow 22/tcp > /dev/null
ufw allow from "$WEB1_IP" to any port 5432 proto tcp > /dev/null
ufw allow from "$WEB2_IP" to any port 5432 proto tcp > /dev/null
ufw --force enable > /dev/null
