#!/bin/bash
# Copyright 2023 FPT Cloud - PaaS

set -o errexit
set -o pipefail
set -u

set -x
NVIDIA_DRIVER_BRANCH="XFree86"
NVIDIA_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION:-510.108.03}"
NVIDIA_TOOLKIT_INSTALL="${NVIDIA_TOOLKIT_INSTALL:-true}"
NVIDIA_DRIVER_DOWNLOAD_URL_DEFAULT="https://download.nvidia.com/${NVIDIA_DRIVER_BRANCH}/Linux-x86_64/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
NVIDIA_DRIVER_DOWNLOAD_URL_SECOND="https://us.download.nvidia.com/tesla//${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run"
NVIDIA_DRIVER_DOWNLOAD_URL="${NVIDIA_DRIVER_DOWNLOAD_URL:-$NVIDIA_DRIVER_DOWNLOAD_URL_DEFAULT}"
NVIDIA_INSTALL_DIR_HOST="${NVIDIA_INSTALL_DIR_HOST:-/var/lib/nvidia}"
NVIDIA_INSTALL_DIR_CONTAINER="${NVIDIA_INSTALL_DIR_CONTAINER:-/usr/local/nvidia}"
NVIDIA_INSTALLER_RUNFILE="$(basename "${NVIDIA_DRIVER_DOWNLOAD_URL}")"
ROOT_MOUNT_DIR="${ROOT_MOUNT_DIR:-/root}"
CACHE_FILE="${NVIDIA_INSTALL_DIR_CONTAINER}/.cache"
KERNEL_VERSION="$(uname -r)"
NVIDIA_TOOLKIT_LIB_URL="https://nvidia.github.io/libnvidia-container/gpgkey"
OS_DISTRIBUTION=$(. /etc/os-release;echo $ID$VERSION_ID)
NVIDIA_TOOLKIT_DOWNLOAD_URL="https://nvidia.github.io/libnvidia-container/stable/${OS_DISTRIBUTION}/nvidia-container-toolkit.list"
NVIDIA_GPU_RESET="${NVIDIA_GPU_RESET:-true}"
# NVIDIA_TOOLKIT_DOWNLOAD_URL="https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list"
# CONFIG_NVIDIA_CONTAINERD_DOWNLOAD_URL="https://raw.githubusercontent.com/fci-xplat/fke-config/main/config.toml"
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
    if [[ "${NVIDIA_DRIVER_VERSION}" == "${CACHE_NVIDIA_DRIVER_VERSION}" ]]; then
      echo "Found existing driver installation for kernel version ${KERNEL_VERSION} and driver version ${NVIDIA_DRIVER_VERSION}."
      return 0
    fi
  fi
  echo "Cache file ${CACHE_FILE} found but existing versions didn't match."
  return 1
}

update_cached_version() {
  cat >"${CACHE_FILE}"<<__EOF__
CACHE_KERNEL_VERSION=${KERNEL_VERSION}
CACHE_NVIDIA_DRIVER_VERSION=${NVIDIA_DRIVER_VERSION}
__EOF__

  echo "Updated cached version as:"
  cat "${CACHE_FILE}"
}

#update_container_ld_cache() {
#  echo "Updating container's ld cache..."
#  echo "${NVIDIA_INSTALL_DIR_CONTAINER}/lib64" > /etc/ld.so.conf.d/nvidia.conf
#  ldconfig
#  echo "Updating container's ld cache... DONE."
#}

download_kernel_src() {
  echo "Downloading kernel sources..."
  apt-get update && apt-get install -y linux-headers-${KERNEL_VERSION}
  echo "Downloading kernel sources... DONE."
}

configure_nvidia_installation_dirs() {
  echo "Configuring installation directories..."
  mkdir -p "${NVIDIA_INSTALL_DIR_CONTAINER}"
  pushd "${NVIDIA_INSTALL_DIR_CONTAINER}"

  # Populate ld.so.conf to avoid warning messages in nvidia-installer logs.
#  update_container_ld_cache

  # Install an exit handler to cleanup the overlayfs mount points.
  popd
  echo "Configuring installation directories... DONE."
}

download_nvidia_installer() {
  set +e
  echo "Download Nvidia driver from $NVIDIA_DRIVER_DOWNLOAD_URL"
  pushd "${NVIDIA_INSTALL_DIR_CONTAINER}"
  curl -L -S -f "${NVIDIA_DRIVER_DOWNLOAD_URL}" -o "${NVIDIA_INSTALLER_RUNFILE}"
  if [[ -f "${NVIDIA_INSTALLER_RUNFILE}" ]]; then
    popd
    echo "Downloading Nvidia driver... DONE."
    set -e
  else
    set -e
    NVIDIA_DRIVER_DOWNLOAD_URL="${NVIDIA_DRIVER_DOWNLOAD_URL_SECOND}"
    NVIDIA_INSTALLER_RUNFILE="$(basename "${NVIDIA_DRIVER_DOWNLOAD_URL}")"
    echo "Download Nvidia driver from $NVIDIA_DRIVER_DOWNLOAD_URL"
    curl -L -S -f "${NVIDIA_DRIVER_DOWNLOAD_URL}" -o "${NVIDIA_INSTALLER_RUNFILE}"
    popd
    echo "Downloading Nvidia driver... DONE."
  fi
}

