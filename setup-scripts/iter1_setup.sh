#!/bin/bash
set -euo pipefail

# =============================================================================
# Kea DHCP Server Full Setup Script (Working Version)
# =============================================================================

info() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }
die() { err "$*"; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"; }

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
PING_HOST=${PING_HOST:-8.8.8.8}

KEA_PACKAGES=(
  isc-kea-admin
  isc-kea-common
  isc-kea-dhcp4
  isc-kea-dhcp6
  isc-kea-hooks
  isc-kea-ctrl-agent
  isc-kea-mysql
  mysql-client
)

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-firewall}
DB_USER=${DB_USER:-kea_user}
DB_USER_PASSWORD=${DB_USER_PASSWORD:-kea@123}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-}

INTERFACE4=${INTERFACE4:-eth0}
INTERFACE6=${INTERFACE6:-eth0}

SUBNET4=${SUBNET4:-192.168.100.0/24}
POOL4=${POOL4:-192.168.100.50-192.168.100.200}
ROUTER4=${ROUTER4:-192.168.100.1}

SUBNET6=${SUBNET6:-2001:db8:1::/64}
POOL6=${POOL6:-2001:db8:1::100-2001:db8:1::1ff}

DNS4=${DNS4:-"8.8.8.8,8.8.4.4"}
DNS6=${DNS6:-"2001:4860:4860::8888,2001:4860:4860::8844"}

DHCP4_CONF=/etc/kea/kea-dhcp4.conf
DHCP6_CONF=/etc/kea/kea-dhcp6.conf
CTRL_CONF=/etc/kea/kea-ctrl-agent.conf

# -----------------------------------------------------------------------------
# Preflight
# -----------------------------------------------------------------------------
require_cmd apt
require_cmd mysql

ping -c1 -W5 "$PING_HOST" >/dev/null || die "No internet connectivity"

# -----------------------------------------------------------------------------
# Install Packages
# -----------------------------------------------------------------------------
info "Installing Kea packages"
curl -fsSL https://dl.cloudsmith.io/public/isc/kea-3-0/setup.deb.sh | bash
apt update
apt install -y "${KEA_PACKAGES[@]}"

# -----------------------------------------------------------------------------
# MySQL Setup
# -----------------------------------------------------------------------------
if [[ -z "$DB_ROOT_PASSWORD" ]]; then
  MYSQL_ROOT_ARGS=(-u root)
else
  MYSQL_ROOT_ARGS=(-u root -p"$DB_ROOT_PASSWORD")
fi

info "Creating database and user"
mysql "${MYSQL_ROOT_ARGS[@]}" <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_USER_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# -----------------------------------------------------------------------------
# Initialize Kea Schema
# -----------------------------------------------------------------------------
info "Initializing Kea database schema"
kea-admin db-init mysql \
  -u "$DB_USER" \
  -p "$DB_USER_PASSWORD" \
  -n "$DB_NAME" || die "DB init failed"

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
info "Setting up log directories"
mkdir -p /var/log/kea
chown -R kea:kea /var/log/kea

# -----------------------------------------------------------------------------
# DHCPv4 Configuration
# -----------------------------------------------------------------------------
info "Writing DHCPv4 config"
cat >"$DHCP4_CONF" <<EOF
{
  "Dhcp4": {
    "interfaces-config": {
      "interfaces": [ "$INTERFACE4" ]
    },
    "lease-database": {
      "type": "mysql",
      "name": "$DB_NAME",
      "user": "$DB_USER",
      "password": "$DB_USER_PASSWORD",
      "host": "$DB_HOST",
      "port": $DB_PORT
    },
    "option-data": [
      { "name": "domain-name-servers", "data": "$DNS4" },
      { "name": "routers", "data": "$ROUTER4" }
    ],
    "subnet4": [
      {
        "subnet": "$SUBNET4",
        "pools": [ { "pool": "$POOL4" } ]
      }
    ],
    "loggers": [
      {
        "name": "kea-dhcp4",
        "severity": "INFO",
        "output_options": [
          {
            "output": "/var/log/kea/kea-dhcp4.log"
          }
        ]
      }
    ]
  }
}
EOF

# -----------------------------------------------------------------------------
# DHCPv6 Configuration
# -----------------------------------------------------------------------------
info "Writing DHCPv6 config"
cat >"$DHCP6_CONF" <<EOF
{
  "Dhcp6": {
    "interfaces-config": {
      "interfaces": [ "$INTERFACE6" ]
    },
    "lease-database": {
      "type": "mysql",
      "name": "$DB_NAME",
      "user": "$DB_USER",
      "password": "$DB_USER_PASSWORD",
      "host": "$DB_HOST",
      "port": $DB_PORT
    },
    "subnet6": [
      {
        "subnet": "$SUBNET6",
        "pools": [ { "pool": "$POOL6" } ]
      }
    ],
    "option-data": [
      { "name": "dns-servers", "data": "$DNS6" }
    ],
    "loggers": [
      {
        "name": "kea-dhcp6",
        "severity": "INFO",
        "output_options": [
          {
            "output": "/var/log/kea/kea-dhcp6.log"
          }
        ]
      }
    ]
  }
}
EOF

# -----------------------------------------------------------------------------
# Control Agent
# -----------------------------------------------------------------------------
info "Configuring control agent"
cat >"$CTRL_CONF" <<EOF
{
  "Control-agent": {
    "http-host": "127.0.0.1",
    "http-port": 8000,
    "control-sockets": {
      "dhcp4": {
        "socket-type": "unix",
        "socket-name": "/run/kea/kea4-ctrl-socket"
      },
      "dhcp6": {
        "socket-type": "unix",
        "socket-name": "/run/kea/kea6-ctrl-socket"
      }
    }
  }
}
EOF

# -----------------------------------------------------------------------------
# Enable and Restart Services
# -----------------------------------------------------------------------------
info "Enabling and restarting services"
systemctl enable isc-kea-dhcp4-server isc-kea-dhcp6-server isc-kea-ctrl-agent
systemctl restart isc-kea-dhcp4-server isc-kea-dhcp6-server isc-kea-ctrl-agent

info "Kea DHCP server setup COMPLETE"
