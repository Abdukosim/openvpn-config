#!/bin/bash
# =============================================================
# OpenVPN — User qo'shish + Telegram xabar
# Server config: TCP/3334, 10.11.1.0/24
# Foydalanish: bash add-user.sh <username>
# =============================================================

set -euo pipefail

# ── Sozlamalar ─────────────────────────────────────────────
EASYRSA_DIR="/etc/openvpn/easy-rsa"
PKI_DIR="$EASYRSA_DIR/pki"
OUTPUT_DIR="/etc/openvpn/clients"
CCD_DIR="/etc/openvpn/ccd"

SERVER_IP="1.1.1.1"      # tashqi IP (Kerio NAT)
SERVER_PORT="3334"              # tashqi port (Kerio NAT)
SERVER_CERT_NAME="OpenVPN"      # server sertifikat nomi

# ── Telegram ───────────────────────────────────────────────
TG_TOKEN="YOURIPKEY"
TG_CHAT_ID="YOURID"

# ── Argument tekshirish ────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Foydalanish: $0 <username>"
    echo "Misol:       $0 johndoe"
    exit 1
fi

USERNAME="$1"
CLIENT_CONF="$OUTPUT_DIR/${USERNAME}.ovpn"

if [[ -f "$PKI_DIR/issued/${USERNAME}.crt" ]]; then
    echo "[!] ${USERNAME} uchun sertifikat allaqachon mavjud."
    echo "    Revoke qilish: bash revoke-user.sh ${USERNAME}"
    exit 1
fi

# ── Telegram funksiyalar ───────────────────────────────────
tg_send() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT_ID}" \
        -d parse_mode="HTML" \
        -d text="$1" > /dev/null
}

tg_send_file() {
    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
        -F chat_id="${TG_CHAT_ID}" \
        -F document=@"$1" \
        -F caption="$2" > /dev/null
}

# ── [1/4] Sertifikat yaratish ──────────────────────────────
echo "=== [1/4] Sertifikat: $USERNAME ==="
cd "$EASYRSA_DIR"
./easyrsa --batch gen-req "$USERNAME" nopass
echo "yes" | ./easyrsa --batch sign-req client "$USERNAME"

# ── [2/4] CCD — routing server tomondan ───────────────────
echo "=== [2/4] CCD route yozilmoqda ==="
mkdir -p "$CCD_DIR"

# server.conf da route-noexec/route-nopull bor —
# har bir user uchun CCD da route belgilanadi (server tomondan)
cat > "$CCD_DIR/${USERNAME}" <<EOF
# ${USERNAME} uchun server-side routing
push "route 192.168.0.0 255.255.255.0"
EOF

# ── [3/4] .ovpn fayl ──────────────────────────────────────
echo "=== [3/4] .ovpn fayl tayyorlanmoqda ==="
mkdir -p "$OUTPUT_DIR"

CA_CERT=$(cat "$PKI_DIR/ca.crt")
CLIENT_CERT=$(openssl x509 -in "$PKI_DIR/issued/${USERNAME}.crt" -out /dev/stdout 2>/dev/null)
CLIENT_KEY=$(cat "$PKI_DIR/private/${USERNAME}.key")
EXPIRE_DATE=$(openssl x509 -in "$PKI_DIR/issued/${USERNAME}.crt" -noout -enddate | cut -d= -f2)

cat > "$CLIENT_CONF" <<EOF
# OpenVPN Client — ${USERNAME}
# Server: ${SERVER_IP}:${SERVER_PORT}
# Yaratildi: $(date '+%Y-%m-%d %H:%M')

client
dev tun
