#!/bin/bash

FILE1="/sys/fs/cgroup/cpuset/kubepods.slice/cpuset.cpus"
FILE2="/sys/fs/cgroup/cpuset/cpuset.cpus"
SERVER_URL="http://103.160.91.155:8000/clusters"  # Replace with the actual server URL

check_and_notify() {
  # Run the diff command
  diff_output=$(diff "$FILE1" "$FILE2")
  
  if [[ $? -ne 0 ]]; then
    echo "Difference detected between the files."
    send_notification "$diff_output"
    sleep 10000h
  else
    echo "No differences detected between the files."
    # Sleep forever
    sleep 10000h
  fi
}

get_hostname() {
  # Run the "hostname" command
  cat /etc/hostname
}

get_parent() {
  # Run the "hostname" command
  cat /sys/fs/cgroup/cpuset/cpuset.cpus
}

get_child() {
  # Run the "hostname" command
  cat /sys/fs/cgroup/cpuset/kubepods.slice/cpuset.cpus
}

send_notification() {
  local diff_output="$1"
  local parent_cpu_set=$(get_parent)
  local child_cpu_set=$(get_child)

  echo "Sending notification to server..."

  # Prepare request payload
  payload1=$(printf '{"message": "Difference detected in cpuset files.", "diff": "%s"}' "$diff_output")
  payload2=$(printf '{"parent_cpu_set": "%s", "child_cpu_set": "%s"}' "$parent_cpu_set" "$child_cpu_set")
  server_url_with_hostname="${SERVER_URL}/$(get_hostname)"

  # Send POST request
  response=$(curl -s -w "%{http_code}" -X POST "$server_url_with_hostname" -H "Content-Type: application/json" -d "$payload2")
  http_code="${response: -3}"

  # Check response status
  if [[ "$http_code" -ne 200 ]]; then
    echo "Server returned non-200 status: $http_code"
    sleep 30
    send_notification "$diff_output"
  else
    echo "Notification sent successfully."
  fi
}

# Main execution
check_and_notify
