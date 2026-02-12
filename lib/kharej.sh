#!/bin/bash

#############################################
# XTRON-TUN Kharej (Foreign Server) Module
# GitHub: alixtron0/xtron-tun
#############################################

# Source utils if available
[[ -f "${LIB_DIR}/utils.sh" ]] && source "${LIB_DIR}/utils.sh"

# Configuration
KHAREJ_CONFIG="${CONFIG_DIR}/kharej"
KHAREJ_LOG="${LOG_DIR}/kharej.log"

# Log function
log_kharej() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$KHAREJ_LOG"
}

# Show Kharej main menu
kharej_main() {
    while true; do
        clear
        show_banner
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                  ${WHITE}Foreign Server (Kharej)${NC}                 ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}1${NC} • ${WHITE}Setup New Tunnel${NC}                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Create SOCKS5 proxy and SMTP tunnel                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}2${NC} • ${WHITE}Manage Tunnels${NC}                                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      View status, Add/Remove user, Ping Test             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}3${NC} • ${WHITE}Export Configuration${NC}                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Generate ZIP file for Iran server                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}4${NC} • ${WHITE}Show Logs${NC}                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}5${NC} • ${WHITE}Delete Tunnel${NC}                                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Complete tunnel removal and cleanup                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}0${NC} • ${WHITE}Back${NC}                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"

        read -p "$(echo -e "\n${WHITE}Your choice: ${NC}")" choice

        case $choice in
            1) setup_new_tunnel ;;
            2) manage_tunnels ;;
            3) export_config ;;
            4) show_kharej_logs ;;
            5) delete_tunnel ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
        esac
    done
}

# Setup new tunnel
setup_new_tunnel() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}Setup New Tunnel${NC}                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # Get tunnel name
    read -p "$(echo -e "${WHITE}Tunnel name (example: smtp-tunnel-1): ${NC}")" tunnel_name
    tunnel_name=${tunnel_name:-smtp-tunnel-1}

    # Get SMTP server details
    read -p "$(echo -e "${WHITE}SMTP server address (example: smtp.example.com): ${NC}")" smtp_server
    if [[ -z "$smtp_server" ]]; then
        echo -e "${RED}Server address is required!${NC}"
        sleep 2
        return
    fi

    # Get SMTP ports
    read -p "$(echo -e "${WHITE}First SMTP port (default: 25): ${NC}")" smtp_port1
    smtp_port1=${smtp_port1:-25}

    read -p "$(echo -e "${WHITE}Second SMTP port (default: 587): ${NC}")" smtp_port2
    smtp_port2=${smtp_port2:-587}

    # Get SOCKS5 port
    read -p "$(echo -e "${WHITE}SOCKS5 port (default: 1080): ${NC}")" socks_port
    socks_port=${socks_port:-1080}

    # Get authentication
    read -p "$(echo -e "${WHITE}SOCKS5 username (empty = no authentication): ${NC}")" socks_user
    if [[ -n "$socks_user" ]]; then
        read -sp "$(echo -e "${WHITE}SOCKS5 password: ${NC}")" socks_pass
        echo
    fi

    echo -e "\n${YELLOW}Configuring tunnel...${NC}\n"

    # Create tunnel directory
    mkdir -p "${KHAREJ_CONFIG}/${tunnel_name}"

    # Resolve SMTP server IP
    echo -e "${CYAN}• Resolving SMTP server IP...${NC}"
    smtp_ip=$(dig +short "$smtp_server" | tail -1)
    if [[ -z "$smtp_ip" ]]; then
        echo -e "${RED}Error: Cannot resolve server IP${NC}"
        log_kharej "ERROR: Failed to resolve $smtp_server"
        sleep 2
        return
    fi
    echo -e "${GREEN}✓ Server IP: ${smtp_ip}${NC}"

    # Configure GOST
    echo -e "\n${CYAN}• Configuring GOST...${NC}"

    local gost_config="${KHAREJ_CONFIG}/${tunnel_name}/gost-config.yaml"

    cat > "$gost_config" << EOF
services:
  - name: socks5-proxy
    addr: :${socks_port}
    handler:
      type: socks5
