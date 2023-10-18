#!/bin/bash

THERMAL_PATH="/sys/class/thermal/"
POLLING_INTERVAL=0.1

cleanup() {
    tput cnorm  # Restore cursor
    clear
    exit 0
}

trap cleanup INT TERM

tput civis      # Hide cursor
printf '\033c'  # Clear screen with scrollable buffer

generate_data() {
    local prefix=$1
    local value_path=$2
    local label_path=${3:-$value_path}
    local output=""

    for folder in $(ls "$THERMAL_PATH" | grep "$prefix" | sort); do
        local label=$(cat "${THERMAL_PATH}${folder}/${label_path}")
        local value=$(cat "${THERMAL_PATH}${folder}/${value_path}")
        output+="$label: $value\n"
    done
    echo -n "$output"
}

while true; do
    buffer="Cooling Devices:\n"
    buffer+=$(generate_data "cooling_device" "cur_state" "type")
    buffer+="\nThermal Zones:\n"
    buffer+=$(generate_data "thermal_zone" "temp" "type")

    printf '\033c'
    echo -e "$buffer"
    sleep ${POLLING_INTERVAL}
done
