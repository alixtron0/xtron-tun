#!/bin/bash

#############################################
# XTRON-TUN Iran Server Module
# GitHub: alixtron0/xtron-tun
#############################################

# Source utils if available
[[ -f "${LIB_DIR}/utils.sh" ]] && source "${LIB_DIR}/utils.sh"

# Configuration
IRAN_CONFIG="${CONFIG_DIR}/iran"
IRAN_LOG="${LOG_DIR}/iran.log"

# Log function
log_iran() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$IRAN_LOG"
}

# Show Iran main menu
iran_main() {
    while true; do
        clear
        show_banner
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                  ${WHITE}Iran Server${NC}                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}1${NC} • ${WHITE}Setup Tunnel${NC}                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Connect to foreign server with ZIP file              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}2${NC} • ${WHITE}Port Forward${NC}                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Define and manage Port Forwarding                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}3${NC} • ${WHITE}Manage Tunnels${NC}                                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      View status, Ping Test, Management                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}4${NC} • ${WHITE}Show Logs${NC}                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}5${NC} • ${WHITE}Delete and Cleanup${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Complete tunnel removal and cleanup                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}0${NC} • ${WHITE}Back${NC}                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"

        read -p "$(echo -e "\n${WHITE}Your choice: ${NC}")" choice

        case $choice in
            1) setup_iran_tunnel ;;
            2) port_forward_menu ;;
            3) manage_iran_tunnels ;;
            4) show_iran_logs ;;
            5) delete_iran_tunnel ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
        esac
    done
}

# Setup Iran tunnel
setup_iran_tunnel() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${WHITE}Setup Tunnel${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${WHITE}Two methods for tunnel setup:${NC}\n"
    echo -e "  ${GREEN}1${NC} • Use ZIP file (exported from foreign server)"
    echo -e "  ${GREEN}2${NC} • Manual configuration (enter information manually)\n"

    read -p "$(echo -e "${WHITE}Your choice: ${NC}")" method

    case $method in
        1) setup_from_zip ;;
        2) setup_manual ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 2; return ;;
    esac
}

