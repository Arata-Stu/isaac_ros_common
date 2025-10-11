#!/bin/bash
#
# Copyright (c) 2021-2024, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of a software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

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

# --- ここから追加 ---
# joy_nodeのために、inputグループが存在することを確認し、ユーザーを所属させる
print_info "Adding user '${USER_NAME}' to 'input' group for joystick access."
getent group input &>/dev/null || groupadd input
usermod -aG input ${USER_NAME}
# --- ここまで追加 ---

exec gosu ${USER_NAME} "$@"