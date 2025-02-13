#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Colors for output
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
NC="\e[0m"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Function to check Docker version
check_docker_version() {
    if command_exists docker; then
        if ! command_exists jq; then
            echo -e "${YELLOW}jq is not installed. Installing jq...${NC}"
            sudo apt-get install -y jq
        fi
        INSTALLED_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        LATEST_VERSION=$(curl -sL https://api.github.com/repos/docker/docker-ce/releases/latest | jq -r '.tag_name')
        echo -e "${GREEN}Your Docker version: ${INSTALLED_VERSION}${NC}"
        echo -e "${YELLOW}Latest available Docker version: ${LATEST_VERSION}${NC}"
    else
        echo -e "${RED}Docker is not installed.${NC}"
    fi
}

# Function to install Docker and Docker Compose
install_docker() {
    echo -e "${YELLOW}Installing Docker and Docker Compose...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed successfully.${NC}"

    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose installed successfully.${NC}"
}

# Function to set system parameters for Wazuh
configure_system() {
    echo -e "${YELLOW}Configuring system parameters for Wazuh...${NC}"
    sudo sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    echo -e "${GREEN}System parameters configured.${NC}"
}

# Function to check and set Docker memory allocation
check_docker_memory() {
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 6]; then
        echo -e "${RED}Warning: Your system has less than 6GB of RAM. Wazuh may not perform optimally.${NC}"
    else
        echo -e "${GREEN}Your system has sufficient RAM (${TOTAL_MEM}GB) for Wazuh.${NC}"
    fi
}

# Function to get the latest Wazuh Docker image tag
get_latest_wazuh_version() {
    LATEST_VERSION=$(curl -s https://api.github.com/repos/wazuh/wazuh-docker/releases/latest | jq -r '.tag_name')
    echo -e "${GREEN}Latest Wazuh Docker image tag: ${LATEST_VERSION}${NC}"
}

# Function to clone the Wazuh Docker repository and set up a single-node deployment
deploy_wazuh() {
    get_latest_wazuh_version
    echo -e "${YELLOW}Cloning Wazuh Docker repository...${NC}"
    git clone https://github.com/wazuh/wazuh-docker.git -b ${LATEST_VERSION}
    cd wazuh-docker/single-node

    # Update the Docker image tag version
    sed -i "s/wazuh\/wazuh:[0-9]*\.[0-9]*\.[0-9]*/wazuh\/wazuh:${LATEST_VERSION}/g" docker-compose.yml

    # Generate SSL certificates
    echo -e "${YELLOW}Generating SSL certificates for Wazuh Indexer...${NC}"
    docker-compose -f generate-indexer-certs.yml run --rm generator
    echo -e "${GREEN}Certificates generated and saved in /opt/wazuh/config/wazuh_indexer_ssl_certs.${NC}"

    echo -e "${YELLOW}Deploying Wazuh (Single Node)...${NC}"
    docker-compose up -d
    echo -e "${GREEN}Wazuh single-node deployment completed.${NC}"
}

# Main execution
check_docker_version
check_docker_memory
configure_system

if ! command_exists docker; then
    install_docker
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

if ! command_exists docker-compose; then
    install_docker
else
    echo -e "${GREEN}Docker Compose is already installed.${NC}"
fi

deploy_wazuh

echo -e "${GREEN}Wazuh single-node setup completed successfully!${NC}"
