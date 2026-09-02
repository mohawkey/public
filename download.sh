#!/bin/bash

BASE_URL="https://raw.githubusercontent.com/mohawkey/public/refs/heads/main/bin/"

# Function: Display colored status icon based on exit code
show_status() {
    local status="$1"

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

    echo -n "$label... "

    "$@" > /dev/null 2>&1 &
    local pid=$!

    wait "$pid"
    local exit_code=$?

    show_status "$exit_code"

    return "$exit_code"
}

# Function: Ask user and download a script
download_script() {
    local script_name="$1"
    local url="${BASE_URL}${script_name}"

    read -r -p "Do you want to download ${script_name}? [y/N]: " answer

    case "$answer" in
        [yY]|[yY][eE][sS])
            if run_task "Downloading ${script_name}" wget -q -O "$script_name" "$url"; then
                chmod +x "$script_name"
                return 0
            else
                echo "Failed to download ${script_name}."
                return 1
            fi
            ;;

        *)
            echo "Skipping ${script_name}."
            return 0
            ;;
    esac
}

download_script "install-docker.sh"
download_script "update.sh"
download_script "cleanup.sh"