EOF

    # Add authentication if provided
    if [[ -n "$socks_user" ]]; then
        cat >> "$gost_config" << EOF
      auth:
        username: ${socks_user}
        password: ${socks_pass}
EOF
    fi

    cat >> "$gost_config" << EOF
    listener:
      type: tcp
EOF

    # Create systemd service
    echo -e "${CYAN}• Creating systemd service...${NC}"

    cat > "/etc/systemd/system/xtron-${tunnel_name}.service" << EOF
[Unit]
Description=XTRON SOCKS5 Tunnel - ${tunnel_name}
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/gost -C ${gost_config}
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/${tunnel_name}.log
StandardError=append:${LOG_DIR}/${tunnel_name}.log

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable "xtron-${tunnel_name}.service" >/dev/null 2>&1
    systemctl start "xtron-${tunnel_name}.service"

    sleep 2

    if systemctl is-active --quiet "xtron-${tunnel_name}.service"; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Error starting service${NC}"
        log_kharej "ERROR: Failed to start service xtron-${tunnel_name}"
        sleep 2
        return
    fi

    # Configure firewall
    echo -e "\n${CYAN}• Configuring firewall...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${socks_port}/tcp >/dev/null 2>&1
        echo -e "${GREEN}✓ Port ${socks_port} opened in firewall${NC}"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${socks_port}/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        echo -e "${GREEN}✓ Port ${socks_port} opened in firewall${NC}"
    fi

    # Save tunnel info
    cat > "${KHAREJ_CONFIG}/${tunnel_name}/info.conf" << EOF
TUNNEL_NAME=${tunnel_name}
SMTP_SERVER=${smtp_server}
SMTP_IP=${smtp_ip}
SMTP_PORT1=${smtp_port1}
SMTP_PORT2=${smtp_port2}
SOCKS_PORT=${socks_port}
SOCKS_USER=${socks_user}
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    # Get server public IP
    server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "N/A")

    # Show success message
    echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}             ${WHITE}Tunnel setup successful!${NC}                    ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${WHITE}Tunnel Information:${NC}"
    echo -e "  Tunnel Name:    ${CYAN}${tunnel_name}${NC}"
    echo -e "  SMTP Server:    ${CYAN}${smtp_server} (${smtp_ip})${NC}"
    echo -e "  SMTP Ports:     ${CYAN}${smtp_port1}, ${smtp_port2}${NC}"
    echo -e "  SOCKS5 Proxy:   ${CYAN}${server_ip}:${socks_port}${NC}"
    if [[ -n "$socks_user" ]]; then
        echo -e "  Authentication: ${CYAN}${socks_user} / ${socks_pass}${NC}"
    fi

    echo -e "\n${YELLOW}To setup Iran server, use 'Export Configuration' option.${NC}\n"

    log_kharej "SUCCESS: Tunnel ${tunnel_name} created successfully"

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}

# Manage tunnels
manage_tunnels() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                  ${WHITE}Manage Tunnels${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # List all tunnels
    if [[ ! -d "$KHAREJ_CONFIG" ]] || [[ -z "$(ls -A "$KHAREJ_CONFIG" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No tunnels found!${NC}\n"
        read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
        return
    fi

    local tunnels=($(ls -1 "$KHAREJ_CONFIG"))
    local i=1

    echo -e "${WHITE}Available Tunnels:${NC}\n"

    for tunnel in "${tunnels[@]}"; do
        if [[ -f "${KHAREJ_CONFIG}/${tunnel}/info.conf" ]]; then
            source "${KHAREJ_CONFIG}/${tunnel}/info.conf"

            local status="❌ Inactive"
            local status_color="${RED}"

            if systemctl is-active --quiet "xtron-${tunnel}.service"; then
                status="✅ Active"
                status_color="${GREEN}"
            fi

            echo -e "  ${CYAN}${i}.${NC} ${WHITE}${tunnel}${NC}"
            echo -e "     Status: ${status_color}${status}${NC}"
            echo -e "     SMTP: ${CYAN}${SMTP_SERVER}:${SMTP_PORT1},${SMTP_PORT2}${NC}"
            echo -e "     SOCKS5: ${CYAN}:${SOCKS_PORT}${NC}"
            echo -e ""

            ((i++))
        fi
    done

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}1${NC} • Start/Stop Tunnel                                   ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}2${NC} • Show Tunnel Details                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}3${NC} • Ping Test                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}0${NC} • Back                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"

    read -p "$(echo -e "\n${WHITE}Your choice: ${NC}")" choice

    case $choice in
        1) toggle_tunnel_service "${tunnels[@]}" ;;
        2) show_tunnel_details "${tunnels[@]}" ;;
        3) ping_test ;;
        0) return ;;
    esac
}

