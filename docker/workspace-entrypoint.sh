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

print_info "Creating non-root container '${USER_NAME}' for host user uid=${HOST_USER_UID}:gid=${HOST_USER_GID}"

groupmod -n ${USER_NAME} -g ${HOST_USER_GID} $(getent group ${HOST_USER_GID} | cut -d: -f1) &>/dev/null || \
groupadd -g ${HOST_USER_GID} ${USER_NAME} &>/dev/null

usermod -l ${USER_NAME} -u ${HOST_USER_UID} -g ${HOST_USER_GID} $(getent passwd ${HOST_USER_UID} | cut -d: -f1) &>/dev/null || \
useradd -u ${HOST_USER_UID} -g ${HOST_USER_GID} -m -s /bin/bash ${USER_NAME} &>/dev/null

echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${USER_NAME}
chmod 0440 /etc/sudoers.d/${USER_NAME}

usermod -a -G dialout,sudo,video,audio,input ${USER_NAME}
id jtop &>/dev/null && usermod -a -G jtop ${USER_NAME}

print_info "Applying custom network settings..."

# 1. multicastを有効化
/usr/sbin/ip link set lo multicast on

# 2. sysctlの値を直接書き込む 
sysctl -w net.core.rmem_max=2147483647
sysctl -w net.ipv4.ipfrag_time=3
sysctl -w net.ipv4.ipfrag_high_thresh=134217728

print_info "Custom network settings applied."

export HOME=${USER_HOME}
chown -R ${HOST_USER_UID}:${HOST_USER_GID} ${USER_HOME}

export ROS_DOMAIN_ID=33

exec gosu ${USER_NAME} "$@"