# Setup from ZIP file
setup_from_zip() {
    echo -e "\n${CYAN}Setup from ZIP file${NC}\n"

    read -p "$(echo -e "${WHITE}ZIP file path: ${NC}")" zip_path

    if [[ ! -f "$zip_path" ]]; then
        echo -e "${RED}✗ File not found: ${zip_path}${NC}"
        sleep 2
        return
    fi

    echo -e "\n${YELLOW}Extracting ZIP file...${NC}"

    local tunnel_name=$(basename "$zip_path" .zip | sed 's/xtron-//' | sed 's/-config//')
    local extract_dir="${IRAN_CONFIG}/${tunnel_name}"

    mkdir -p "$extract_dir"
    unzip -q "$zip_path" -d /tmp/

    local extracted_folder=$(ls -1d /tmp/xtron-export-* 2>/dev/null | head -1)

    if [[ -z "$extracted_folder" ]]; then
        echo -e "${RED}✗ Error extracting file${NC}"
        sleep 2
        return
    fi

    cp -r "$extracted_folder"/* "$extract_dir/"
    rm -rf "$extracted_folder"

    # Load configuration
    if [[ -f "${extract_dir}/info.conf" ]]; then
        source "${extract_dir}/info.conf"

        echo -e "${GREEN}✓ Configuration loaded successfully${NC}\n"

        echo -e "${WHITE}Tunnel Information:${NC}"
        echo -e "  Name: ${CYAN}${TUNNEL_NAME}${NC}"
        echo -e "  SMTP Server: ${CYAN}${SMTP_SERVER}${NC}"
        echo -e "  SOCKS5 Port: ${CYAN}${SOCKS_PORT}${NC}"

        # Ask for server IP
        read -p "$(echo -e "\n${WHITE}Foreign server IP: ${NC}")" kharej_ip

        # Save Iran-specific config
        cat > "${extract_dir}/iran-config.conf" << EOF
TUNNEL_NAME=${TUNNEL_NAME}
KHAREJ_IP=${kharej_ip}
SOCKS_PORT=${SOCKS_PORT}
SOCKS_USER=${SOCKS_USER}
IMPORTED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF

        echo -e "\n${GREEN}✓ Tunnel setup successfully${NC}"
        echo -e "${YELLOW}Use 'Port Forward' menu to configure ports.${NC}\n"

        log_iran "SUCCESS: Tunnel ${TUNNEL_NAME} imported from ZIP"
    else
        echo -e "${RED}✗ Configuration file not found${NC}"
        log_iran "ERROR: Config file not found in ZIP"
    fi

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}

# Setup manual
setup_manual() {
    echo -e "\n${CYAN}Manual Configuration${NC}\n"

    read -p "$(echo -e "${WHITE}Tunnel name: ${NC}")" tunnel_name
    tunnel_name=${tunnel_name:-iran-tunnel-1}

    read -p "$(echo -e "${WHITE}Foreign server IP: ${NC}")" kharej_ip

    if [[ -z "$kharej_ip" ]]; then
        echo -e "${RED}Server IP is required!${NC}"
        sleep 2
        return
    fi

    read -p "$(echo -e "${WHITE}SOCKS5 port (default: 1080): ${NC}")" socks_port
    socks_port=${socks_port:-1080}

    read -p "$(echo -e "${WHITE}SOCKS5 username (empty = no auth): ${NC}")" socks_user

    if [[ -n "$socks_user" ]]; then
        read -sp "$(echo -e "${WHITE}Password: ${NC}")" socks_pass
        echo
    fi

    # Create config directory
    mkdir -p "${IRAN_CONFIG}/${tunnel_name}"

    # Save configuration
    cat > "${IRAN_CONFIG}/${tunnel_name}/iran-config.conf" << EOF
TUNNEL_NAME=${tunnel_name}
KHAREJ_IP=${kharej_ip}
SOCKS_PORT=${socks_port}
SOCKS_USER=${socks_user}
SOCKS_PASS=${socks_pass}
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    echo -e "\n${GREEN}✓ Configuration saved${NC}"
    echo -e "${YELLOW}Use 'Port Forward' menu to setup port forwarding.${NC}\n"

    log_iran "SUCCESS: Manual tunnel ${tunnel_name} configured"

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}

# Port Forward Menu
port_forward_menu() {
    while true; do
        clear
        show_banner
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                  ${WHITE}Port Forward${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}1${NC} • ${WHITE}Create New Port Forward${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Define new port with GOST or socat                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${GREEN}2${NC} • ${WHITE}List Port Forwards${NC}                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}      Show all active port forwards                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}3${NC} • ${WHITE}Start/Stop Port Forward${NC}                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}4${NC} • ${WHITE}Delete Port Forward${NC}                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}0${NC} • ${WHITE}Back${NC}                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"

        read -p "$(echo -e "\n${WHITE}Your choice: ${NC}")" choice

        case $choice in
            1) create_port_forward ;;
            2) list_port_forwards ;;
            3) toggle_port_forward ;;
            4) delete_port_forward ;;
            0) return ;;
            *) echo -e "${RED}Invalid choice!${NC}"; sleep 1 ;;
        esac
    done
}

# Create Port Forward
create_port_forward() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}            ${WHITE}Create New Port Forward${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    # Select tunnel
    if [[ ! -d "$IRAN_CONFIG" ]] || [[ -z "$(ls -A "$IRAN_CONFIG" 2>/dev/null)" ]]; then
        echo -e "${RED}You must setup a tunnel first!${NC}\n"
        sleep 2
        return
    fi

    local tunnels=($(ls -1 "$IRAN_CONFIG"))

    if [[ ${#tunnels[@]} -eq 1 ]]; then
        local tunnel="${tunnels[0]}"
        echo -e "${CYAN}Using tunnel: ${tunnel}${NC}\n"
    else
        echo -e "${WHITE}Select tunnel:${NC}\n"
        local i=1
        for t in "${tunnels[@]}"; do
            echo -e "  ${CYAN}${i}.${NC} ${WHITE}${t}${NC}"
            ((i++))
        done

        read -p "$(echo -e "\n${WHITE}Tunnel number: ${NC}")" tunnel_num
        tunnel="${tunnels[$((tunnel_num-1))]}"
    fi

    # Load tunnel config
    if [[ -f "${IRAN_CONFIG}/${tunnel}/iran-config.conf" ]]; then
        source "${IRAN_CONFIG}/${tunnel}/iran-config.conf"
    else
        echo -e "${RED}Tunnel configuration not found!${NC}"
        sleep 2
        return
    fi

    # Select engine
    echo -e "${WHITE}Select Port Forward engine:${NC}\n"
    echo -e "  ${GREEN}1${NC} • GOST (recommended - powerful and fast)"
    echo -e "  ${GREEN}2${NC} • socat (lightweight and simple)\n"

    read -p "$(echo -e "${WHITE}Your choice: ${NC}")" engine_choice

    case $engine_choice in
        1) engine="gost" ;;
        2) engine="socat" ;;
        *) echo -e "${RED}Invalid choice!${NC}"; sleep 2; return ;;
    esac

    # Get port details
    read -p "$(echo -e "\n${WHITE}Local port (example: 2087): ${NC}")" local_port

    if [[ -z "$local_port" ]]; then
        echo -e "${RED}Local port is required!${NC}"
        sleep 2
        return
    fi

    read -p "$(echo -e "${WHITE}Destination port (example: 25): ${NC}")" remote_port
    remote_port=${remote_port:-$local_port}

    read -p "$(echo -e "${WHITE}Destination address (default: 127.0.0.1): ${NC}")" remote_host
    remote_host=${remote_host:-127.0.0.1}

    echo -e "\n${YELLOW}Creating Port Forward...${NC}\n"

    local pf_name="pf-${tunnel}-${local_port}"

    # Create port forward based on engine
    if [[ "$engine" == "gost" ]]; then
        create_gost_forward "$pf_name" "$local_port" "$remote_host" "$remote_port" "$KHAREJ_IP" "$SOCKS_PORT" "$SOCKS_USER" "$SOCKS_PASS"
    else
        create_socat_forward "$pf_name" "$local_port" "$remote_host" "$remote_port" "$KHAREJ_IP" "$SOCKS_PORT" "$SOCKS_USER" "$SOCKS_PASS"
    fi

    # Save port forward info
    mkdir -p "${IRAN_CONFIG}/${tunnel}/port-forwards"
    cat > "${IRAN_CONFIG}/${tunnel}/port-forwards/${pf_name}.conf" << EOF
PF_NAME=${pf_name}
ENGINE=${engine}
LOCAL_PORT=${local_port}
REMOTE_HOST=${remote_host}
REMOTE_PORT=${remote_port}
CREATED_AT=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    echo -e "\n${GREEN}✓ Port Forward created successfully${NC}\n"
    echo -e "${WHITE}Details:${NC}"
    echo -e "  Engine: ${CYAN}${engine}${NC}"
    echo -e "  Local Port: ${CYAN}${local_port}${NC}"
    echo -e "  Destination: ${CYAN}${remote_host}:${remote_port}${NC}"

    log_iran "SUCCESS: Port forward ${pf_name} created with ${engine}"

    read -p "$(echo -e "\n${WHITE}Press Enter to continue...${NC}")"
}

# Create GOST forward
create_gost_forward() {
    local pf_name=$1
    local local_port=$2
    local remote_host=$3
    local remote_port=$4
    local proxy_ip=$5
    local proxy_port=$6
    local proxy_user=$7
    local proxy_pass=$8

    local gost_config="/etc/xtron-tun/gost-${pf_name}.yaml"

    # Build proxy URL
    local proxy_url="socks5://${proxy_ip}:${proxy_port}"
    if [[ -n "$proxy_user" ]]; then
        proxy_url="socks5://${proxy_user}:${proxy_pass}@${proxy_ip}:${proxy_port}"
    fi

    # Create GOST config
    cat > "$gost_config" << EOF
services:
  - name: ${pf_name}
    addr: :${local_port}
    handler:
      type: tcp
      chain: chain-0
    listener:
      type: tcp
    forwarder:
      nodes:
        - name: target
          addr: ${remote_host}:${remote_port}

chains:
  - name: chain-0
    hops:
      - name: hop-0
        nodes:
          - name: proxy
            addr: ${proxy_ip}:${proxy_port}
            connector:
              type: socks5
EOF

    if [[ -n "$proxy_user" ]]; then
        cat >> "$gost_config" << EOF
              auth:
                username: ${proxy_user}
                password: ${proxy_pass}
EOF
    fi

    cat >> "$gost_config" << EOF
            dialer:
              type: tcp
EOF

    # Create systemd service
    cat > "/etc/systemd/system/xtron-pf-${pf_name}.service" << EOF
[Unit]
Description=XTRON Port Forward - ${pf_name} (GOST)
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/gost -C ${gost_config}
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/${pf_name}.log
StandardError=append:${LOG_DIR}/${pf_name}.log

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start
    systemctl daemon-reload
    systemctl enable "xtron-pf-${pf_name}.service" >/dev/null 2>&1
    systemctl start "xtron-pf-${pf_name}.service"

    # Configure firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${local_port}/tcp >/dev/null 2>&1
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${local_port}/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
}

# Create socat forward
create_socat_forward() {
    local pf_name=$1
    local local_port=$2
    local remote_host=$3
    local remote_port=$4
    local proxy_ip=$5
    local proxy_port=$6
    local proxy_user=$7
    local proxy_pass=$8

    # Build socat command
    local socat_cmd="socat TCP-LISTEN:${local_port},fork,reuseaddr"

    if [[ -n "$proxy_user" ]]; then
        socat_cmd="${socat_cmd} SOCKS5:${proxy_ip}:${remote_host}:${remote_port},socksport=${proxy_port},socksuser=${proxy_user},sockspass=${proxy_pass}"
    else
        socat_cmd="${socat_cmd} SOCKS5:${proxy_ip}:${remote_host}:${remote_port},socksport=${proxy_port}"
    fi

    # Create systemd service
    cat > "/etc/systemd/system/xtron-pf-${pf_name}.service" << EOF
[Unit]
Description=XTRON Port Forward - ${pf_name} (socat)
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/bin/socat TCP-LISTEN:${local_port},fork,reuseaddr SOCKS5:${proxy_ip}:${remote_host}:${remote_port},socksport=${proxy_port}
Restart=always
RestartSec=10
StandardOutput=append:${LOG_DIR}/${pf_name}.log
StandardError=append:${LOG_DIR}/${pf_name}.log

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start
    systemctl daemon-reload
    systemctl enable "xtron-pf-${pf_name}.service" >/dev/null 2>&1
    systemctl start "xtron-pf-${pf_name}.service"

    # Configure firewall
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${local_port}/tcp >/dev/null 2>&1
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${local_port}/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
}

# List port forwards
list_port_forwards() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              ${WHITE}List Port Forwards${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    local found=false

    for tunnel_dir in "${IRAN_CONFIG}"/*; do
        if [[ -d "${tunnel_dir}/port-forwards" ]]; then
            local tunnel=$(basename "$tunnel_dir")

            echo -e "${WHITE}Tunnel: ${CYAN}${tunnel}${NC}\n"

            for pf_file in "${tunnel_dir}/port-forwards"/*.conf; do
                if [[ -f "$pf_file" ]]; then
                    source "$pf_file"

                    local status="❌ Inactive"
                    local status_color="${RED}"

                    if systemctl is-active --quiet "xtron-pf-${PF_NAME}.service"; then
                        status="✅ Active"
                        status_color="${GREEN}"
                    fi

                    echo -e "  • ${WHITE}${PF_NAME}${NC}"
                    echo -e "    Status: ${status_color}${status}${NC}"
                    echo -e "    Engine: ${CYAN}${ENGINE}${NC}"
                    echo -e "    Local Port: ${CYAN}${LOCAL_PORT}${NC}"
                    echo -e "    Destination: ${CYAN}${REMOTE_HOST}:${REMOTE_PORT}${NC}"
                    echo -e ""

                    found=true
                fi
            done
        fi
    done

    if ! $found; then
        echo -e "${YELLOW}No active Port Forwards found${NC}\n"
    fi

    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Toggle port forward
toggle_port_forward() {
    echo -e "\n${YELLOW}This feature is under development...${NC}\n"
    sleep 2
}

# Delete port forward
delete_port_forward() {
    echo -e "\n${YELLOW}This feature is under development...${NC}\n"
    sleep 2
}

# Manage Iran tunnels
manage_iran_tunnels() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${WHITE}Manage Tunnels${NC}                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    if [[ ! -d "$IRAN_CONFIG" ]] || [[ -z "$(ls -A "$IRAN_CONFIG" 2>/dev/null)" ]]; then
        echo -e "${YELLOW}No tunnels found!${NC}\n"
        read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
        return
    fi

    local tunnels=($(ls -1 "$IRAN_CONFIG"))

    echo -e "${WHITE}Available Tunnels:${NC}\n"

    for tunnel in "${tunnels[@]}"; do
        if [[ -f "${IRAN_CONFIG}/${tunnel}/iran-config.conf" ]]; then
            source "${IRAN_CONFIG}/${tunnel}/iran-config.conf"

            echo -e "  ${CYAN}•${NC} ${WHITE}${tunnel}${NC}"
            echo -e "    Foreign Server: ${CYAN}${KHAREJ_IP}:${SOCKS_PORT}${NC}"

            # Count port forwards
            local pf_count=0
            if [[ -d "${IRAN_CONFIG}/${tunnel}/port-forwards" ]]; then
                pf_count=$(ls -1 "${IRAN_CONFIG}/${tunnel}/port-forwards"/*.conf 2>/dev/null | wc -l)
            fi

            echo -e "    Port Forwards: ${CYAN}${pf_count}${NC}"
            echo -e ""
        fi
    done

    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Show Iran logs
show_iran_logs() {
    clear
    show_banner
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}Logs${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    if [[ -f "$IRAN_LOG" ]]; then
        echo -e "${WHITE}Recent logs:${NC}\n"
        tail -n 50 "$IRAN_LOG"
    else
        echo -e "${YELLOW}No logs found${NC}"
    fi

    echo -e ""
    read -p "$(echo -e "${WHITE}Press Enter to go back...${NC}")"
}

# Delete Iran tunnel
delete_iran_tunnel() {
    clear
    show_banner
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}                ${WHITE}Delete and Cleanup${NC}                        ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${RED}⚠️  Warning: This operation will delete all tunnels and port forwards!${NC}\n"

    read -p "$(echo -e "${WHITE}Are you sure? (yes/no): ${NC}")" confirm

    if [[ "$confirm" == "yes" ]]; then
        echo -e "\n${YELLOW}Deleting...${NC}\n"

        # Stop all services
        for service in $(systemctl list-units --all "xtron-pf-*" --no-legend | awk '{print $1}'); do
            systemctl stop "$service" 2>/dev/null
            systemctl disable "$service" 2>/dev/null
        done

        # Remove service files
        rm -f /etc/systemd/system/xtron-pf-*.service
        rm -f /etc/xtron-tun/gost-pf-*.yaml

        systemctl daemon-reload

        # Remove configurations
        rm -rf "$IRAN_CONFIG"

        echo -e "${GREEN}✓ All tunnels and configurations deleted successfully${NC}\n"
        log_iran "SUCCESS: All tunnels and port forwards deleted"
    else
        echo -e "${YELLOW}Operation cancelled${NC}\n"
    fi

    read -p "$(echo -e "${WHITE}Press Enter to continue...${NC}")"
}
