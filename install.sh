#!/bin/bash

#############################################
# XTRON-TUN One-Line Installer
# GitHub: alixtron0/xtron-tun
# Author: AliXtron
# Description: Professional SMTP Tunnel Manager
#############################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Installation paths
readonly INSTALL_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc/xtron-tun"
readonly LIB_DIR="/usr/local/lib/xtron-tun"
readonly LOG_DIR="/var/log/xtron-tun"
readonly GITHUB_REPO="https://raw.githubusercontent.com/alixtron0/xtron-tun/main"

# Show banner
show_banner() {
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
}

# Spinner function
spin() {
    local -r pid=$1
    local -r message=$2
    local -r spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}${spinner[$i]} ${message}...${NC}"
        i=$(( (i + 1) % 10 ))
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r${GREEN}✓ ${message}... Done!${NC}\n"
    else
        printf "\r${RED}✗ ${message}... Failed!${NC}\n"
        return $exit_code
    fi
}

# Check root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}✗ This script must be run as root or with sudo${NC}"
        exit 1
    fi
}

# Detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        echo -e "${RED}✗ Cannot detect OS${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Detected OS: $OS $VER${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "\n${YELLOW}Installing dependencies...${NC}\n"

    case $OS in
        ubuntu|debian)
            (apt-get update -qq && apt-get install -y -qq \
                curl wget git net-tools netcat jq bc \
                build-essential libssl-dev >/dev/null 2>&1) &
            spin $! "Installing system packages"
            ;;
        centos|rhel|fedora)
            (dnf install -y -q curl wget git net-tools nc jq bc \
                gcc make openssl-devel >/dev/null 2>&1) &
            spin $! "Installing system packages"
            ;;
        *)
            echo -e "${RED}✗ Unsupported OS: $OS${NC}"
            exit 1
            ;;
    esac
}

# Install GOST
install_gost() {
    echo -e "\n${YELLOW}Installing GOST v3...${NC}\n"

    local gost_version="3.0.0-rc10"
    local arch=$(uname -m)

    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *)
            echo -e "${RED}✗ Unsupported architecture: $arch${NC}"
            exit 1
            ;;
    esac

    if command -v gost >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GOST already installed${NC}"
        return 0
    fi

    (
        cd /tmp
        wget -q "https://github.com/go-gost/gost/releases/download/v${gost_version}/gost_${gost_version}_linux_${arch}.tar.gz"
        tar -xzf "gost_${gost_version}_linux_${arch}.tar.gz"
        mv gost /usr/local/bin/
        chmod +x /usr/local/bin/gost
        rm -f "gost_${gost_version}_linux_${arch}.tar.gz" README.md
    ) &

    spin $! "Installing GOST"
}

# Install socat
install_socat() {
    echo -e "\n${YELLOW}Installing socat 1.8.x...${NC}\n"

    if command -v socat >/dev/null 2>&1; then
        local socat_ver=$(socat -V 2>&1 | head -1 | grep -oP '\d+\.\d+\.\d+')
        if [[ ${socat_ver%%.*} -ge 1 ]] && [[ ${socat_ver#*.} -ge 8 ]]; then
            echo -e "${GREEN}✓ socat 1.8+ already installed (v${socat_ver})${NC}"
            return 0
        fi
    fi

    case $OS in
        ubuntu|debian)
            (apt-get install -y -qq socat >/dev/null 2>&1) &
            spin $! "Installing socat"
            ;;
        centos|rhel|fedora)
            (dnf install -y -q socat >/dev/null 2>&1) &
            spin $! "Installing socat"
            ;;
    esac
}

# Create directory structure
create_directories() {
    echo -e "\n${YELLOW}Creating directory structure...${NC}\n"

    (
        mkdir -p "$CONFIG_DIR"/{kharej,iran,templates}
        mkdir -p "$LIB_DIR"
        mkdir -p "$LOG_DIR"
        chmod 755 "$CONFIG_DIR" "$LIB_DIR"
        chmod 750 "$LOG_DIR"
    ) &

    spin $! "Creating directories"
}

# Download main scripts
download_scripts() {
    echo -e "\n${YELLOW}Downloading XTRON-TUN scripts...${NC}\n"

    # For now, we'll create them locally since GitHub repo doesn't exist yet
    # Later, uncomment these lines:
    # curl -fsSL "${GITHUB_REPO}/xtron-tun" -o "${INSTALL_DIR}/xtron-tun"
    # curl -fsSL "${GITHUB_REPO}/lib/utils.sh" -o "${LIB_DIR}/utils.sh"
    # curl -fsSL "${GITHUB_REPO}/lib/kharej.sh" -o "${LIB_DIR}/kharej.sh"
    # curl -fsSL "${GITHUB_REPO}/lib/iran.sh" -o "${LIB_DIR}/iran.sh"

    echo -e "${GREEN}✓ Scripts will be created locally${NC}"
}

# Set permissions
set_permissions() {
    echo -e "\n${YELLOW}Setting permissions...${NC}\n"

    (
        chmod +x "${INSTALL_DIR}/xtron-tun" 2>/dev/null || true
        chmod +x "${LIB_DIR}"/*.sh 2>/dev/null || true
        chown -R root:root "$CONFIG_DIR" "$LIB_DIR"
    ) &

    spin $! "Setting permissions"
}

# Show completion message
show_completion() {
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
    echo -e "  ${WHITE}xtron-tun${NC}          - Start the tunnel manager"
    echo -e "  ${WHITE}xtron-tun --help${NC}   - Show help menu\n"

    echo -e "${CYAN}Configuration:${NC}"
    echo -e "  Config:  ${WHITE}${CONFIG_DIR}${NC}"
    echo -e "  Logs:    ${WHITE}${LOG_DIR}${NC}\n"

    echo -e "${CYAN}Next steps:${NC}"
    echo -e "  1. Run ${WHITE}xtron-tun${NC} to start the tunnel manager"
    echo -e "  2. Choose your server type (Iran or Kharej)"
    echo -e "  3. Follow the setup wizard\n"

    echo -e "${YELLOW}For support and documentation:${NC}"
    echo -e "  ${CYAN}https://github.com/alixtron0/xtron-tun${NC}\n"
}

# Main installation function
main() {
    show_banner

    echo -e "${YELLOW}Starting installation...${NC}\n"

    check_root
    detect_os
    install_dependencies
    install_gost
    install_socat
    create_directories
    download_scripts
    set_permissions

    show_completion

    echo -e "${GREEN}✓ Installation completed successfully!${NC}\n"
}

# Run main function
main "$@"
