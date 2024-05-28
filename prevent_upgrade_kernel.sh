#!/bin/bash
# Copyright 2023 FPT Cloud - PaaS

set -o errexit
set -o pipefail
set -u

set -x


PREVENT_UPGRADE_DIR="${PREVENT_UPGRADE_DIR:-/usr/local/prevent-upgrade-kernel}"

CACHE_FILE="${PREVENT_UPGRADE_DIR}/.cache"
INFRA_PLATFORM="${INFRA_PLATFORM:-VMW}" #VMW/OSP
# KEEP_KERNEL="${KEEP_KERNEL:-5.15.0-76}"
BLOCK_KERNEL="${BLOCK_KERNEL:-5.15.0-107}"
#GRUB_FILE_CONFIG="${GRUB_FILE_CONFIG:-/boot/grub/grub.cfg}"
KERNEL_VERSION="$(uname -r)"
set +x

check_cached_version() {
  echo "Checking cached version"
  if [[ ! -f "${CACHE_FILE}" ]]; then
    echo "Cache file ${CACHE_FILE} not found."
    return 1
  fi

  # Source the cache file and check if the cached driver matches
  # currently running kernel version and requested driver versions.
  . "${CACHE_FILE}"
  if [[ "${KERNEL_VERSION}" == "${CACHE_KERNEL_VERSION}" ]]; then
    echo "Found existing kernel version keeper for kernel version ${KERNEL_VERSION}."
    return 0
  fi
  echo "Cache file ${CACHE_FILE} found but existing versions didn't match."
  return 1
}

update_cached_version() {
  cat >"${CACHE_FILE}"<<__EOF__
CACHE_KERNEL_VERSION=${KERNEL_VERSION}
__EOF__

  echo "Updated cached version as:"
  cat "${CACHE_FILE}"
}


init_kernel_version() {
  mkdir $PREVENT_UPGRADE_DIR
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

  cat > /etc/default/grub.d/95-savedef.cfg <<EOF
  GRUB_DEFAULT=saved
  GRUB_SAVEDEFAULT=true
EOF
  grub-editenv /boot/grub/grubenv set saved_entry="${MID}>${KID}"
  update-grub
}

check_kernel_version() {
  dpkg -l | grep linux-image
  uname -r
  uname -a 
  echo "Kernel version is: linux-image-$KERNEL_VERSION"
}


main() {
  if check_cached_version; then
    check_kernel_version
  else
    init_kernel_version
    prevent_upgrade_kernel
    update_grub_config
    update_cached_version
    check_kernel_version
  fi
}

main "$@"
sleep infinity
