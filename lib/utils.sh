#!/bin/bash

#############################################
# XTRON-TUN Utility Functions Library
# GitHub: alixtron0/xtron-tun
#############################################

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'

# Emoji / Unicode symbols
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly ARROW="→"
readonly BULLET="•"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly SUCCESS="🎉"
readonly ROCKET="🚀"

# Configuration paths
readonly CONFIG_DIR="${CONFIG_DIR:-/etc/xtron-tun}"
readonly LOG_DIR="${LOG_DIR:-/var/log/xtron-tun}"
readonly LIB_DIR="${LIB_DIR:-/usr/local/lib/xtron-tun}"

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
║              مدیریت حرفه‌ای تونل SMTP                     ║
║                      نسخه 1.0.0                          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

# Logging functions
log_info() {
    echo -e "${CYAN}${INFO}  $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "${LOG_DIR}/xtron.log"
}

log_success() {
    echo -e "${GREEN}${CHECK_MARK}  $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $*" >> "${LOG_DIR}/xtron.log"
}

log_error() {
    echo -e "${RED}${CROSS_MARK}  $*${NC}" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "${LOG_DIR}/xtron.log"
}

log_warning() {
    echo -e "${YELLOW}${WARNING}  $*${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $*" >> "${LOG_DIR}/xtron.log"
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${DIM}[DEBUG] $*${NC}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "${LOG_DIR}/xtron.log"
    fi
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
        printf "\r${GREEN}${CHECK_MARK} ${message}... Done!${NC}\n"
    else
        printf "\r${RED}${CROSS_MARK} ${message}... Failed!${NC}\n"
        return $exit_code
    fi
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50

    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${CYAN}["
    printf "%0.s=" $(seq 1 $filled)
    printf "%0.s " $(seq 1 $empty)
    printf "] %d%%${NC}" $percentage
}

# Box drawing
draw_box() {
    local title=$1
    local width=${2:-60}

    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $((width - 2))))╗${NC}"

    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local padding=$(( (width - title_len - 2) / 2 ))
        echo -e "${CYAN}║${NC}$(printf ' %.0s' $(seq 1 $padding))${WHITE}${title}${NC}$(printf ' %.0s' $(seq 1 $padding))${CYAN}║${NC}"
        echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $((width - 2))))╣${NC}"
    fi
}

end_box() {
    local width=${1:-60}
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $((width - 2))))╝${NC}"
}

# Horizontal line
draw_line() {
    local char=${1:-─}
    local width=${2:-60}
    echo -e "${CYAN}$(printf "${char}%.0s" $(seq 1 $width))${NC}"
}

# Confirmation prompt
confirm() {
    local message=$1
    local default=${2:-n}

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    read -p "$(echo -e "${WHITE}${message} ${YELLOW}${prompt}${NC}: ")" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

# Input validation
validate_ip() {
    local ip=$1
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $regex ]]; then
        local IFS='.'
        local -a octets=($ip)

        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]]; then
                return 1
            fi
        done

        return 0
    fi

    return 1
}

validate_port() {
    local port=$1

    if [[ "$port" =~ ^[0-9]+$ ]] && [[ $port -ge 1 ]] && [[ $port -le 65535 ]]; then
        return 0
    fi

    return 1
}

validate_domain() {
    local domain=$1
    local regex='^([a-zA-Z0-9]([-a-zA-Z0-9]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'

    [[ $domain =~ $regex ]]
}

# Check if port is available
is_port_available() {
    local port=$1

    if ss -tuln | grep -q ":${port} "; then
        return 1  # Port is in use
    fi

    return 0  # Port is available
}

# Get public IP
get_public_ip() {
    local ip

    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --max-time 5 icanhazip.com 2>/dev/null) || \
    ip=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null) || \
    ip=$(wget -qO- --timeout=5 ifconfig.me 2>/dev/null) || \
    ip="N/A"

    echo "$ip"
}

