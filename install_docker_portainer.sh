#!/bin/bash

# Update and install dependencies
sudo apt-get update
sudo apt-get install -y \
  curl \
  gnupg \
  lsb-release \
  ca-certificates \
  wget \
  sudo

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up Docker's stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Docker Compose plugin
sudo apt-get update
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

# Enable and start Docker service
sudo systemctl enable --now docker

# Install Docker Compose (latest version)
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add current user to Docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Portainer
sudo docker volume create portainer_data
sudo docker run -d \
  -p 9443:9443 \
  --name portainer \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Output completion message
echo "Docker and Portainer have been installed successfully!"
echo "Access Portainer at: https://<your-ip>:9443"
