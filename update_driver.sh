#! /bin/bash
# Copyright 2024 FPT Cloud - PaaS

set -o errexit
set -o pipefail
set -u

#target driver info
TARGET_DRIVER_VERSION=${TARGET_DRIVER_VERSION:?"Missing diver version name"}
MAJOR_DRIVER_BRANCH="${TARGET_DRIVER_VERSION%%.*}"
DRIVER_FILE_NAME="NVIDIA-Linux-x86_64-${TARGET_DRIVER_VERSION}.run"
FABRIC_MANAGER_FILE="nvidia-fabricmanager-${MAJOR_DRIVER_BRANCH}_${TARGET_DRIVER_VERSION}-1_amd64.deb"
NSCQ_LIB_FILE="libnvidia-nscq-${MAJOR_DRIVER_BRANCH}_${TARGET_DRIVER_VERSION}-1_amd64.deb"
#for upgrading linux kernel purpose
TARGET_KERNEL_VERSION=${TARGET_KERNEL_VERSION:-""}

_kill_all_gpu_processes() {
    sudo kill -9 $(sudo fuser -v /dev/nvidia* 2>/dev/null | awk 'NF>1 {for (i=2; i<=NF; i++) print $i}' | sort -u) 2>/dev/null || true
}

_host_driver() {
    # check if driver is pre-installed on the host
    if [ -f /host/usr/bin/nvidia-smi ] || [ -L /host/usr/bin/nvidia-smi ]; then
        DRIVER_VERSION=$(chroot /host nvidia-smi --query-gpu=driver_version --format=csv,noheader)
        if [ $? == 0 ] && [ ! -z "${DRIVER_VERSION}" ]; then
            return 0
        fi
    fi

    return 1
}


_uninstall_driver() {
    # don't attempt to un-install if driver is pre-installed on the node
    if ! _host_driver; then
        echo "NVIDIA GPU driver is not installed on node, continue ..."
    else
        echo "Uninstalling all gpu components in silent mode"
        if sudo nvidia-uninstall --silent ; then
            echo "nvidia driver uninstalled sucessfully"
        else
            echo "nvidia driver is failed to uninstall"
            exit 1
        fi
    fi
}

_uninstall_fabricmanager() {
    echo "========== removing Fabric manager =========="
    old_fabric_manager_service=$(dpkg -l "*fabric*" 2>/dev/null | awk '/^ii/ {print $2}' || true)
    if dpkg -P $old_fabric_manager_service ; then
        echo "Fabric manager uninstalled sucessfully"
    else
        echo "Fabric manager is failed to uninstall"
        exit 1
    fi
}


