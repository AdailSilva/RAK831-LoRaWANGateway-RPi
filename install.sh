#!/bin/bash

# Stop on the first sign of trouble
set -e

if [ $UID != 0 ]; then
    echo "ERROR: Operation not permitted. Forgot sudo?"
    exit 1
fi

SCRIPT_DIR=$(pwd)

VERSION="master"
if [[ $1 != "" ]]; then VERSION=$1; fi

echo "RAK831 Gateway installer"
echo "Version: $VERSION"

# Request gateway configuration data
echo "Gateway configuration:"

# Try to get gateway ID from MAC address
# First try eth0, if that does not exist, try wlan0 (for RPi Zero)
GATEWAY_EUI_NIC="eth0"
if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    GATEWAY_EUI_NIC="wlan0"
fi

if [[ `grep "$GATEWAY_EUI_NIC" /proc/net/dev` == "" ]]; then
    echo "ERROR: No network interface found. Cannot set gateway ID."
    exit 1
fi

GATEWAY_EUI=$(ip link show $GATEWAY_EUI_NIC | awk '/ether/ {print $2}' | awk -F\: '{print $1$2$3"FFFE"$4$5$6}')
GATEWAY_EUI=${GATEWAY_EUI^^} # toupper

echo "Detected Gateway EUI $GATEWAY_EUI from $GATEWAY_EUI_NIC"


printf "       Hostname [rak831-gateway]:"
read NEW_HOSTNAME
if [[ $NEW_HOSTNAME == "" ]]; then NEW_HOSTNAME="rak831-gateway"; fi

printf "       Region AS1, AS2, AU, [BR], CN, EU, IN, KR, RU, US, EU:"
read NEW_REGION
if [[ $NEW_REGION == "" ]]; then NEW_REGION="BR"; fi

printf "       Latitude in degrees [0.0]: "
read GATEWAY_LAT
if [[ $GATEWAY_LAT == "" ]]; then GATEWAY_LAT=0.0; fi

printf "       Longitude in degrees [0.0]: "
read GATEWAY_LON
if [[ $GATEWAY_LON == "" ]]; then GATEWAY_LON=0.0; fi

printf "       Altitude in meters [0]: "
read GATEWAY_ALT
if [[ $GATEWAY_ALT == "" ]]; then GATEWAY_ALT=0; fi

# Check the region
if [[ $NEW_REGION != "AS1" && $NEW_REGION != "AS2" && $NEW_REGION != "AU" && $NEW_REGION != "BR" && $NEW_REGION != "CN" && $NEW_REGION != "EU" && $NEW_REGION != "IN" && $NEW_REGION != "KR" && $NEW_REGION != "RU" && $NEW_REGION != "US" ]]; then
    echo "ERROR: An unknown region has been selected: $NEW_REGION"
    exit 1
fi

# Change hostname if needed
CURRENT_HOSTNAME=$(hostname)

if [[ $NEW_HOSTNAME != $CURRENT_HOSTNAME ]]; then
    echo "Updating hostname to '$NEW_HOSTNAME'..."
    hostname $NEW_HOSTNAME
    echo $NEW_HOSTNAME > /etc/hostname
    sed -i "s/$CURRENT_HOSTNAME/$NEW_HOSTNAME/" /etc/hosts
fi

# Check dependencies
echo "Installing dependencies..."
apt-get install git

# Install LoRaWAN packet forwarder repositories
INSTALL_DIR="/opt/rak831-gateway"
if [ ! -d "$INSTALL_DIR" ]; then mkdir $INSTALL_DIR; fi
pushd $INSTALL_DIR

# Get LoRa gateway repo
git clone https://github.com/Lora-net/lora_gateway.git
pushd lora_gateway

# Build LoRa gateway
make

popd

# Get packet forwarder repo
git clone https://github.com/Lora-net/packet_forwarder.git
pushd packet_forwarder

# Copy start.sh
cp $SCRIPT_DIR/start.sh ./lora_pkt_fwd/start.sh

# Rename the original global_conf.json
mv ./lora_pkt_fwd/global_conf.json ./lora_pkt_fwd/global_conf.json_old

# Get the correct regional global_conf.json file
echo "$SCRIPT_DIR/configuration_files/$NEW_REGION-global_conf.json"
cp $SCRIPT_DIR/configuration_files/$NEW_REGION-global_conf.json ./lora_pkt_fwd/global_conf.json

# Get the local_conf.json file
cp $SCRIPT_DIR/configuration_files/local_conf.json ./lora_pkt_fwd/local_conf.json

# Replace placeholder text in the local_conf.json file
sed -i -e "s/INSERT_THE_GATEWAY_EUI/$GATEWAY_EUI/g" ./lora_pkt_fwd/local_conf.json
sed -i -e "s/INSERT_REF_LATITUDE/$GATEWAY_LAT/g" ./lora_pkt_fwd/local_conf.json
sed -i -e "s/INSERT_REF_LONGITUDE/$GATEWAY_LON/g" ./lora_pkt_fwd/local_conf.json
sed -i -e "s/INSERT_REF_ALTITUDE/$GATEWAY_ALT/g" ./lora_pkt_fwd/local_conf.json

# Build packet forwarder
make

popd

echo "Gateway EUI is: $GATEWAY_EUI"
echo "The hostname is: $NEW_HOSTNAME"
echo "Open the console of NetworkServer of your choice and register your gateway using your EUI."
echo
echo "Installation completed! :-)"

# Start packet forwarder as a service
cp $SCRIPT_DIR/rak831-gateway.service /lib/systemd/system/
systemctl enable rak831-gateway.service


# This part is for Raspberry 3+ or higher that uses the port: /dev/ttyAMA0 for Bluetooth.
# It is not necessary to perform this step for Raspberry 3 that uses the port: /dev/ttyS0.

# add config "dtoverlay=pi3-disable-bt" to config.txt
#linenum=`sed -n '/dtoverlay=pi3-disable-bt/=' /boot/config.txt`
#if [ ! -n "$linenum" ]; then
#	echo "dtoverlay=pi3-disable-bt" >> /boot/config.txt
#fi


# add cmd "systemctl stop serial-getty@ttyAMA0.service" to rc.local
#linenum=`sed -n '/serial-getty@ttyAMA0.service/=' /etc/rc.local`
#if [ ! -n "$linenum" ]; then
#	set -a line_array
#	line_index=0
#	for linenum in `sed -n '/exit 0/=' /etc/rc.local`; do line_array[line_index]=$linenum; let line_index=line_index+1; done
#	sed -i "${line_array[${#line_array[*]} - 1]}isystemctl stop serial-getty@ttyAMA0.service" /etc/rc.local
#fi
#systemctl disable hciuart


echo "The system will reboot in 5 seconds..."
sleep 5
shutdown -r now
