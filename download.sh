#!/bin/bash

BASE_URL="https://raw.githubusercontent.com/mohawkey/public/refs/heads/main/bin/"

download_script() {
    local script_name="$1"
    local url="${BASE_URL}${script_name}"

    read -r -p "Do you want to download ${script_name}? [y/N]: " answer

    case "$answer" in
        [yY]|[yY][eE][sS])
            echo "Downloading ${script_name}..."
            wget "$url"
            ;;
        *)
            echo "Skipping ${script_name}."
            ;;
    esac
}

download_script "install-docker.sh"
download_script "update.sh"
download_script "cleanup.sh"
