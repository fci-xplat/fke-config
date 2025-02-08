#!/bin/bash
# Copyright 2024 FPT Cloud - PaaS

set -o errexit
set -o pipefail
set -u

set -x

PREVENT_UPGRADE_DIR="${PREVENT_UPGRADE_DIR:-/var/cache}"
CACHE_FILE="${PREVENT_UPGRADE_DIR}/.cache"
INFRA_PLATFORM="${INFRA_PLATFORM:-VMW}" #VMW/OSP
BLOCK_KERNEL="${BLOCK_KERNEL:-5.15.0-107}"
REVERT_OPERATION="${REVERT_OPERATION:-false}"
KERNEL_VERSION=$(uname -r)
# KEEP_KERNEL="${KEEP_KERNEL:-5.15.0-76}"
#GRUB_FILE_CONFIG="${GRUB_FILE_CONFIG:-/boot/grub/grub.cfg}"
set +x

check_cached_version() {
  echo "Checking cached version"
  if [[ ! -f "${CACHE_FILE}" ]]; then
    echo "Cache file ${CACHE_FILE} not found."
    return 1
  fi
  . "${CACHE_FILE}"
  if [[ "${BLOCK_KERNEL}" == "${CACHE_BLOCK_KERNEL_VERSION}" ]]; then
    echo "Found existing kernel reverter for latest kernel version ${BLOCK_KERNEL}."
    return 0
  fi
  echo "Cache file ${CACHE_FILE} found but existing kernel versions didn't match."
  return 1
}

update_cached_version() {
  cat >"${CACHE_FILE}"<<__EOF__
  CACHE_BLOCK_KERNEL_VERSION=${BLOCK_KERNEL}
__EOF__
  echo "Updated cached version as:"
  cat "${CACHE_FILE}"
}

init_kernel_version() {
  echo "Checking Infra Platform"
  if [[ "${INFRA_PLATFORM}" == "VMW" ]]; then
    echo "Infra Platform using VMware"
    KEEP_KERNEL="5.15.0-88"
  else
    KEEP_KERNEL="5.15.0-76"
  fi
}

prevent_upgrade_kernel() {
  echo "Prevent upgrade OS kernel"
  apt-mark hold linux-image-${KEEP_KERNEL}-generic
  apt-mark hold linux-image-${BLOCK_KERNEL}-generic
}

update_grub_config() {
  MID=$(awk '/Advanced options for Ubuntu/{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2)
  KID=$(awk "/with Linux $KEEP_KERNEL/"'{print $(NF-1)}' /boot/grub/grub.cfg | cut -d\' -f2 | head -n1)

  cat > /etc/default/grub.d/95-savedef.cfg <<__EOF__
  GRUB_DEFAULT=saved
  GRUB_SAVEDEFAULT=true
__EOF__
  grub-editenv /boot/grub/grubenv set saved_entry="${MID}>${KID}"
  update-grub
}

check_kernel_version() {
  dpkg -l | grep linux-image
  uname -r
  uname -a 
  echo "Kernel version is: linux-image-$KERNEL_VERSION"
}

revert_script_action() {
  echo "reverting action performed by this script..."
  echo "unholding kernel version.."
  apt-mark unhold linux-image-"${KEEP_KERNEL}"-generic
  apt-mark unhold linux-image-"${BLOCK_KERNEL}"-generic
  echo "removing cache file..."
  rm "${CACHE_FILE}"
  echo "revert boot entry..."
  rm /etc/default/grub.d/95-savedef.cfg
  grub-editenv /boot/grub/grubenv unset saved_entry
  update-grub
  echo "reverted action performed by this script"
}

disable_unattended_upgrades() {
  curl https://raw.githubusercontent.com/fci-xplat/fke-config/main/50unattended-upgrades > /etc/apt/apt.conf.d/50unattended-upgrades
  curl https://raw.githubusercontent.com/fci-xplat/fke-config/refs/heads/main/20auto-upgrades > /etc/apt/apt.conf.d/20auto-upgrades
}

main() { 
  if [[ "${REVERT_OPERATION}" == "true" ]]; then
    init_kernel_version
    revert_script_action
  elif check_cached_version; then
    check_kernel_version
  else
    init_kernel_version
    prevent_upgrade_kernel
    update_grub_config
    disable_unattended_upgrades
    update_cached_version
    check_kernel_version
  fi
}

main "$@"
sleep infinity
