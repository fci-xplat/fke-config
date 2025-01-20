#!/bin/bash

check_cpuset() {
    echo "- Node:"
    echo $(cat /etc/hostname)
    echo "- cpuset/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus)
    echo "- kube.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kube.slice/cpuset.cpus)
    echo "- kube.slice/cpuset.effective_cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kube.slice/cpuset.effective_cpus)
    echo "- kube.slice/kubelet.service/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kube.slice/kubelet.service/cpuset.cpus)
    echo "- kube.slice/kubelet.service/cpuset.effective_cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kube.slice/kubelet.service/cpuset.effective_cpus)
    echo "- kubepods.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/cpuset.cpus)
    echo "- kubepods.slice/cpuset.effective_cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/cpuset.effective_cpus)
    echo "- kubepods.slice/kubepods-besteffort.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-besteffort.slice/cpuset.cpus)
    echo "- kubepods.slice/kubepods-besteffort.slice/cpuset.effective_cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-besteffort.slice/cpuset.effective_cpus)
    echo "- kubepods.slice/kubepods-burstable.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-burstable.slice/cpuset.cpus)
    echo "- kubepods.slice/kubepods-burstable.slice/cpuset.effective_cpus"
    echo $(cat /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-burstable.slice/cpuset.effective_cpus)
}

fix_cpuset() {
    echo "*** Difference detected between the cpuset.cpus files."
    echo "- kubepods.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus) > /sys/fs/cgroup/cpuset/kubepods.slice/cpuset.cpus
    echo "- kube.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus) > /sys/fs/cgroup/cpuset/kube.slice/cpuset.cpus
    echo "- kube.slice/kubelet.service/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus) > /sys/fs/cgroup/cpuset/kube.slice/kubelet.service/cpuset.cpus
    echo "- kubepods.slice/kubepods-besteffort.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus) > /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-besteffort.slice/cpuset.cpus
    echo "- kubepods.slice/kubepods-burstable.slice/cpuset.cpus"
    echo $(cat /sys/fs/cgroup/cpuset/cpuset.cpus) > /sys/fs/cgroup/cpuset/kubepods.slice/kubepods-burstable.slice/cpuset.cpus
}

# Main execution
main() {
  FILE1="/sys/fs/cgroup/cpuset/kubepods.slice/cpuset.cpus"
  FILE2="/sys/fs/cgroup/cpuset/cpuset.cpus"
  diff_output=$(diff "$FILE1" "$FILE2")
  if [[ $? -ne 0 ]]; then
    fix_cpuset
    check_cpuset
  else
    echo "*** No differences detected between the cpuset.cpus files."
    check_cpuset
  fi
}

main "$@"
sleep infinity
