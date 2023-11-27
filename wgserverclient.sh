#!/bin/bash
# installation of wireguard server and first client config file. must be
# ran as root
#
if [ "$EUID" -ne 0 ]
then echo "Please run as root"
exit 1
else echo "Welcome! Let's get started."
fi
echo "To confirm, are you running a Debian/Ubuntu derivitive? Select 'n' if on a Fedora/RHEL based distrobution. (y or n) "
read -r debian
if [ "${debian}" = "y" ]
then sudo apt install -y wireguard wireguard-tools
else sudo yum install -y wireguard-tools
fi
umask 077
wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub
touch /etc/wireguard/wg0.conf
{ echo "[Interface]" ; echo "Address = 10.100.0.1/24, fd08:4711::1/64" ; echo "ListenPort = 47111" ; echo "PrivateKey = $(cat /etc/wireguard/server.key)" ; echo "\n" ; } >> /etc/wireguard/wg0.conf
sudo systemctl enable wg-quick@wg0.service
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg0
echo "Confirmation of WireGuard Interface: "
sudo wg
sleep 3
echo "What is the name of the 1st peer/device that we'll add to the VPN setup?"
read -r client
echo "Creating config for ${client}. "
sleep 1
echo "One moment, please..."
sleep 2
wg genkey | tee "/etc/wireguard/${client}.key" | wg pubkey > "/etc/wireguard/${client}.pub"
wg genpsk > "/etc/wireguard/${client}.psk"
{ echo "[Peer]" ; echo "PublicKey = $(cat /etc/wireguard/${client}.pub)" ; echo "PresharedKey = $(cat /etc/wireguard/${client}.psk)" ; echo "AllowedIPs = 10.100.0.2/32, fd08:4711::2/128" ; echo "\n" ; } >> /etc/wireguard/wg0.conf
wg syncconf wg0 <(wg-quick strip wg0)
{ echo "[Interface]" ; echo "Address = 10.100.0.2/32, fd08:4711::2/128" ; echo "DNS = 10.100.0.1" ; echo "PrivateKey = $(cat /etc/wireguard/${client}.key)" ; echo "\n" ; } >> "/etc/wireguard/${client}.conf"
#
echo "Installing QRencode. This will grant the ability to scan a QR code for easily importing the config file to ${client}. "
sleep 3
if [ "${debian}" = "y" ]
then sudo apt install -y qrencode
else sudo yum install -y qrencode
fi
echo "Please confirm the external IP address, or the domain name for this connection: "
read -r conn
echo "Great! Almost there! "
#
{ echo "[Peer]" ; echo "AllowedIPs = 10.100.0.1/32, fd08:4711::1/128" ; echo "Endpoint = ${conn}:47111" ; echo "PersistentKeepalive = 25" ; echo "PublicKey = $(cat /etc/wireguard/server.pub)" ; echo "PresharedKey = $(cat /etc/wireguard/${client}.psk)" ; echo "\n" ; } >> "/etc/wireguard/${client}.conf"
#
echo "Generating QR code: "
sleep 3
qrencode -t ansiutf8 < "/etc/wireguard/${client}.conf"
echo "Ensure to open port 47111 on your router/firewall and forward requests to this machine's internal IP address. Your VPN should be up and operational after importing the above config (potentially via the generated QR code) to ${client}. "
sleep 5
echo "fin!"