_uninstall_nscq() {
    echo "========== removing NSCQ =========="
    old_nscq_service=$(dpkg -l "*nscq*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true)
    if dpkg -P $old_nscq_service ; then
        echo "NSCQ lib uninstalled sucessfully"
    else
        echo "NSCQ lib is failed to uninstall"
        exit 1
    fi
}

_install_driver() {
    echo "Downloading nvidia driver file..."
    wget https://us.download.nvidia.com/tesla/$TARGET_DRIVER_VERSION/$DRIVER_FILE_NAME -O $DRIVER_FILE_NAME
    chmod +x ${DRIVER_FILE_NAME}
    dpkg -l | grep linux-image
    uname -r
    apt install -y linux-headers-$(uname -r)
    echo "========== start setup nvidia driver =========="
    ./$DRIVER_FILE_NAME -s -a --allow-installation-with-running-driver
    echo "Verifying Nvidia installation..."
    modinfo nvidia
    echo "========== finish setup nvidia driver =========="
    rm -f ${DRIVER_FILE_NAME}    
}

_install_fabricmanager() {
    echo "Downloading nvidia fabricmanager file..."
    echo "installing nvidia fabricmanager"
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/$FABRIC_MANAGER_FILE -O $FABRIC_MANAGER_FILE
    dpkg -i ${FABRIC_MANAGER_FILE}
    if dpkg -l "*fabric*" 2>/dev/null | awk '/^ii/ {print $2}' || true; then
        echo "Fabric Manager is installed sucessfully"
        rm -f ${FABRIC_MANAGER_FILE}
        systemctl enable nvidia-fabricmanager
        systemctl start nvidia-fabricmanager
    else
        echo "Fabric Manager is failed to install"
        exit 1
    fi
}

_install_nscq() {
    echo "Downloading nvswitch configuration and query lib file..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/$NSCQ_LIB_FILE -O $NSCQ_LIB_FILE
    dpkg -i ${NSCQ_LIB_FILE}
    if dpkg -l "*nscq*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true; then
        echo "NSCQ lib installed sucessfully"
        rm -f ${NSCQ_LIB_FILE}
    else
        echo "NSCQ lib is failed to install"
        exit 1
    fi
}

preflight_check() {
    # TODO: add checks for driver package availability for current kernel
    # TODO: add checks for driver dependencies
    # TODO: add checks for entitlements(OCP)
    current_kernel_version=$(uname -r)
    current_driver_version=$(nvidia-smi -i 0 --query-gpu=driver_version --format=csv,noheader || true)
    current_fabric_manager_version=$(dpkg -l "*fabric*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true)
    current_nscq_version=$(dpkg -l "*nscq*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true)

    echo "linux header: ${current_kernel_version}"
    echo "current driver version: ${current_driver_version}"
    echo "current fabric manager version: ${current_fabric_manager_version}"
    echo "current nscq version: ${current_nscq_version}"
    echo "==========Operating system info:=========="
    cat /etc/os-release
    exit 0
}


upgrade_nvidia_package_components() {
    #check current fabric manager
    current_fabric_manager_service=$(dpkg -l "*fabric*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true)
    if [ -z "$current_fabric_manager_service" ]; then
        echo "do not detect fabric manager on this system, skipping upgrade fabric manager..."
    else
        _uninstall_fabricmanager
        _install_fabricmanager
    fi
    #check current NSCQ
    current_nscq_service=$(dpkg -l "*nscq*" 2>/dev/null | awk '/^(ii|hi)/ {print $2}' || true)
    if [ -z "$current_nscq_service" ]; then
        echo "do not detect nscq on this system, skipping upgrade nscq..."
    else
        _uninstall_nscq
        _install_nscq
    fi
    #update gpu drivers
    _kill_all_gpu_processes
    _uninstall_driver
    _install_driver
    #reboot 
    echo "install all components successfully, reboot after 15 seconds, use ctr + C to abort ..."
    sleep 15
    reboot 
}

change_kernel_version() {
    if [ ! -z "$TARGET_KERNEL_VERSION" ]; then
        target_kernel_version=$TARGET_KERNEL_VERSION
    else
        echo "TARGET_KERNEL_VERSION variable was not set, aborting to change kernel now ..."
        exit 1
    fi

    echo "upgrade node to kernel version ${target_kernel_version}"
    sudo apt update
    sudo apt install -y linux-image-${target_kernel_version}-generic
    
    MID=$(awk '/Advanced options for Ubuntu/{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2)
    KID=$(awk "/with Linux $target_kernel_version/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2 | head -n1)

    cat > /etc/default/grub.d/95-savedef.cfg <<__EOF__
    GRUB_DEFAULT=saved
    GRUB_SAVEDEFAULT=true
__EOF__
    grub-editenv /boot/grub/grubenv set saved_entry="${MID}>${KID}"
    update-grub
    #reboot to change os to latest kernel
    echo "upgrade linux kernel successfully, reboot after 15 seconds, use ctr + C to abort ..."
    sleep 15
    reboot
}


usage() {
    cat >&2 <<EOF
Usage: $0 COMMAND [ARG...]

Commands:
  upgrade_nvidia_package_components
  preflight_check
  change_kernel_version
EOF
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi
command=$1; shift
case "${command}" in
    upgrade_nvidia_package_components) ;;
    preflight_check) ;;
    change_kernel_version) ;;
    *) usage ;;
esac
if [ $? -ne 0 ]; then
    usage
fi

$command