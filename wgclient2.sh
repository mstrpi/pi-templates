#!/bin/bash
# used for adding another client to current wireguard installation. must have wireguard and qrencode installed prior to running with a working vpn in place (presumably interface wg0. update as needed).
#
# should not matter debian vs rhel base.  best if used after wgserverclient.sh
#
# must be ran as root
#
if [ "$EUID" -ne 0 ]
then echo "Please run as root"
exit 1
else echo "Welcome! Let's get started."
fi
#
umask 077
sleep 1
#
echo "What is the name for the next peer/device that we'll connect to the VPN?"
read -r client
echo "Creating config for ${client}. What number shall be assigned to the ip after 10.100.0.___? (typically the next value after the one created previously, check with your network admin for confirmation) "
read -r addy
echo "One moment, please..."
sleep 2
#
wg genkey | tee "/etc/wireguard/${client}.key" | wg pubkey > "/etc/wireguard/${client}.pub"
wg genpsk > "/etc/wireguard/${client}.psk"
{ echo "[Peer]" ; echo "PublicKey = $(cat /etc/wireguard/${client}.pub)" ; echo "PresharedKey = $(cat /etc/wireguard/${client}.psk)" ; echo "AllowedIPs = 10.100.0.${addy}/32, fd08:4711::${addy}/128" ; echo "\n" ; } >> /etc/wireguard/wg0.conf
wg syncconf wg0 <(wg-quick strip wg0)
{ echo "[Interface]" ; echo "Address = 10.100.0.${addy}/32, fd08:4711::${addy}/128" ; echo "DNS = 10.100.0.1" ; echo "PrivateKey = $(cat /etc/wireguard/${client}.key)" ; echo "\n" ; } >> "/etc/wireguard/${client}.conf"
#
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