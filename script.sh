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

# Description of what the script does
print_info "This script will:"
echo "1. Add a new user with the specified username."
echo "2. Optionally copy the .ssh folder to the new user's home directory and set correct permissions."
echo "3. Optionally add the user to the sudo group."
echo "4. Optionally install Docker and Docker Compose."

# Ask the user if they want to continue
read -p "Do you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  print_info "Exiting the script. No changes were made."
  exit 0
fi

# Ask all the questions at the start
read -p "Enter the username you want to create: " username
read -p "Do you want to copy the current .ssh folder to the new user's home directory? (y/n): " copy_ssh
read -p "Do you want to add user '$username' to the sudo group? (y/n): " add_sudo
read -p "Do you want to install Docker? (y/n): " install_docker
if [[ "$install_docker" == "y" ]]; then
  read -p "Do you want to install Docker Compose as well? (y/n): " install_docker_compose
fi

# Add the user
print_info "Adding user '$username' using adduser"
adduser "$username"

# Copy the .ssh folder if requested
if [[ "$copy_ssh" == "y" ]]; then
  print_info "Copying .ssh folder to /home/$username/"
  cp -r ~/.ssh /home/"$username"/
  chown -R "$username":"$username" /home/"$username"/.ssh
else
  print_info ".ssh folder will not be copied."
fi

# Add the user to the sudo group if requested
if [[ "$add_sudo" == "y" ]]; then
  print_info "Adding user '$username' to the sudo group"
  usermod -aG sudo "$username"
else
  print_info "User '$username' will not be added to the sudo group."
fi

# Install Docker if requested
if [[ "$install_docker" == "y" ]]; then
  echo -e "${YELLOW}Please select your operating system:${NC}"
  echo "1. Debian 11 & 12"
  echo "2. Ubuntu 20.04 (Focal)"
  echo "3. Ubuntu 22.04 (Jammy)"
  echo "4. Ubuntu 18.04 (Bionic)"
  echo "5. Fedora"
  echo "6. CentOS 7"
  read -p "Enter the number corresponding to your OS: " os_choice

  # Set up Docker repository and installation based on OS
  case "$os_choice" in
    1)
      print_info "Setting up Docker for Debian 11/12"
      DOCKER_REPO="debian"
      DOCKER_CODENAME="bullseye"
      ;;
    2)
      print_info "Setting up Docker for Ubuntu 20.04 (Focal)"
      DOCKER_REPO="ubuntu"
      DOCKER_CODENAME="focal"
      ;;
    3)
      print_info "Setting up Docker for Ubuntu 22.04 (Jammy)"
      DOCKER_REPO="ubuntu"
      DOCKER_CODENAME="jammy"
      ;;
    4)
      print_info "Setting up Docker for Ubuntu 18.04 (Bionic)"
      DOCKER_REPO="ubuntu"
      DOCKER_CODENAME="bionic"
      ;;
    5)
      print_info "Setting up Docker for Fedora"
      OS_TYPE="fedora"
      ;;
    6)
      print_info "Setting up Docker for CentOS 7"
      OS_TYPE="centos"
      ;;
    *)
      print_error "Invalid choice. Please run the script again and choose a valid option."
      exit 1
      ;;
  esac

  # Docker installation steps for Debian/Ubuntu
  if [[ "$os_choice" -ge 1 && "$os_choice" -le 4 ]]; then
    print_info "Installing Docker for Debian/Ubuntu"
    apt update
    apt install -y \
      ca-certificates \
      curl \
      gnupg \
      lsb-release

    print_info "Adding Docker's official GPG key"
    mkdir -m 0755 -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$DOCKER_REPO/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    print_info "Setting up Docker repository"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DOCKER_REPO \
      $DOCKER_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_info "Installing Docker"
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  elif [[ "$os_choice" == "5" ]]; then
    print_info "Installing Docker for Fedora"
    dnf install -y docker
  elif [[ "$os_choice" == "6" ]]; then
    print_info "Installing Docker for CentOS 7"
    yum install -y docker
  fi

  print_info "Starting and enabling Docker service"
  systemctl start docker
  systemctl enable docker

  # Install Docker Compose if requested
  if [[ "$install_docker_compose" == "y" ]]; then
    print_info "Installing Docker Compose"
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    print_info "Docker Compose installed"
  else
    print_info "Skipping Docker Compose installation"
  fi

  # Add the user to the Docker group
  print_info "Adding user '$username' to the docker group"
  usermod -aG docker "$username"
else
  print_info "Skipping Docker installation"
fi

# Final message
print_info "Setup Complete"
print_warning "It is recommended to reboot the system to ensure all changes take effect."