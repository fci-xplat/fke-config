#!/bin/bash
# Copyright 2023 FPT Cloud - PaaS

set -o errexit
set -o pipefail
set -u

set -x

INFRA_PLATFORM="${INFRA_PLATFORM:-VMW}" #VMW/OSP
# KEEP_KERNEL="${KEEP_KERNEL:-5.15.0-76}"
BLOCK_KERNEL="${BLOCK_KERNEL:-5.15.0-107}"
#GRUB_FILE_CONFIG="${GRUB_FILE_CONFIG:-/boot/grub/grub.cfg}"

set +x

# check_cache() {
#   echo "Checking cached version"
#   if [[ ! -f "${CACHE_FILE}" ]]; then
#     echo "Cache file ${CACHE_FILE} not found."
#     return 1
#   fi
# }

init_kernel_version() {
  echo "Checking Infra Platform"
  if [[ "${INFRA_PLATFORM}" == "VMW" ]]; then
    echo "Infra Platform using VMware"
    KEEP_KERNEL="5.15.0-76"
  else
    KEEP_KERNEL="5.15.0-88"
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

  cat > /etc/default/grub.d/95-savedef.cfg < EOF
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
  echo "Kerbel version is:"
  linux-image-$(uname -r)
}

main() {
  init_kernel_version
  prevent_upgrade_kernel
  update_grub_config
  check_kernel_version
}

main "$@"
sleep infinity
