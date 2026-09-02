#!/bin/bash

# Function: Display colored status icon based on exit code
show_status() {
    local status=$1
    if [ "$status" -eq 0 ]; then
        echo -e "\e[32m\u2714\e[0m" # Green ✔
    else
        echo -e "\e[31m\u2718\e[0m" # Red ✘
    fi
}

# Function: Run any command quietly and display status icon
run_task() {
    local label="$1"
    shift
    local cmd=("$@")

    echo -n "$label... "

    # Execute command in background redirecting output to /dev/null
    "${cmd[@]}" > /dev/null 2>&1 &
    local pid=$!

    # Wait for completion and capture the exit code
    wait "$pid"
    local exit_code=$?

    # Print final status icon
    show_status "$exit_code"
    return "$exit_code"
}

# --- functions ---

cleanup_snap() {
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do sudo snap remove "$snapname" --revision="$revision"; done
}

# --- Usage Example ---

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

run_task "Cleanup Package list" apt autoremove
run_task "Cleanup Snap" cleanup_snap
