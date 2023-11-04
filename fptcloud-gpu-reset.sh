#!/bin/bash
#remove module gpu
echo "Remove gpu modules: "
nvidia_mod=$(lsmod | grep nvidia)
if [[ -z "$nvidia_mod" ]]; then
     echo "No nvidia modules load"
else
     echo "Remove nvidia modules: "
     rmmod -f nvidia_uvm nvidia_drm nvidia_modeset nvidia
fi
#reset gpu
echo "Check mig instance: " && nvidia-smi -L
echo "Reset gpu" && nvidia-smi --gpu-reset
#kill gpu process
echo "Kill gpu processes is running: "
PIDS=$(lsof -t /dev/nvidia0)
if [[ -z $PIDS ]]; then
     echo "No processes using gpu found"
     exit 1
else
     for PID in $PIDS; do
     echo "Killing process $PID"
     kill -9 $PID
     done
fi
#enable mig
mig_status=$(nvidia-smi -i 0 --query-gpu=mig.mode.current --format=csv,noheader)
if [ $mig_status == "Enabled" ]; then
     echo "MIG is $mig_status"
else
     nvidia-smi -i 0 -mig 1
fi
#reset result
echo "GPU reset result: " && nvidia-smi -L
echo "Check gpu processes: " && fuser -v /dev/nvidia* && ps -ef | grep nvidia
