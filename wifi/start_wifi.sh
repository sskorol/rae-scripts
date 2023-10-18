#!/bin/bash

TIMEOUT=2
MAX_RETRIES=10
PING_TARGET="8.8.8.8"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

start_wifi_service() {
    wifi_status=$(systemctl is-active wifi)

    if [ "$wifi_status" == "active" ]; then
        echo "Wi-Fi service is already up and running."
        return
    fi

    echo "Starting Wi-Fi service..."
    systemctl start wifi

    retries=0
    while [ "$wifi_status" != "active" ] && [ $retries -lt $MAX_RETRIES ]; do
        echo "Attempt $retries: waiting for Wi-Fi service to start..."
        sleep $TIMEOUT
        wifi_status=$(systemctl is-active wifi)
        ((retries++))
    done
    
    if [ "$wifi_status" == "active" ]; then
        echo "Wi-Fi service has successfully started after $retries attempts."
    else
        echo "Failed to start Wi-Fi service after $MAX_RETRIES attempts."
        exit 1
    fi
}

restart_wpa_supplicant() {
    if pgrep wpa_supplicant > /dev/null; then
        echo "wpa_supplicant is already running. Restarting it..."
        killall wpa_supplicant

        retries=0
        while pgrep wpa_supplicant > /dev/null && [ $retries -lt $MAX_RETRIES ]; do
            sleep $TIMEOUT
            ((retries++))
        done

        if [ $retries -eq $MAX_RETRIES ]; then
            echo "Failed to terminate wpa_supplicant after $MAX_RETRIES attempts."
            exit 1
        fi
    fi
}

restart_wireless_driver() {
    ip link set wlp1s0 down
    sleep $TIMEOUT

    # Check for any dependent modules of iwlwifi and remove them first
    local deps=$(lsmod | grep iwlwifi | awk '{print $4}' | tr ',' ' ')
    for dep in $deps; do
        modprobe -r $dep
    done

    echo "Restarting wireless driver..."
    modprobe -r iwlwifi
    sleep $TIMEOUT
    modprobe iwlwifi
    sleep $TIMEOUT

    ip link set wlp1s0 up
    sleep $TIMEOUT
}

check_internet_connectivity() {
    retries=0
    while ! ping -c 1 $PING_TARGET &> /dev/null && [ $retries -lt $MAX_RETRIES ]; do
        echo "Failed to establish Internet connectivity. Retrying in $TIMEOUT seconds..."
        sleep $TIMEOUT
        ((retries++))
    done

    if [ $retries -eq $MAX_RETRIES ]; then
        echo "Max retries reached. Unable to establish Internet connectivity."
        exit 4
    fi
}

start_wifi_service
restart_wpa_supplicant
restart_wireless_driver

wpa_supplicant -i wlp1s0 -c /etc/wpa_supplicant.conf -B
if [ $? -ne 0 ]; then
    echo "Failed to start wpa_supplicant."
    exit 2
fi

systemctl restart systemd-networkd
if [ $? -ne 0 ]; then
    echo "Failed to restart systemd-networkd."
    exit 3
fi

check_internet_connectivity
echo "Wi-Fi setup complete. Enjoy!"
