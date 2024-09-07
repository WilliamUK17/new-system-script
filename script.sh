#!/bin/bash

# Define text colors for nice output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print sections with formatting
print_info() {
  echo -e "${GREEN}===== $1 =====${NC}"
}

print_warning() {
  echo -e "${YELLOW}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  print_error "Please run this script as root or with sudo."
  exit 1
fi

# Get system architecture
ARCH=$(uname -m)
print_info "Checking system architecture: $ARCH"

# Check if the architecture is supported
if [[ "$ARCH" != "x86_64" && "$ARCH" != "arm64" ]]; then
  print_error "Unsupported architecture: $ARCH. Only x86_64 and arm64 are supported."
  exit 1
fi

# Update and upgrade the system
print_info "Updating and upgrading the system"
apt update && apt upgrade -y

# Ask for the username
print_info "User Creation"
read -p "Enter the username you want to create: " username

# Add the new user
print_info "Adding user '$username'"
adduser "$username"

# Copy the .ssh folder to the new user's home directory
print_info "Copying .ssh folder to /home/$username/"
cp -r ~/.ssh /home/"$username"/

# Give ownership of the .ssh folder and its contents to the new user
print_info "Changing ownership of .ssh to user '$username'"
chown -R "$username":"$username" /home/"$username"/.ssh

# Add the user to the sudo group
print_info "Adding user '$username' to the sudo group"
usermod -aG sudo "$username"

# Install prerequisites for Docker
print_info "Installing prerequisites for Docker"
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker’s official GPG key
print_info "Adding Docker's GPG key"
mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up Docker repository based on architecture
print_info "Setting up Docker repository"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update the package index and install Docker
print_info "Updating package index and installing Docker"
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Docker Compose (standalone) based on architecture
print_info "Installing the latest Docker Compose"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-${ARCH}"
curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose

# Apply executable permissions to the Docker Compose binary
print_info "Applying executable permissions to Docker Compose"
chmod +x /usr/local/bin/docker-compose

# Add the new user to the docker group
print_info "Adding user '$username' to the docker group"
usermod -aG docker "$username"

# Restart Docker service to apply group changes
print_info "Restarting Docker service"
systemctl restart docker

# Confirm installations
print_info "Checking Docker and Docker Compose versions"
docker --version
docker-compose --version

print_info "Setup Complete"
echo -e "${GREEN}User $username has been created, added to sudo and docker groups, and Docker + Docker Compose installed.${NC}"