run_nvidia_installer() {
  echo "Running Nvidia installer..."
  pushd "${NVIDIA_INSTALL_DIR_CONTAINER}"
  sh "${NVIDIA_INSTALLER_RUNFILE}" \
    --log-file-name="${NVIDIA_INSTALL_DIR_CONTAINER}/nvidia-installer.log" \
    --silent \
    --no-cc-version-check \
    --accept-license
  popd
  echo "Running Nvidia installer... DONE."
}

# configure_cached_installation() {
#   echo "Configuring cached driver installation..."
# #  update_container_ld_cache
#   if ! lsmod | grep -w 'nvidia' > /dev/null; then
#     insmod "${NVIDIA_INSTALL_DIR_CONTAINER}/drivers/nvidia.ko"
#   fi
#   if ! lsmod | grep -w 'nvidia_uvm' > /dev/null; then
#     insmod "${NVIDIA_INSTALL_DIR_CONTAINER}/drivers/nvidia-uvm.ko"
#   fi
#   echo "Configuring cached driver installation... DONE"
# }

verify_nvidia_installation() {
  echo "Verifying Nvidia installation..."
  export PATH="${NVIDIA_INSTALL_DIR_CONTAINER}/bin:${PATH}"
  nvidia-smi
  # Create unified memory device file.
  nvidia-modprobe -c0 -u
  echo "Verifying Nvidia installation... DONE."
}

clean_nvidia_installation() {
  rm -rf ${NVIDIA_INSTALL_DIR_CONTAINER}/${NVIDIA_INSTALLER_RUNFILE} ${CACHE_FILE}
  echo "Clean Nvidia installation... DONE."
}

install_nvidia_toolkit() {
  echo "Add gpg key for NVIDIA-toolkit ..."
  curl -fsSL ${NVIDIA_TOOLKIT_LIB_URL} | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L ${NVIDIA_TOOLKIT_DOWNLOAD_URL} |
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  # curl -s -L ${NVIDIA_TOOLKIT_LIB_URL} | sudo apt-key add -
  #curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/libnvidia-container.list
  # curl -s -L ${NVIDIA_TOOLKIT_DOWNLOAD_URL} | sudo tee /etc/apt/sources.list.d/libnvidia-container.list
  
  echo "Installing NVIDIA-toolkit ..."
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=containerd
  nvidia-ctk -v
  echo "Install NVIDIA-toolkit... DONE"
}

change_default_container_runtime() {
  echo "Changing config default container runtime to nvidia..."
  # curl -Ls ${CONFIG_NVIDIA_CONTAINERD_DOWNLOAD_URL} > "/etc/containerd/config.toml"
  sed -i 's\default_runtime_name = "runc"\default_runtime_name = "nvidia"\g' /etc/containerd/config.toml
  echo "Change default runtime... DONE"
  systemctl restart containerd
}

reset_gpu_config() {
  echo "Resetting GPU config ..."
  curl -Ls https://raw.githubusercontent.com/fci-xplat/fke-config/main/fptcloud-user-gpu-reset.sh | bash -s -- -p admin
  echo "Reset GPU config... DONE"
  echo "Disable MIG"
  nvidia-smi -i 0 -mig 0
}

# update_host_ld_cache() {
#   echo "Updating host's ld cache..."
#   echo "${NVIDIA_INSTALL_DIR_HOST}/lib64" >> "${ROOT_MOUNT_DIR}/etc/ld.so.conf"
#   ldconfig -r "${ROOT_MOUNT_DIR}"
#   echo "Updating host's ld cache... DONE."
# }

main() {
  if check_cached_version; then
    #configure_cached_installation
    verify_nvidia_installation
  else
    download_kernel_src
    configure_nvidia_installation_dirs
    download_nvidia_installer
    run_nvidia_installer
    update_cached_version
    if ${NVIDIA_TOOLKIT_INSTALL}; then
      echo "Installing NVIDIA TOOLKIT..."
      install_nvidia_toolkit
      change_default_container_runtime
    else
      echo "Ignore NVIDIA TOOLKIT..."
    fi
    if ${NVIDIA_GPU_RESET}; then
      echo "GPU RESET CONFIG..."
      reset_gpu_config
    else
      echo "Ignore GPU RESET..."
    fi
    verify_nvidia_installation
  fi
  clean_nvidia_installation
  # update_host_ld_cache
}

main "$@"
sleep infinity
