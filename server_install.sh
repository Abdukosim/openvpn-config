#!/bin/bash
# =============================================================
# OpenVPN Server — To'liq o'rnatish skripti
# Debian 12 | TCP/3334 | NAT orqasida
# Server ichki IP: 192.168.0.6
# =============================================================

set -euo pipefail

# ── O'zgaruvchilar ──────────────────────────────────────────
EASYRSA_DIR="/etc/openvpn/easy-rsa"
PKI_DIR="$EASYRSA_DIR/pki"
SERVER_CONF="/etc/openvpn/server/server.conf"
SERVER_CERT_NAME="OpenVPN"

BIND_IP="192.168.0.6"
VPN_SUBNET="10.11.1.0"
VPN_MASK="255.255.255.0"
PUSH_ROUTE="192.168.0.0/24"
DNS_SERVER="10.11.1.1"
DOMAIN="test.uz"

# ── [1/5] Paketlar ──────────────────────────────────────────
echo "=== [1/5] Paketlar o'rnatilmoqda ==="
apt-get update -y
apt-get install -y openvpn easy-rsa iptables-persistent

# ── [2/5] PKI va sertifikatlar ──────────────────────────────
echo "=== [2/5] Easy-RSA PKI tayyorlanmoqda ==="
mkdir -p "$EASYRSA_DIR"
cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"
cd "$EASYRSA_DIR"

cat > "$EASYRSA_DIR/vars" <<VARSEOF
set_var EASYRSA_REQ_COUNTRY    "UZ"
set_var EASYRSA_REQ_PROVINCE   "Tashkent"
set_var EASYRSA_REQ_CITY       "Tashkent"
set_var EASYRSA_REQ_ORG        "Private"
set_var EASYRSA_REQ_EMAIL      "admin@test.uz"
set_var EASYRSA_REQ_OU         "IT"
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    825
set_var EASYRSA_ALGO           rsa
set_var EASYRSA_KEY_SIZE       2048
VARSEOF

./easyrsa init-pki
echo "yes" | ./easyrsa --batch build-ca nopass
./easyrsa --batch gen-req "$SERVER_CERT_NAME" nopass
echo "yes" | ./easyrsa --batch sign-req server "$SERVER_CERT_NAME"
./easyrsa gen-dh

# ── [3/5] server.conf ───────────────────────────────────────
echo "=== [3/5] Server config yozilmoqda ==="
mkdir -p /etc/openvpn/server
mkdir -p /etc/openvpn/ccd
mkdir -p /var/log/openvpn

cat > "$SERVER_CONF" <<CONFEOF
# ===========================================
# OpenVPN Server — Private
# ===========================================

# ── General ──────────────────────────────
mode server
tls-server
proto tcp-server
port 3334
dev tun
local $BIND_IP

# ── Network ──────────────────────────────
server $VPN_SUBNET $VPN_MASK
topology subnet
keepalive 10 60

# ── Certificates ─────────────────────────
ca   $PKI_DIR/ca.crt
cert $PKI_DIR/issued/${SERVER_CERT_NAME}.crt
key  $PKI_DIR/private/${SERVER_CERT_NAME}.key
dh   $PKI_DIR/dh.pem

# ── Client verification ───────────────────
verify-client-cert require

# ── Routing ──────────────────────────────
push "route $PUSH_ROUTE"

# ── Push options ──────────────────────────
push "block-ipv6"
push "dhcp-option DOMAIN $DOMAIN"
push "dhcp-option DOMAIN-SEARCH $DOMAIN"
push "dhcp-option DNS $DNS_SERVER"

# ── Misc ──────────────────────────────────
client-config-dir /etc/openvpn/ccd
persist-key
persist-tun
verb 3
mute 10

# ── Log ──────────────────────────────────
status /var/log/openvpn/status.log 30
log-append /var/log/openvpn/server.log
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-CBC
CONFEOF

# ── [4/5] IP forwarding va NAT ──────────────────────────────
echo "=== [4/5] IP forwarding va NAT ==="
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo "  Tashqi interfeys: $IFACE"

iptables -t nat -A POSTROUTING -s "${VPN_SUBNET}/${VPN_MASK}" -o "$IFACE" -j MASQUERADE
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -A FORWARD -o tun0 -j ACCEPT
netfilter-persistent save

# ── [5/5] Service ────────────────────────────────────────────
echo "=== [5/5] OpenVPN service yoqilmoqda ==="
systemctl enable openvpn-server@server
systemctl restart openvpn-server@server
sleep 2
systemctl status openvpn-server@server --no-pager

echo ""
echo "=============================="
echo "  OpenVPN o'rnatildi!"
echo "=============================="
echo "  Bind IP  : $BIND_IP:3334"
echo "  VPN net  : $VPN_SUBNET/$VPN_MASK"
echo "  DNS      : $DNS_SERVER"
echo "  Domain   : $DOMAIN"
echo "  PKI      : $PKI_DIR"
echo "  Log      : /var/log/openvpn/server.log"
echo ""
echo "=============================="
