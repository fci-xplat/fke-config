#!/bin/bash
echo "*** FPT Cloud - Kubernetes Engine GPU reset ***"
#kill gpu process
echo "*Kill gpu processes are running: "
PIDS=$(lsof -t /dev/nvidia0)
if [[ -z $PIDS ]]; then
     echo "No processes using gpu found"
else
     for PID in $PIDS; do
     echo "Killing process $PID"
     kill -9 $PID
     done
fi
#remove module gpu
echo "*Remove gpu modules: "
nvidia_mod=$(lsmod | grep nvidia)
if [[ -z "$nvidia_mod" ]]; then
     echo "No nvidia modules load"
else
     rmmod -f nvidia_uvm nvidia_drm nvidia_modeset nvidia
     if [ $? -eq 0 ] ; then
          echo "All modules had been removed"
          module_status=removed
     else
          echo "Modules were not removed"
          module_status="not removed"
     fi
fi
#reset gpu
echo "*Check mig instance: " && nvidia-smi -L
echo "*Reset gpu: " && nvidia-smi --gpu-reset
if [ $? -eq 0 ] ; then
     echo "GPU was reset succeeded"
     reset_status=successfull
else
     echo "GPU was reset failed"
     reset_status=failed
fi
#enable mig
echo "*Enable MIG: "
mig_status=$(nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv,noheader)
if [ $mig_status == "Enabled" ]; then
     echo "MIG is $mig_status"
else
     nvidia-smi -i 0 -mig 1
fi
#reset result
echo "=== GPU reset result ==="
echo "- GPU instances: " && nvidia-smi -L
echo "- GPU processes are running: " && fuser -v /dev/nvidia* && ps -ef | grep nvidia
if [[ -z "$(fuser -v /dev/nvidia*)" ]]; then echo "None process";fi
echo "- GPU remove modules: $module_status"
echo "- GPU reset status: $reset_status"
echo "- GPU MIG status: $mig_status"
echo "GPU reset process finished"
