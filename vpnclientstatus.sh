#!/bin/bash
# =============================================================
# OpenVPN — Ulangan userlar statusi
# Foydalanish: bash vpn-status.sh
# =============================================================

STATUS_LOG="/var/log/openvpn/status.log"

if [[ ! -f "$STATUS_LOG" ]]; then
    echo "[!] Status log topilmadi: $STATUS_LOG"
    exit 1
fi

echo ""
echo "=============================================="
echo "  OpenVPN — Ulangan userlar"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================================="
echo ""

# CLIENT_LIST qatorlarini olish
mapfile -t LINES < <(grep "^CLIENT_LIST," "$STATUS_LOG")
COUNT=${#LINES[@]}

if [[ $COUNT -eq 0 ]]; then
    echo "  Hozir hech kim ulanmagan."
    echo ""
    exit 0
fi

echo "  Ulangan: $COUNT ta user"
echo ""
printf "  %-20s %-25s %-12s %-10s %-10s %s\n" \
    "Username" "Real IP" "VPN IP" "Rx" "Tx" "Ulangan vaqt"
echo "  --------------------------------------------------------------------------------------"

for line in "${LINES[@]}"; do
    IFS=',' read -r _ cn real_addr virt_addr virt6 bytes_rx bytes_tx connected_since _rest <<< "$line"

    rx_mb=$(awk "BEGIN {printf \"%.1f MB\", $bytes_rx/1048576}")
    tx_mb=$(awk "BEGIN {printf \"%.1f MB\", $bytes_tx/1048576}")

    printf "  %-20s %-25s %-12s %-10s %-10s %s\n" \
        "$cn" "$real_addr" "$virt_addr" "$rx_mb" "$tx_mb" "$connected_since"
done

echo ""
echo "  [ Log: $STATUS_LOG | Yangilanadi: har 30s ]"
echo ""
