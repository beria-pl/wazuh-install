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

# Function to install Docker and Docker Compose
install_docker() {
    echo -e "${YELLOW}Installing Docker and Docker Compose...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    echo -e "${GREEN}Docker installed successfully.${NC}"

    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose installed successfully.${NC}"
}

# Function to get the latest stable Wazuh release
get_latest_wazuh_release() {
    echo -e "${YELLOW}Fetching latest stable Wazuh release...${NC}"
    LATEST_WAZUH_TAG=$(curl -s https://api.github.com/repos/wazuh/wazuh-docker/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    echo -e "${GREEN}Latest Wazuh release: ${LATEST_WAZUH_TAG}${NC}"
}

# Function to deploy Wazuh in a single-node setup
deploy_wazuh() {
    echo -e "${YELLOW}Deploying Wazuh (Single Node)...${NC}"
    mkdir -p ~/wazuh && cd ~/wazuh
    get_latest_wazuh_release
    
    # Create a single-node Docker Compose configuration
    cat <<EOF > docker-compose.yml
version: "3.7"
services:
  wazuh:
    image: wazuh/wazuh-manager:${LATEST_WAZUH_TAG}
    container_name: wazuh-manager
    restart: always
    ports:
      - "1514:1514/udp"
      - "55000:55000/tcp"
    volumes:
      - wazuh-logs:/var/ossec/logs
      - wazuh-etc:/var/ossec/etc
      - wazuh-queue:/var/ossec/queue
      - wazuh-agentless:/var/ossec/agentless
      - wazuh-integrations:/var/ossec/integrations
      - wazuh-active-response:/var/ossec/active-response
volumes:
  wazuh-logs:
  wazuh-etc:
  wazuh-queue:
  wazuh-agentless:
  wazuh-integrations:
  wazuh-active-response:
EOF

    docker-compose up -d
    echo -e "${GREEN}Wazuh single-node deployment completed.${NC}"
}

# Function to configure PfSense logging
configure_pfsense() {
    echo -e "${YELLOW}Configuring PfSense log forwarding...${NC}"
    echo "Follow these steps to configure PfSense to send logs to Wazuh:" > ~/wazuh/pfsense_setup.txt
    echo "1. Log into PfSense Web UI." >> ~/wazuh/pfsense_setup.txt
    echo "2. Navigate to Status > System Logs > Settings." >> ~/wazuh/pfsense_setup.txt
    echo "3. Enable 'Remote Logging' and set Remote Syslog Server to the Wazuh Manager IP." >> ~/wazuh/pfsense_setup.txt
    echo "4. Use UDP port 1514 for Syslog (ensure Wazuh container listens on this port)." >> ~/wazuh/pfsense_setup.txt
    echo "5. Save the settings and restart logging services." >> ~/wazuh/pfsense_setup.txt
    echo -e "${GREEN}PfSense setup instructions saved to ~/wazuh/pfsense_setup.txt${NC}"
}

# Function to verify Wazuh is running
verify_wazuh() {
    echo -e "${YELLOW}Verifying Wazuh deployment...${NC}"
    if docker ps | grep -q wazuh-manager; then
        echo -e "${GREEN}Wazuh is running successfully.${NC}"
    else
        echo -e "${RED}Wazuh deployment failed. Check logs using 'docker-compose logs'.${NC}"
        exit 1
    fi
}

# Main execution
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
configure_pfsense
verify_wazuh

echo -e "${GREEN}Wazuh single-node setup completed successfully!${NC}"