# Toggle tunnel service
toggle_tunnel_service() {
    local tunnels=("$@")

    read -p "$(echo -e "${WHITE}Tunnel number: ${NC}")" tunnel_num

    if [[ $tunnel_num -gt 0 ]] && [[ $tunnel_num -le ${#tunnels[@]} ]]; then
        local tunnel="${tunnels[$((tunnel_num-1))]}"

        if systemctl is-active --quiet "xtron-${tunnel}.service"; then
            systemctl stop "xtron-${tunnel}.service"
            echo -e "${YELLOW}Tunnel ${tunnel} stopped${NC}"
        else
            systemctl start "xtron-${tunnel}.service"
            echo -e "${GREEN}Tunnel ${tunnel} started${NC}"
        fi
    fi

    sleep 2
}

# Show tunnel details
show_tunnel_details() {
    local tunnels=("$@")

    read -p "$(echo -e "${WHITE}Tunnel number: ${NC}")" tunnel_num

    if [[ $tunnel_num -gt 0 ]] && [[ $tunnel_num -le ${#tunnels[@]} ]]; then
        local tunnel="${tunnels[$((tunnel_num-1))]}"

        clear
        show_banner
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}              ${WHITE}Tunnel Details: ${tunnel}${NC}                ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

        if [[ -f "${KHAREJ_CONFIG}/${tunnel}/info.conf" ]]; then
            source "${KHAREJ_CONFIG}/${tunnel}/info.conf"

            echo -e "${WHITE}Basic Information:${NC}"
            echo -e "  Tunnel Name:    ${CYAN}${TUNNEL_NAME}${NC}"
            echo -e "  Created At:     ${CYAN}${CREATED_AT}${NC}"
            echo -e "  SMTP Server:    ${CYAN}${SMTP_SERVER} (${SMTP_IP})${NC}"
            echo -e "  SMTP Ports:     ${CYAN}${SMTP_PORT1}, ${SMTP_PORT2}${NC}"
            echo -e "  SOCKS5 Port:    ${CYAN}${SOCKS_PORT}${NC}"

            if [[ -n "$SOCKS_USER" ]]; then
                echo -e "  Username:       ${CYAN}${SOCKS_USER}${NC}"
            fi

            echo -e "\n${WHITE}Service Status:${NC}"
            systemctl status "xtron-${tunnel}.service" --no-pager | head -10
        fi
    fi

    echo -e ""
    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Ping test
ping_test() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}Ping Test${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    read -p "$(echo -e "${WHITE}Target address for Ping (example: 8.8.8.8): ${NC}")" target
    target=${target:-8.8.8.8}

    echo -e "\n${CYAN}Pinging ${target}...${NC}\n"
    ping -c 4 "$target"

    echo -e ""
    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Export configuration
export_config() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${WHITE}Export Configuration${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # List tunnels
    if [[ ! -d "$KHAREJ_CONFIG" ]] || [[ -z "$(ls -A "$KHAREJ_CONFIG" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No tunnels found for export!${NC}\n"
        read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
        return
    fi

    local tunnels=($(ls -1 "$KHAREJ_CONFIG"))
    local i=1

    echo -e "${WHITE}Select tunnel for export:${NC}\n"

    for tunnel in "${tunnels[@]}"; do
        echo -e "  ${CYAN}${i}.${NC} ${WHITE}${tunnel}${NC}"
        ((i++))
    done

    echo -e ""
    read -p "$(echo -e "${WHITE}Tunnel number: ${NC}")" tunnel_num

    if [[ $tunnel_num -gt 0 ]] && [[ $tunnel_num -le ${#tunnels[@]} ]]; then
        local tunnel="${tunnels[$((tunnel_num-1))]}"

        echo -e "\n${CYAN}Creating ZIP file...${NC}\n"

        local export_dir="/tmp/xtron-export-${tunnel}"
        local zip_file="/tmp/xtron-${tunnel}-config.zip"

        rm -rf "$export_dir" "$zip_file"
        mkdir -p "$export_dir"

        # Copy configuration
        cp -r "${KHAREJ_CONFIG}/${tunnel}"/* "$export_dir/"

        # Get server IP
        local server_ip=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "UNKNOWN")

        # Create info file for Iran server
        cat > "${export_dir}/server-info.txt" << EOF
XTRON-TUN Configuration Export
================================
Tunnel Name: ${tunnel}
Server IP: ${server_ip}
Export Date: $(date '+%Y-%m-%d %H:%M:%S')

This file contains tunnel configuration for Iran server.
Extract the ZIP file on Iran server and use 'Setup Tunnel' option.
EOF

        # Create ZIP
        (cd /tmp && zip -r "xtron-${tunnel}-config.zip" "xtron-export-${tunnel}" >/dev/null 2>&1)

        if [[ -f "$zip_file" ]]; then
            echo -e "${GREEN}✓ ZIP file created successfully${NC}\n"
            echo -e "${WHITE}File path:${NC}"
            echo -e "  ${CYAN}${zip_file}${NC}\n"
            echo -e "${YELLOW}Transfer this file to Iran server.${NC}\n"

            log_kharej "SUCCESS: Config exported for tunnel ${tunnel}"
        else
            echo -e "${RED}✗ Error creating ZIP file${NC}\n"
            log_kharej "ERROR: Failed to export config for tunnel ${tunnel}"
        fi

        # Cleanup
        rm -rf "$export_dir"
    fi

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}

# Show Kharej logs
show_kharej_logs() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}Logs${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    if [[ -f "$KHAREJ_LOG" ]]; then
        echo -e "${WHITE}Recent logs:${NC}\n"
        tail -n 50 "$KHAREJ_LOG"
    else
        echo -e "${YELLOW}No logs found${NC}"
    fi

    echo -e ""
    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Delete tunnel
delete_tunnel() {
    clear
    show_banner
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                  ${WHITE}Delete Tunnel${NC}                            ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # List tunnels
    if [[ ! -d "$KHAREJ_CONFIG" ]] || [[ -z "$(ls -A "$KHAREJ_CONFIG" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No tunnels found for deletion!${NC}\n"
        read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
        return
    fi

    local tunnels=($(ls -1 "$KHAREJ_CONFIG"))
    local i=1

    echo -e "${WHITE}Select tunnel for deletion:${NC}\n"

    for tunnel in "${tunnels[@]}"; do
        echo -e "  ${CYAN}${i}.${NC} ${WHITE}${tunnel}${NC}"
        ((i++))
    done

    echo -e ""
    read -p "$(echo -e "${WHITE}Tunnel number: ${NC}")" tunnel_num

    if [[ $tunnel_num -gt 0 ]] && [[ $tunnel_num -le ${#tunnels[@]} ]]; then
        local tunnel="${tunnels[$((tunnel_num-1))]}"

        echo -e "\n${RED}⚠️  Warning: This operation is irreversible!${NC}"
        read -p "$(echo -e "${WHITE}Are you sure? (yes/no): ${NC}")" confirm

        if [[ "$confirm" == "yes" ]]; then
            echo -e "\n${YELLOW}Deleting tunnel ${tunnel}...${NC}\n"

            # Stop and disable service
            systemctl stop "xtron-${tunnel}.service" 2>/dev/null
            systemctl disable "xtron-${tunnel}.service" 2>/dev/null
            rm -f "/etc/systemd/system/xtron-${tunnel}.service"
            systemctl daemon-reload

            # Remove configuration
            rm -rf "${KHAREJ_CONFIG}/${tunnel}"

            echo -e "${GREEN}✓ Tunnel ${tunnel} deleted successfully${NC}\n"
            log_kharej "SUCCESS: Tunnel ${tunnel} deleted"
        else
            echo -e "${YELLOW}Operation cancelled${NC}\n"
        fi
    fi

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}
