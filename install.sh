#!/bin/bash

#############################################
# XTRON-TUN Installer
# GitHub: alixtron0/xtron-tun
# Author: AliXtron
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Paths
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/xtron-tun"
LIB_DIR="/usr/local/lib/xtron-tun"
LOG_DIR="/var/log/xtron-tun"

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ██╗  ██╗████████╗██████╗  ██████╗ ███╗   ██╗        ║
║     ╚██╗██╔╝╚══██╔══╝██╔══██╗██╔═══██╗████╗  ██║        ║
║      ╚███╔╝    ██║   ██████╔╝██║   ██║██╔██╗ ██║        ║
║      ██╔██╗    ██║   ██╔══██╗██║   ██║██║╚██╗██║        ║
║     ██╔╝ ██╗   ██║   ██║  ██║╚██████╔╝██║ ╚████║        ║
║     ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝        ║
║                                                           ║
║              Professional SMTP Tunnel Manager            ║
║                      Version 1.0.0                       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo -e "${WHITE}GitHub: ${CYAN}https://github.com/alixtron0/xtron-tun${NC}\n"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}✗ This script must be run as root or with sudo${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting installation...${NC}\n"

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo -e "${RED}✗ Cannot detect OS${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Detected OS: $OS $VER${NC}\n"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
case $OS in
    ubuntu|debian)
        echo -e "${CYAN}→ Updating package list...${NC}"
        apt-get update -qq || true
        echo -e "${CYAN}→ Installing packages...${NC}"
        apt-get install -y -qq curl wget git net-tools netcat jq bc build-essential libssl-dev || true
        ;;
    centos|rhel|fedora)
        echo -e "${CYAN}→ Installing packages...${NC}"
        dnf install -y -q curl wget git net-tools nc jq bc gcc make openssl-devel || true
        ;;
    *)
        echo -e "${RED}✗ Unsupported OS: $OS${NC}"
        exit 1
        ;;
esac
echo -e "${GREEN}✓ Dependencies installed${NC}\n"

# Install GOST
echo -e "${YELLOW}Installing GOST v3...${NC}"
if command -v gost >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GOST already installed${NC}\n"
else
    GOST_VERSION="3.0.0-rc10"
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        *)
            echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
            exit 1
            ;;
    esac

    echo -e "${CYAN}→ Downloading GOST...${NC}"
    cd /tmp
    wget -q "https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/gost_${GOST_VERSION}_linux_${ARCH}.tar.gz" || {
        echo -e "${RED}✗ Failed to download GOST${NC}"
        exit 1
    }

    echo -e "${CYAN}→ Extracting GOST...${NC}"
    tar -xzf "gost_${GOST_VERSION}_linux_${ARCH}.tar.gz"
    mv gost /usr/local/bin/
    chmod +x /usr/local/bin/gost
    rm -f "gost_${GOST_VERSION}_linux_${ARCH}.tar.gz" README.md

    echo -e "${GREEN}✓ GOST installed${NC}\n"
fi

# Install socat
echo -e "${YELLOW}Installing socat...${NC}"
if command -v socat >/dev/null 2>&1; then
    echo -e "${GREEN}✓ socat already installed${NC}\n"
else
    case $OS in
        ubuntu|debian)
            apt-get install -y -qq socat || true
            ;;
        centos|rhel|fedora)
            dnf install -y -q socat || true
            ;;
    esac
    echo -e "${GREEN}✓ socat installed${NC}\n"
fi

# Create directories
echo -e "${YELLOW}Creating directory structure...${NC}"
mkdir -p "$CONFIG_DIR"/{kharej,iran,templates}
mkdir -p "$LIB_DIR"
mkdir -p "$LOG_DIR"
chmod 755 "$CONFIG_DIR" "$LIB_DIR"
chmod 750 "$LOG_DIR"
echo -e "${GREEN}✓ Directories created${NC}\n"

# Copy main script
echo -e "${YELLOW}Installing xtron-tun script...${NC}"
if [[ -f "./xtron-tun" ]]; then
    cp ./xtron-tun "$INSTALL_DIR/xtron-tun"
    chmod +x "$INSTALL_DIR/xtron-tun"
    echo -e "${GREEN}✓ xtron-tun installed to $INSTALL_DIR${NC}\n"
else
    echo -e "${YELLOW}⚠ xtron-tun script not found in current directory${NC}"
    echo -e "${YELLOW}  You can copy it manually later to $INSTALL_DIR/xtron-tun${NC}\n"
fi

# Copy lib files if they exist
if [[ -d "./lib" ]]; then
    echo -e "${YELLOW}Installing library files...${NC}"
    cp -r ./lib/* "$LIB_DIR/" 2>/dev/null || true
    chmod +x "$LIB_DIR"/*.sh 2>/dev/null || true
    echo -e "${GREEN}✓ Library files installed${NC}\n"
fi

# Set ownership
chown -R root:root "$CONFIG_DIR" "$LIB_DIR" 2>/dev/null || true

# Success
echo -e "\n${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✓ Installation Completed!                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${WHITE}XTRON-TUN has been successfully installed!${NC}\n"
echo -e "${CYAN}Usage:${NC}"
echo -e "  ${WHITE}sudo xtron-tun${NC}          - Start the tunnel manager\n"

echo -e "${CYAN}Configuration:${NC}"
echo -e "  Config:  ${WHITE}${CONFIG_DIR}${NC}"
echo -e "  Logs:    ${WHITE}${LOG_DIR}${NC}\n"

echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Run ${WHITE}sudo xtron-tun${NC} to start"
echo -e "  2. Choose your server type (Iran or Kharej)"
echo -e "  3. Follow the setup wizard\n"

echo -e "${GREEN}✓ Installation completed successfully!${NC}\n"
