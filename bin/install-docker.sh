#!/bin/bash

# --------------------------------------------------------------------------------
# Update System
# --------------------------------------------------------------------------------

sudo apt update
sudo apt-get upgrade -y

# --------------------------------------------------------------------------------
# Install Certificates
# --------------------------------------------------------------------------------

sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# --------------------------------------------------------------------------------
# Add the repository to Apt sources:
# --------------------------------------------------------------------------------

sudo echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# --------------------------------------------------------------------------------
# Install Docker
# --------------------------------------------------------------------------------

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
