#!/bin/bash

# Define text colors for clear output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

print_info "This script will:"
echo "1. Add a new user with the specified username."
echo "2. Optionally copy the .ssh folder to the new user's home directory with secure permissions."
echo "3. Optionally add the user to the sudo group."
echo "4. Optionally install Docker (including Docker Compose) via official repositories and grant user access."

read -p "Do you want to continue? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  print_info "Exiting the script. No changes were made."
  exit 0
fi

# Gather user inputs upfront
read -p "Enter the username you want to create: " username
read -p "Do you want to copy the current .ssh folder to the new user's home directory? (y/n): " copy_ssh
read -p "Do you want to add user '$username' to the sudo group? (y/n): " add_sudo
read -p "Do you want to install Docker & Docker Compose? (y/n): " install_docker

# 1. Add User
print_info "Adding user '$username'"
adduser --gecos "" "$username"

# 2. Copy .ssh folder and set secure permissions
if [[ "$copy_ssh" == "y" ]]; then
  if [ -d "$HOME/.ssh" ]; then
    print_info "Copying .ssh folder to /home/$username/"
    cp -r "$HOME/.ssh" "/home/$username/"
    chown -R "$username:$username" "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    find "/home/$username/.ssh" -type f -exec chmod 600 {} +
    find "/home/$username/.ssh" -type f -name "*.pub" -exec chmod 644 {} +
  else
    print_warning "Source directory $HOME/.ssh does not exist. Skipping SSH copy."
  fi
else
  print_info ".ssh folder will not be copied."
fi

# 3. Add to sudo group
if [[ "$add_sudo" == "y" ]]; then
  print_info "Adding user '$username' to the sudo group"
  usermod -aG sudo "$username" 2>/dev/null || usermod -aG wheel "$username"
else
  print_info "User '$username' will not be added to the sudo group."
fi

# 4. Install Docker via Auto-Detected OS Repositories
if [[ "$install_docker" == "y" ]]; then
  print_info "Detecting Operating System..."

  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    VERSION_CODENAME=${VERSION_CODENAME:-$UBUNTU_CODENAME}
  else
    print_error "Cannot detect operating system via /etc/os-release."
    exit 1
  fi

  case "$OS_ID" in
    ubuntu|debian)
      print_info "Setting up official Docker repository for $OS_ID ($VERSION_CODENAME)"
      apt update
      apt install -y ca-certificates curl gnupg

      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg

      echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS_ID \
        $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

      apt update
      apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;

    fedora)
      print_info "Setting up official Docker repository for Fedora"
      dnf install -y dnf-plugins-core
      dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;

    rhel|rocky|almalinux)
      print_info "Setting up official Docker repository for $NAME"
      dnf install -y dnf-plugins-core
      dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      ;;

    *)
      print_error "Unsupported operating system: $OS_ID"
      exit 1
      ;;
  esac

  print_info "Starting and enabling Docker service"
  systemctl start docker
  systemctl enable docker

  print_info "Adding user '$username' to the docker group"
  usermod -aG docker "$username"
else
  print_info "Skipping Docker installation"
fi

print_info "Setup Complete"
print_warning "It is recommended to log out and back in (or reboot) for group permissions to take effect."
