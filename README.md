OpenVPN Server — Debian 12
Debian 12 da OpenVPN server o'rnatish va boshqarish uchun skriptlar to'plami.

NAT orqasida ishlaydi (Kerio Control yoki boshqa firewall).

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Foydali buyruqlar
bash# Service holati
systemctl status openvpn-server@server

# Log kuzatish
tail -f /var/log/openvpn/server.log

# Config tekshirish
openvpn --config /etc/openvpn/server/server.conf --verb 6

# Barcha sertifikatlar
ls /etc/openvpn/easy-rsa/pki/issued/
