#!/bin/bash
#
# Copyright (c) 2021-2024, NVIDIA CORPORATION.  All rights reserved.

set -e

USER_NAME="admin"
USER_HOME="/home/${USER_NAME}"

HOST_USER_UID="${HOST_USER_UID:=1000}"
HOST_USER_GID="${HOST_USER_GID:=1000}"

print_info() {
    echo "workspace-entrypoint: $1"
}

# 1. multicastを有効化
/usr/sbin/ip link set lo multicast on

# 2. sysctlの値を直接書き込む 
sysctl -w net.core.rmem_max=2147483647
sysctl -w net.ipv4.ipfrag_time=3
sysctl -w net.ipv4.ipfrag_high_thresh=134217728

print_info "Custom network settings applied."

export HOME=${USER_HOME}
chown -R ${HOST_USER_UID}:${HOST_USER_GID} ${USER_HOME}

# ============================================================
# デバイス権限の動的設定関数
# $1: デバイスパス, $2: デフォルト名, $3: デフォルトGID
# ============================================================
setup_device_perms() {
    local DEV_PATH=$1
    local GROUP_NAME=$2
    local DEFAULT_GID=$3

    if [ -e "$DEV_PATH" ]; then
        local HOST_GID=$(stat -c '%g' "$DEV_PATH")
        print_info "Detected $DEV_PATH GID: ${HOST_GID}"
        
        local EXISTING_GROUP=$(getent group ${HOST_GID} | cut -d: -f1)
        if [ -n "${EXISTING_GROUP}" ]; then
            usermod -aG "${EXISTING_GROUP}" "${USER_NAME}"
            print_info "Added '${USER_NAME}' to existing group '${EXISTING_GROUP}'"
        else
            groupadd -g "${HOST_GID}" "${GROUP_NAME}"
            usermod -aG "${GROUP_NAME}" "${USER_NAME}"
            print_info "Created group '${GROUP_NAME}' (GID: ${HOST_GID}) and added '${USER_NAME}'"
        fi
    else
        print_info "WARNING: Device $DEV_PATH not found. Skipping."
    fi
}

# 3. ジョイスティック (joy_node)
setup_device_perms "/dev/input/js0" "input_host" 101

# 4. GPIO (jetracer_node)
# GPIOは特殊なため、既存のロジック（GID 999固定）を維持
if [ -c /dev/gpiochip0 ]; then
    HOST_GPIO_GID=999
    EXISTING_GPIO_GROUP=$(getent group ${HOST_GPIO_GID} | cut -d: -f1)
    if [ -n "${EXISTING_GPIO_GROUP}" ]; then
        usermod -aG ${EXISTING_GPIO_GROUP} ${USER_NAME}
    else
        groupadd -g ${HOST_GPIO_GID} gpio
        usermod -aG gpio ${USER_NAME}
    fi
    print_info "GPIO permissions configured (GID: 999)"
fi

# 5. I2C (jetracer_node)
setup_device_perms "/dev/i2c-7" "i2c_host" 102

# 6. YDLIDAR (Serial Port) 
# /dev/ydlidar があれば優先、なければ /dev/ttyUSB0 をチェック
if [ -c /dev/ydlidar ]; then
    setup_device_perms "/dev/ydlidar" "ydlidar_host" 103
elif [ -c /dev/ttyUSB0 ]; then
    setup_device_perms "/dev/ttyUSB0" "dialout_host" 103
else
    print_info "WARNING: Lidar device not found on /dev/ydlidar or /dev/ttyUSB0"
fi

export ROS_DOMAIN_ID="${ROS_DOMAIN_ID:=0}"
print_info "Using ROS_DOMAIN_ID=${ROS_DOMAIN_ID}"

exec gosu ${USER_NAME} "$@"