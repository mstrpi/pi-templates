#!/bin/bash
# installation of wireguard server and first client config file. must be
# ran as root. the intention is for this to be used for pihole/wg setup, but 
# could be used in general use case. It will install server tools for 
# debian/fedora, nftables, and create 1st peer config file. 
#
if [ "$EUID" -ne 0 ]
then echo "Please run as root! "
exit 1
else echo "Welcome! Let's get started. "
fi
echo "To confirm, are you running a Debian/Ubuntu derivitive? "
echo "Select 'n' if on a Fedora/RHEL based distrobution. (y or n) "
read -r debian
if [ "${debian}" = "y" ]
then sudo apt install -y wireguard wireguard-tools nftables
else sudo yum install -y wireguard-tools nftables
fi
umask 077
mkdir -p /etc/wireguard/server/
wg genkey | tee /etc/wireguard/server/server.key | wg pubkey > /etc/wireguard/server/server.pub
touch /etc/wireguard/wg0.conf
{ echo "[Interface] # server " ; echo "Address = 10.100.0.1/24, fd08:4711::1/64" ; echo "ListenPort = 47111" ; echo "PrivateKey = $(cat /etc/wireguard/server/server.key)" ; echo ; } >> /etc/wireguard/wg0.conf
{ echo "PostUp = nft add table ip wireguard; nft add chain ip wireguard wireguard_chain {type nat hook postrouting priority srcnat\; policy accept\;}; nft add rule ip wireguard wireguard_chain counter packets 0 bytes 0 masquerade; nft add table ip6 wireguard; nft add chain ip6 wireguard wireguard_chain {type nat hook postrouting priority srcnat\; policy accept\;}; nft add rule ip6 wireguard wireguard_chain counter packets 0 bytes 0 masquerade" ; echo "PostDown = nft delete table ip wireguard; nft delete table ip6 wireguard" ; echo ; } >> /etc/wireguard/wg0.conf
systemctl enable --now nftables
systemctl enable wg-quick@wg0.service
systemctl daemon-reload
systemctl start wg-quick@wg0
echo "Confirmation of WireGuard Interface: "
wg
sleep 3
echo "What is the name of the 1st peer/device to be added to this VPN setup? "
read -r client
echo -e "Creating config for ${client}. "
mkdir -p /etc/wireguard/${client}/
echo "One moment, please... "
sleep 2
wg genkey | tee /etc/wireguard/${client}/${client}.key | wg pubkey > /etc/wireguard/${client}/${client}.pub
wg genpsk > /etc/wireguard/${client}/${client}.psk
{ echo "[Peer] # ${client} " ; echo -e "PublicKey = $(cat /etc/wireguard/${client}/${client}.pub) " ; echo -e "PresharedKey = $(cat /etc/wireguard/${client}/${client}.psk) " ; echo "AllowedIPs = 10.100.0.2/32, fd08:4711::2/128" ; echo ; } >> /etc/wireguard/wg0.conf
wg syncconf wg0 <(wg-quick strip wg0)
{ echo "[Interface] # ${client} " ; echo "Address = 10.100.0.2/32, fd08:4711::2/128" ; echo "DNS = 10.100.0.1" ; echo -e "PrivateKey = $(cat /etc/wireguard/${client}/${client}.key) " ; echo ; } >> /etc/wireguard/${client}/${client}.conf
echo -e "Installing QRencode. This will grant the ability to scan a QR code for easily importing this config file to ${client}. "
sleep 4
if [ "${debian}" = "y" ]
then sudo apt install -y qrencode
else sudo yum install -y qrencode
fi
echo "Please enter the external IP address, or the domain name for this connection: "
read -r conn
echo "Great! Almost there! "
echo "Enabling forwarding: "
{ echo "net.ipv4.ip_forward = 1" ; echo "net.ipv6.conf.all.forwarding = 1" ; echo ; } >> /etc/sysctl.d/99-ipforward.conf
sysctl -p /etc/sysctl.d/99-ipforward.conf
{ echo "[Peer] # server " ; echo "AllowedIPs = 10.100.0.1/32, fd08:4711::1/128" ; echo "Endpoint = ${conn}:47111" ; echo "PersistentKeepalive = 25" ; echo "PublicKey = $(cat /etc/wireguard/server/server.pub) " ; echo -e "PresharedKey = $(cat /etc/wireguard/${client}/${client}.psk) " ; echo ; } >> /etc/wireguard/${client}/${client}.conf
echo "Generating QR code: "
sleep 2
qrencode -t ansiutf8 < /etc/wireguard/${client}/${client}.conf
sleep 2
echo -e "Ensure to open port 47111 on your router/firewall and forward requests to this machine's internal IP address. Your VPN should be up and operational after importing the above config (potentially via the generated QR code) to ${client}. "
sleep 5
echo "fin!"