# Resolve hostname to IP
resolve_host() {
    local hostname=$1
    local ip

    ip=$(dig +short "$hostname" 2>/dev/null | tail -1) || \
    ip=$(host "$hostname" 2>/dev/null | grep "has address" | awk '{print $NF}' | head -1) || \
    ip=$(nslookup "$hostname" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1) || \
    ip=""

    echo "$ip"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if service is running
is_service_running() {
    local service=$1

    if systemctl is-active --quiet "$service"; then
        return 0
    fi

    return 1
}

# Check if service exists
service_exists() {
    local service=$1

    if systemctl list-unit-files | grep -q "^${service}"; then
        return 0
    fi

    return 1
}

# Get service status
get_service_status() {
    local service=$1

    if is_service_running "$service"; then
        echo -e "${GREEN}فعال${NC}"
    else
        echo -e "${RED}غیرفعال${NC}"
    fi
}

# System information
get_os_info() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${NAME} ${VERSION}"
    else
        echo "Unknown"
    fi
}

get_kernel_version() {
    uname -r
}

get_cpu_cores() {
    nproc
}

get_total_memory() {
    free -h | awk '/^Mem:/ {print $2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}'
}

get_uptime() {
    uptime -p
}

# Network utilities
check_connectivity() {
    local host=${1:-8.8.8.8}

    if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

test_socks5_proxy() {
    local proxy_host=$1
    local proxy_port=$2
    local proxy_user=${3:-}
    local proxy_pass=${4:-}

    if command_exists curl; then
        local proxy_url="socks5://${proxy_host}:${proxy_port}"

        if [[ -n "$proxy_user" ]]; then
            proxy_url="socks5://${proxy_user}:${proxy_pass}@${proxy_host}:${proxy_port}"
        fi

        if curl -s --max-time 10 --proxy "$proxy_url" https://ifconfig.me >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

# File utilities
backup_file() {
    local file=$1
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_info "Backup created: $backup"
        echo "$backup"
        return 0
    fi

    return 1
}

create_directory() {
    local dir=$1
    local mode=${2:-755}

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        log_debug "Directory created: $dir"
    fi
}

# Generate random string
generate_random_string() {
    local length=${1:-16}
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Generate random password
generate_password() {
    local length=${1:-20}
    tr -dc 'A-Za-z0-9!@#$%^&*()_+=' < /dev/urandom | head -c "$length"
}

# Format bytes
format_bytes() {
    local bytes=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while [[ $bytes -ge 1024 ]] && [[ $unit -lt 4 ]]; do
        bytes=$((bytes / 1024))
        ((unit++))
    done

    echo "${bytes}${units[$unit]}"
}

# Time formatting
format_duration() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local mins=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h ${mins}m"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${mins}m ${secs}s"
    elif [[ $mins -gt 0 ]]; then
        echo "${mins}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Error handling
die() {
    log_error "$*"
    exit 1
}

# Cleanup function
cleanup() {
    log_debug "Cleanup function called"
    # Add cleanup tasks here
}

# Trap errors
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    local missing=()

    for cmd in curl wget jq systemctl; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi

    return 0
}

# Wait for service
wait_for_service() {
    local service=$1
    local timeout=${2:-30}
    local elapsed=0

    while [[ $elapsed -lt $timeout ]]; do
        if is_service_running "$service"; then
            return 0
        fi

        sleep 1
        ((elapsed++))
    done

    return 1
}

# Menu builder
build_menu() {
    local title=$1
    shift
    local -a options=("$@")

    draw_box "$title"

    local i=1
    for option in "${options[@]}"; do
        echo -e "${CYAN}║${NC}  ${GREEN}${i}${NC} ${BULLET} ${WHITE}${option}${NC}"
        ((i++))
    done

    echo -e "${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${YELLOW}0${NC} ${BULLET} ${WHITE}بازگشت${NC}"
    end_box
}

# Table builder
print_table_row() {
    local -a columns=("$@")
    local width=20

    echo -n "${CYAN}║${NC}"
    for col in "${columns[@]}"; do
        printf " ${WHITE}%-${width}s${NC}" "$col"
    done
    echo " ${CYAN}║${NC}"
}

# Export all functions
export -f show_banner
export -f log_info log_success log_error log_warning log_debug
export -f spin show_progress
export -f draw_box end_box draw_line
export -f confirm
export -f validate_ip validate_port validate_domain
export -f is_port_available get_public_ip resolve_host
export -f command_exists is_service_running service_exists get_service_status
export -f check_connectivity test_socks5_proxy
export -f backup_file create_directory
export -f generate_random_string generate_password
export -f format_bytes format_duration
export -f die cleanup check_prerequisites wait_for_service
export -f build_menu print_table_row
