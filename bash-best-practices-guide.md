# راهنمای جامع مدیریت تونل و سرویس‌های لینوکس با Bash
## استانداردهای 2024-2026

این مستند شامل بهترین روش‌ها و مثال‌های کامل برای مدیریت تونل‌ها، سرویس‌ها و پیکربندی‌های امنیتی در محیط‌های production می‌باشد.

---

## 1. مدیریت سرویس‌های Systemd

### 1.1 ایجاد سرویس Systemd برای GOST

```bash
#!/bin/bash
# create-gost-service.sh - ایجاد سرویس systemd برای GOST proxy

set -euo pipefail  # خروج در صورت خطا، متغیرهای تعریف نشده، یا خطا در pipe

# تنظیمات پیش‌فرض
readonly SERVICE_NAME="gost-tunnel"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
readonly GOST_BIN="/usr/local/bin/gost"
readonly CONFIG_FILE="/etc/gost/config.yml"

# رنگ‌ها برای خروجی
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# تابع logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a /var/log/gost-setup.log
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a /var/log/gost-setup.log >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a /var/log/gost-setup.log
}

# بررسی دسترسی root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "این اسکریپت باید با دسترسی root اجرا شود"
        exit 1
    fi
}

# ایجاد فایل سرویس systemd
create_service_file() {
    log_info "در حال ایجاد فایل سرویس ${SERVICE_FILE}..."

    cat > "${SERVICE_FILE}" <<'EOF'
[Unit]
Description=GOST Tunnel Service
Documentation=https://gost.run
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=gost
Group=gost
ExecStart=/usr/local/bin/gost -C /etc/gost/config.yml
Restart=always
RestartSec=5
StartLimitInterval=0
StandardOutput=append:/var/log/gost/gost.log
StandardError=append:/var/log/gost/gost-error.log

# امنیت
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log/gost

# محدودیت منابع
LimitNOFILE=65535
LimitNPROC=512
CPUQuota=200%
MemoryMax=512M

[Install]
WantedBy=multi-user.target
EOF

    chmod 644 "${SERVICE_FILE}"
    log_info "فایل سرویس با موفقیت ایجاد شد"
}

# ایجاد کاربر و دایرکتوری‌های لازم
setup_user_and_dirs() {
    log_info "در حال ایجاد کاربر و دایرکتوری‌ها..."

    # ایجاد کاربر gost در صورت عدم وجود
    if ! id -u gost &>/dev/null; then
        useradd -r -s /bin/false -d /var/lib/gost gost
        log_info "کاربر gost ایجاد شد"
    else
        log_warn "کاربر gost قبلاً وجود دارد"
    fi

    # ایجاد دایرکتوری‌ها
    mkdir -p /etc/gost /var/log/gost /var/lib/gost
    chown -R gost:gost /etc/gost /var/log/gost /var/lib/gost
    chmod 750 /etc/gost /var/log/gost
}

# ایجاد فایل پیکربندی نمونه
create_sample_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_info "در حال ایجاد فایل پیکربندی نمونه..."

        cat > "${CONFIG_FILE}" <<'EOF'
services:
  - name: tcp-forward-2087
    addr: :2087
    handler:
      type: tcp
    listener:
      type: tcp
    forwarder:
      nodes:
        - name: foreign-server
          addr: FOREIGN_IP:2087
          connector:
            type: socks5
          dialer:
            type: tcp
chains:
  - name: chain-0
    hops:
      - name: hop-0
        nodes:
          - name: socks5-proxy
            addr: 127.0.0.1:1080
            connector:
              type: socks5
              auth:
                username: ""
                password: ""
            dialer:
              type: tcp
log:
  level: info
  format: json
  output: /var/log/gost/gost.log
EOF

        chown gost:gost "${CONFIG_FILE}"
        chmod 640 "${CONFIG_FILE}"
        log_info "فایل پیکربندی نمونه ایجاد شد: ${CONFIG_FILE}"
    else
        log_warn "فایل پیکربندی قبلاً وجود دارد، از تغییر آن صرف‌نظر شد"
    fi
}

# فعال‌سازی و شروع سرویس
enable_and_start_service() {
    log_info "در حال reload کردن systemd daemon..."
    systemctl daemon-reload

    log_info "در حال فعال‌سازی سرویس ${SERVICE_NAME}..."
    systemctl enable "${SERVICE_NAME}"

    log_info "در حال شروع سرویس ${SERVICE_NAME}..."
    if systemctl start "${SERVICE_NAME}"; then
        log_info "سرویس با موفقیت شروع شد"
    else
        log_error "خطا در شروع سرویس"
        systemctl status "${SERVICE_NAME}" --no-pager
        exit 1
    fi
}

# بررسی وضعیت سرویس
check_service_status() {
    log_info "وضعیت سرویس:"
    systemctl status "${SERVICE_NAME}" --no-pager

    log_info "\nلاگ‌های اخیر:"
    journalctl -u "${SERVICE_NAME}" -n 20 --no-pager
}

# تابع اصلی
main() {
    check_root
    log_info "شروع نصب سرویس GOST..."

    setup_user_and_dirs
    create_service_file
    create_sample_config
    enable_and_start_service
    check_service_status

    log_info "نصب با موفقیت به پایان رسید!"
    echo -e "\n${GREEN}دستورات مفید:${NC}"
    echo "  - مشاهده وضعیت: systemctl status ${SERVICE_NAME}"
    echo "  - مشاهده لاگ‌ها: journalctl -u ${SERVICE_NAME} -f"
    echo "  - توقف سرویس: systemctl stop ${SERVICE_NAME}"
    echo "  - ویرایش پیکربندی: nano ${CONFIG_FILE}"
    echo "  - restart سرویس: systemctl restart ${SERVICE_NAME}"
}

main "$@"
```

### 1.2 مدیریت پیشرفته سرویس‌ها

```bash
#!/bin/bash
# service-manager.sh - مدیریت جامع سرویس‌های systemd

set -euo pipefail

# کدهای خروج
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=2
readonly EXIT_SERVICE_ERROR=3
readonly EXIT_PERMISSION_ERROR=4

# توابع مدیریت سرویس
service_exists() {
    local service_name="$1"
    systemctl list-unit-files --type=service | grep -q "^${service_name}.service"
}

is_service_active() {
    local service_name="$1"
    systemctl is-active --quiet "${service_name}"
}

is_service_enabled() {
    local service_name="$1"
    systemctl is-enabled --quiet "${service_name}"
}

start_service() {
    local service_name="$1"
    echo "[INFO] در حال شروع سرویس ${service_name}..."

    if systemctl start "${service_name}"; then
        echo "[SUCCESS] سرویس ${service_name} با موفقیت شروع شد"
        return 0
    else
        echo "[ERROR] خطا در شروع سرویس ${service_name}" >&2
        systemctl status "${service_name}" --no-pager >&2
        return 1
    fi
}

stop_service() {
    local service_name="$1"
    echo "[INFO] در حال توقف سرویس ${service_name}..."

    if systemctl stop "${service_name}"; then
        echo "[SUCCESS] سرویس ${service_name} متوقف شد"
        return 0
    else
        echo "[ERROR] خطا در توقف سرویس ${service_name}" >&2
        return 1
    fi
}

restart_service() {
    local service_name="$1"
    echo "[INFO] در حال restart سرویس ${service_name}..."

    if systemctl restart "${service_name}"; then
        echo "[SUCCESS] سرویس ${service_name} restart شد"
        return 0
    else
        echo "[ERROR] خطا در restart سرویس ${service_name}" >&2
        return 1
    fi
}

enable_service() {
    local service_name="$1"
    echo "[INFO] در حال فعال‌سازی سرویس ${service_name}..."

    if systemctl enable "${service_name}"; then
        echo "[SUCCESS] سرویس ${service_name} فعال شد (راه‌اندازی خودکار در boot)"
        return 0
    else
        echo "[ERROR] خطا در فعال‌سازی سرویس ${service_name}" >&2
        return 1
    fi
}

disable_service() {
    local service_name="$1"
    echo "[INFO] در حال غیرفعال‌سازی سرویس ${service_name}..."

    if systemctl disable "${service_name}"; then
        echo "[SUCCESS] سرویس ${service_name} غیرفعال شد"
        return 0
    else
        echo "[ERROR] خطا در غیرفعال‌سازی سرویس ${service_name}" >&2
        return 1
    fi
}

get_service_status() {
    local service_name="$1"

    echo "=== وضعیت سرویس ${service_name} ==="
    systemctl status "${service_name}" --no-pager

    echo -e "\n=== آخرین لاگ‌ها ==="
    journalctl -u "${service_name}" -n 30 --no-pager
}

# نمونه استفاده
if [[ $# -lt 2 ]]; then
    echo "استفاده: $0 <action> <service_name>" >&2
    echo "Actions: start, stop, restart, enable, disable, status" >&2
    exit ${EXIT_INVALID_ARGS}
fi

ACTION="$1"
SERVICE_NAME="$2"

case "${ACTION}" in
    start)
        start_service "${SERVICE_NAME}"
        ;;
    stop)
        stop_service "${SERVICE_NAME}"
        ;;
    restart)
        restart_service "${SERVICE_NAME}"
        ;;
    enable)
        enable_service "${SERVICE_NAME}"
        ;;
    disable)
        disable_service "${SERVICE_NAME}"
        ;;
    status)
        get_service_status "${SERVICE_NAME}"
        ;;
    *)
        echo "[ERROR] عملیات نامعتبر: ${ACTION}" >&2
        exit ${EXIT_INVALID_ARGS}
        ;;
esac
```

---

## 2. مدیریت کاربران SOCKS5/GOST

### 2.1 مدیریت کاربران با GOST v3

```bash
#!/bin/bash
# gost-user-manager.sh - مدیریت کاربران GOST

set -euo pipefail

readonly AUTH_FILE="/etc/gost/auth.txt"
readonly CONFIG_FILE="/etc/gost/config.yml"
readonly SERVICE_NAME="gost-tunnel"

# توابع رنگی
red() { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

# بررسی دسترسی
check_permissions() {
    if [[ ! -w "${AUTH_FILE}" ]]; then
        red "خطا: دسترسی نوشتن به ${AUTH_FILE} وجود ندارد"
        exit 1
    fi
}

# ایجاد فایل auth در صورت عدم وجود
init_auth_file() {
    if [[ ! -f "${AUTH_FILE}" ]]; then
        touch "${AUTH_FILE}"
        chown gost:gost "${AUTH_FILE}"
        chmod 600 "${AUTH_FILE}"
        green "فایل احراز هویت ایجاد شد: ${AUTH_FILE}"
    fi
}

# اضافه کردن کاربر
add_user() {
    local username="$1"
    local password="$2"

    # بررسی وجود کاربر
    if grep -q "^${username}:" "${AUTH_FILE}" 2>/dev/null; then
        yellow "کاربر ${username} قبلاً وجود دارد"
        read -p "آیا می‌خواهید رمز عبور را به‌روزرسانی کنید؟ (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        remove_user "${username}"
    fi

    # اضافه کردن کاربر جدید
    echo "${username}:${password}" >> "${AUTH_FILE}"
    green "کاربر ${username} با موفقیت اضافه شد"

    # reload سرویس
    reload_service
}

# حذف کاربر
remove_user() {
    local username="$1"

    if grep -q "^${username}:" "${AUTH_FILE}" 2>/dev/null; then
        sed -i "/^${username}:/d" "${AUTH_FILE}"
        green "کاربر ${username} حذف شد"
        reload_service
    else
        yellow "کاربر ${username} یافت نشد"
        return 1
    fi
}

# لیست کاربران
list_users() {
    echo "=== لیست کاربران ==="
    if [[ -f "${AUTH_FILE}" && -s "${AUTH_FILE}" ]]; then
        awk -F: '{print "  - " $1}' "${AUTH_FILE}"
    else
        yellow "هیچ کاربری تعریف نشده است"
    fi
}

# تغییر رمز عبور
change_password() {
    local username="$1"
    local new_password="$2"

    if grep -q "^${username}:" "${AUTH_FILE}" 2>/dev/null; then
        sed -i "s/^${username}:.*/${username}:${new_password}/" "${AUTH_FILE}"
        green "رمز عبور کاربر ${username} تغییر یافت"
        reload_service
    else
        red "کاربر ${username} یافت نشد"
        return 1
    fi
}

# reload سرویس GOST
reload_service() {
    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        green "در حال reload سرویس ${SERVICE_NAME}..."
        systemctl reload-or-restart "${SERVICE_NAME}"
        sleep 2

        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            green "سرویس با موفقیت reload شد"
        else
            red "خطا در reload سرویس"
            systemctl status "${SERVICE_NAME}" --no-pager
        fi
    else
        yellow "سرویس ${SERVICE_NAME} در حال اجرا نیست"
    fi
}

# تولید رمز عبور تصادفی
generate_password() {
    local length="${1:-16}"
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c "${length}"
    echo
}

# منوی اصلی
show_menu() {
    echo "=== مدیریت کاربران GOST ==="
    echo "1. اضافه کردن کاربر"
    echo "2. حذف کاربر"
    echo "3. لیست کاربران"
    echo "4. تغییر رمز عبور"
    echo "5. تولید رمز عبور تصادفی"
    echo "6. خروج"
    echo
}

# تابع اصلی
main() {
    init_auth_file
    check_permissions

    while true; do
        show_menu
        read -p "انتخاب کنید (1-6): " choice

        case $choice in
            1)
                read -p "نام کاربری: " username
                read -sp "رمز عبور: " password
                echo
                add_user "${username}" "${password}"
                ;;
            2)
                read -p "نام کاربری برای حذف: " username
                remove_user "${username}"
                ;;
            3)
                list_users
                ;;
            4)
                read -p "نام کاربری: " username
                read -sp "رمز عبور جدید: " password
                echo
                change_password "${username}" "${password}"
                ;;
            5)
                echo "رمز عبور تصادفی: $(generate_password 16)"
                ;;
            6)
                green "خروج..."
                exit 0
                ;;
            *)
                red "انتخاب نامعتبر"
                ;;
        esac
        echo
    done
}

# اجرای اسکریپت با menu در صورت عدم ارسال آرگومان
if [[ $# -eq 0 ]]; then
    main
else
    # استفاده از command-line
    case "$1" in
        add)
            [[ $# -lt 3 ]] && { red "استفاده: $0 add <username> <password>"; exit 1; }
            init_auth_file
            add_user "$2" "$3"
            ;;
        remove)
            [[ $# -lt 2 ]] && { red "استفاده: $0 remove <username>"; exit 1; }
            remove_user "$2"
            ;;
        list)
            list_users
            ;;
        *)
            red "دستور نامعتبر: $1"
            echo "دستورات: add, remove, list"
            exit 1
            ;;
    esac
fi
```

### 2.2 پیکربندی YAML برای GOST v3 با احراز هویت

```yaml
# /etc/gost/config.yml - پیکربندی کامل GOST v3

services:
  - name: socks5-server
    addr: :1080
    handler:
      type: socks5
      auth:
        auther:
          file:
            path: /etc/gost/auth.txt
            reload: 60s  # بررسی تغییرات هر 60 ثانیه
    listener:
      type: tcp

  - name: tcp-forward-2087
    addr: :2087
    handler:
      type: tcp
    listener:
      type: tcp
    forwarder:
      nodes:
        - name: target-2087
          addr: FOREIGN_IP:2087

  - name: tcp-forward-2052
    addr: :2052
    handler:
      type: tcp
    listener:
      type: tcp
    forwarder:
      nodes:
        - name: target-2052
          addr: FOREIGN_IP:2052

chains:
  - name: socks5-chain
    hops:
      - name: socks5-hop
        nodes:
          - name: local-socks5
            addr: 127.0.0.1:1080
            connector:
              type: socks5
              auth:
                username: admin
                password: secure_password_here
            dialer:
              type: tcp

log:
  level: info
  format: json
  output: /var/log/gost/gost.log
  rotation:
    maxSize: 100  # MB
    maxAge: 30    # days
    maxBackups: 10
    compress: true

api:
  addr: 127.0.0.1:18080
  auth:
    username: admin
    password: api_secure_password
  accesslog: true
```

---

## 3. مانیتورینگ و Health Check

### 3.1 اسکریپت جامع بررسی سلامت تونل

```bash
#!/bin/bash
# tunnel-health-check.sh - بررسی سلامت تونل‌ها و پروکسی‌ها

set -euo pipefail

# تنظیمات
readonly SOCKS_PROXY="127.0.0.1:1080"
readonly TEST_URL="https://api.ipify.org?format=json"
readonly TIMEOUT=10
readonly LOG_FILE="/var/log/tunnel-health.log"
readonly MAX_RETRIES=3

# رنگ‌ها
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# متغیرهای global
declare -i TOTAL_CHECKS=0
declare -i PASSED_CHECKS=0
declare -i FAILED_CHECKS=0

# لاگ با timestamp
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

# بررسی دسترسی به اینترنت مستقیم
check_direct_internet() {
    log "INFO" "بررسی دسترسی مستقیم به اینترنت..."
    ((TOTAL_CHECKS++))

    if curl -s --max-time "${TIMEOUT}" "${TEST_URL}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} اتصال مستقیم به اینترنت: موفق"
        log "SUCCESS" "اتصال مستقیم به اینترنت برقرار است"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC} اتصال مستقیم به اینترنت: ناموفق"
        log "ERROR" "اتصال مستقیم به اینترنت برقرار نیست"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# بررسی پورت باز بودن
check_port() {
    local host="$1"
    local port="$2"
    ((TOTAL_CHECKS++))

    if timeout "${TIMEOUT}" bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} پورت ${port} روی ${host}: باز"
        log "SUCCESS" "پورت ${port} روی ${host} باز است"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC} پورت ${port} روی ${host}: بسته"
        log "ERROR" "پورت ${port} روی ${host} بسته است"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# بررسی SOCKS5 proxy
check_socks5_proxy() {
    local proxy="$1"
    ((TOTAL_CHECKS++))

    log "INFO" "بررسی SOCKS5 proxy: ${proxy}"

    # تست اتصال از طریق SOCKS5
    local result
    result=$(curl -s --max-time "${TIMEOUT}" \
        --socks5-hostname "${proxy}" \
        "${TEST_URL}" 2>&1)

    if [[ $? -eq 0 ]] && [[ -n "${result}" ]]; then
        local ip
        ip=$(echo "${result}" | grep -oP '(?<="ip":")[^"]+' || echo "نامشخص")
        echo -e "${GREEN}✓${NC} SOCKS5 proxy (${proxy}): فعال - IP: ${ip}"
        log "SUCCESS" "SOCKS5 proxy ${proxy} فعال است - IP: ${ip}"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC} SOCKS5 proxy (${proxy}): غیرفعال"
        log "ERROR" "SOCKS5 proxy ${proxy} پاسخ نمی‌دهد - خطا: ${result}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# بررسی SOCKS5 با احراز هویت
check_socks5_auth() {
    local proxy="$1"
    local username="$2"
    local password="$3"
    ((TOTAL_CHECKS++))

    log "INFO" "بررسی SOCKS5 با احراز هویت: ${username}@${proxy}"

    local result
    result=$(curl -s --max-time "${TIMEOUT}" \
        --socks5-hostname "${proxy}" \
        --proxy-user "${username}:${password}" \
        "${TEST_URL}" 2>&1)

    if [[ $? -eq 0 ]] && [[ -n "${result}" ]]; then
        echo -e "${GREEN}✓${NC} SOCKS5 احراز هویت (${username}@${proxy}): موفق"
        log "SUCCESS" "احراز هویت SOCKS5 برای ${username} موفق بود"
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC} SOCKS5 احراز هویت (${username}@${proxy}): ناموفق"
        log "ERROR" "احراز هویت SOCKS5 برای ${username} ناموفق - خطا: ${result}"
        ((FAILED_CHECKS++))
        return 1
    fi
}

# بررسی تاخیر (latency)
check_latency() {
    local proxy="$1"
    local test_url="${2:-${TEST_URL}}"

    log "INFO" "اندازه‌گیری تاخیر از طریق ${proxy}..."

    local start_time end_time latency
    start_time=$(date +%s%N)

    if curl -s --max-time "${TIMEOUT}" \
        --socks5-hostname "${proxy}" \
        "${test_url}" > /dev/null 2>&1; then

        end_time=$(date +%s%N)
        latency=$(( (end_time - start_time) / 1000000 ))

        if [[ ${latency} -lt 1000 ]]; then
            echo -e "${GREEN}✓${NC} تاخیر: ${latency}ms (عالی)"
        elif [[ ${latency} -lt 3000 ]]; then
            echo -e "${YELLOW}!${NC} تاخیر: ${latency}ms (متوسط)"
        else
            echo -e "${RED}✗${NC} تاخیر: ${latency}ms (ضعیف)"
        fi

        log "INFO" "تاخیر اتصال از طریق ${proxy}: ${latency}ms"
        return 0
    else
        echo -e "${RED}✗${NC} خطا در اندازه‌گیری تاخیر"
        log "ERROR" "خطا در اندازه‌گیری تاخیر از طریق ${proxy}"
        return 1
    fi
}

# بررسی DNS leak
check_dns_leak() {
    local proxy="$1"

    log "INFO" "بررسی DNS leak از طریق ${proxy}..."

    local dns_result
    dns_result=$(curl -s --max-time "${TIMEOUT}" \
        --socks5-hostname "${proxy}" \
        "https://dns.google/resolve?name=google.com&type=A" 2>&1)

    if [[ $? -eq 0 ]] && echo "${dns_result}" | grep -q "Answer"; then
        echo -e "${GREEN}✓${NC} DNS resolution از طریق proxy: موفق"
        log "SUCCESS" "DNS resolution از طریق proxy کار می‌کند"
        return 0
    else
        echo -e "${YELLOW}!${NC} DNS resolution: ممکن است leak وجود داشته باشد"
        log "WARN" "احتمال DNS leak - بررسی دقیق‌تر نیاز است"
        return 1
    fi
}

# بررسی وضعیت سرویس systemd
check_service_status() {
    local service_name="$1"
    ((TOTAL_CHECKS++))

    log "INFO" "بررسی وضعیت سرویس ${service_name}..."

    if systemctl is-active --quiet "${service_name}"; then
        echo -e "${GREEN}✓${NC} سرویس ${service_name}: فعال"
        log "SUCCESS" "سرویس ${service_name} در حال اجرا است"

        # نمایش اطلاعات بیشتر
        local uptime
        uptime=$(systemctl show -p ActiveEnterTimestamp "${service_name}" | cut -d= -f2)
        echo -e "  ${BLUE}↳${NC} زمان شروع: ${uptime}"

        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC} سرویس ${service_name}: غیرفعال"
        log "ERROR" "سرویس ${service_name} در حال اجرا نیست"

        # نمایش آخرین خطا
        echo -e "  ${RED}↳${NC} آخرین خطا:"
        journalctl -u "${service_name}" -n 3 --no-pager | sed 's/^/    /'

        ((FAILED_CHECKS++))
        return 1
    fi
}

# بررسی استفاده از منابع سیستم
check_resource_usage() {
    local service_name="$1"

    log "INFO" "بررسی استفاده از منابع ${service_name}..."

    if ! systemctl is-active --quiet "${service_name}"; then
        echo -e "${YELLOW}!${NC} سرویس ${service_name} فعال نیست - نمی‌توان منابع را بررسی کرد"
        return 1
    fi

    # دریافت PID
    local pid
    pid=$(systemctl show -p MainPID "${service_name}" | cut -d= -f2)

    if [[ -z "${pid}" || "${pid}" == "0" ]]; then
        echo -e "${YELLOW}!${NC} PID سرویس یافت نشد"
        return 1
    fi

    # استفاده از CPU و RAM
    local cpu_usage mem_usage
    cpu_usage=$(ps -p "${pid}" -o %cpu --no-headers | xargs)
    mem_usage=$(ps -p "${pid}" -o %mem --no-headers | xargs)

    echo -e "${BLUE}ℹ${NC} استفاده از منابع ${service_name}:"
    echo -e "  ${BLUE}↳${NC} CPU: ${cpu_usage}%"
    echo -e "  ${BLUE}↳${NC} RAM: ${mem_usage}%"

    log "INFO" "استفاده از منابع ${service_name} - CPU: ${cpu_usage}%, RAM: ${mem_usage}%"
}

# تست کامل با retry
test_with_retry() {
    local test_func="$1"
    shift
    local args=("$@")

    for ((i=1; i<=MAX_RETRIES; i++)); do
        if "${test_func}" "${args[@]}"; then
            return 0
        fi

        if [[ ${i} -lt ${MAX_RETRIES} ]]; then
            echo -e "${YELLOW}  ⟳${NC} تلاش مجدد ${i}/${MAX_RETRIES}..."
            sleep 2
        fi
    done

    return 1
}

# نمایش خلاصه نتایج
show_summary() {
    echo
    echo "========================================="
    echo "         خلاصه نتایج بررسی سلامت"
    echo "========================================="
    echo -e "مجموع تست‌ها: ${TOTAL_CHECKS}"
    echo -e "${GREEN}موفق: ${PASSED_CHECKS}${NC}"
    echo -e "${RED}ناموفق: ${FAILED_CHECKS}${NC}"

    local success_rate=0
    if [[ ${TOTAL_CHECKS} -gt 0 ]]; then
        success_rate=$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))
    fi

    echo -e "نرخ موفقیت: ${success_rate}%"
    echo "========================================="

    log "SUMMARY" "مجموع: ${TOTAL_CHECKS}, موفق: ${PASSED_CHECKS}, ناموفق: ${FAILED_CHECKS}, نرخ موفقیت: ${success_rate}%"

    # خروج با کد مناسب
    if [[ ${FAILED_CHECKS} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# تابع اصلی
main() {
    echo "========================================="
    echo "    بررسی سلامت تونل و پروکسی"
    echo "========================================="
    echo

    log "INFO" "شروع بررسی سلامت..."

    # بررسی اتصال مستقیم
    check_direct_internet
    echo

    # بررسی سرویس‌ها
    check_service_status "gost-tunnel"
    check_resource_usage "gost-tunnel"
    echo

    # بررسی پورت‌ها
    check_port "127.0.0.1" "1080"
    check_port "127.0.0.1" "2087"
    check_port "127.0.0.1" "2052"
    echo

    # بررسی SOCKS5
    test_with_retry check_socks5_proxy "${SOCKS_PROXY}"
    echo

    # بررسی تاخیر
    check_latency "${SOCKS_PROXY}"
    echo

    # بررسی DNS
    check_dns_leak "${SOCKS_PROXY}"
    echo

    # نمایش خلاصه
    show_summary
}

# اجرای اصلی
main "$@"
```

### 3.2 Monitoring با Prometheus (اختیاری)

```bash
#!/bin/bash
# gost-prometheus-exporter.sh - export کردن metrics برای Prometheus

set -euo pipefail

readonly METRICS_FILE="/var/lib/node_exporter/textfile_collector/gost_metrics.prom"
readonly GOST_API="http://127.0.0.1:18080"

# ایجاد دایرکتوری در صورت عدم وجود
mkdir -p "$(dirname "${METRICS_FILE}")"

# جمع‌آوری metrics
collect_metrics() {
    local temp_file
    temp_file=$(mktemp)

    {
        echo "# HELP gost_tunnel_up GOST tunnel service status (1=up, 0=down)"
        echo "# TYPE gost_tunnel_up gauge"
        if systemctl is-active --quiet gost-tunnel; then
            echo "gost_tunnel_up 1"
        else
            echo "gost_tunnel_up 0"
        fi

        echo "# HELP gost_active_connections Active SOCKS5 connections"
        echo "# TYPE gost_active_connections gauge"
        local conn_count
        conn_count=$(ss -tn state established '( dport = :1080 or sport = :1080 )' | wc -l)
        echo "gost_active_connections ${conn_count}"

        echo "# HELP gost_proxy_latency_ms Proxy latency in milliseconds"
        echo "# TYPE gost_proxy_latency_ms gauge"
        local start end latency
        start=$(date +%s%N)
        if curl -s --max-time 5 --socks5-hostname 127.0.0.1:1080 https://api.ipify.org > /dev/null 2>&1; then
            end=$(date +%s%N)
            latency=$(( (end - start) / 1000000 ))
            echo "gost_proxy_latency_ms ${latency}"
        else
            echo "gost_proxy_latency_ms -1"
        fi

    } > "${temp_file}"

    mv "${temp_file}" "${METRICS_FILE}"
}

collect_metrics
```

---

## 4. ایجاد و انتقال فایل‌های Zip

### 4.1 اسکریپت بک‌آپ و فشرده‌سازی امن

```bash
#!/bin/bash
# backup-tunnel-config.sh - بک‌آپ امن پیکربندی تونل

set -euo pipefail

readonly BACKUP_DIR="/var/backups/tunnel"
readonly CONFIG_DIRS=(
    "/etc/gost"
    "/etc/systemd/system/gost*.service"
    "/etc/ufw"
)
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_NAME="tunnel-config-${TIMESTAMP}"
readonly ENCRYPTION_PASSWORD_FILE="/root/.tunnel_backup_password"

# رنگ‌ها
red() { echo -e "\033[0;31m$*\033[0m"; }
green() { echo -e "\033[0;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

# بررسی ابزارهای مورد نیاز
check_dependencies() {
    local deps=("zip" "gpg")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "${dep}" &> /dev/null; then
            missing+=("${dep}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        red "خطا: ابزارهای زیر نصب نیستند: ${missing[*]}"
        echo "برای نصب: sudo apt install ${missing[*]}"
        exit 1
    fi
}

# ایجاد رمز عبور برای رمزنگاری
setup_encryption_password() {
    if [[ ! -f "${ENCRYPTION_PASSWORD_FILE}" ]]; then
        yellow "ایجاد رمز عبور برای رمزنگاری بک‌آپ..."
        tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32 > "${ENCRYPTION_PASSWORD_FILE}"
        chmod 600 "${ENCRYPTION_PASSWORD_FILE}"
        green "رمز عبور ایجاد شد: ${ENCRYPTION_PASSWORD_FILE}"
        echo "لطفاً این رمز را در مکان امن ذخیره کنید!"
        cat "${ENCRYPTION_PASSWORD_FILE}"
        read -p "Press Enter to continue..."
    fi
}

# ایجاد بک‌آپ
create_backup() {
    green "شروع فرآیند بک‌آپ..."

    # ایجاد دایرکتوری موقت
    local temp_dir
    temp_dir=$(mktemp -d)
    local backup_content="${temp_dir}/${BACKUP_NAME}"
    mkdir -p "${backup_content}"

    # کپی فایل‌های پیکربندی
    for config_path in "${CONFIG_DIRS[@]}"; do
        if [[ -e ${config_path} ]]; then
            green "کپی ${config_path}..."
            cp -r "${config_path}" "${backup_content}/" 2>/dev/null || true
        else
            yellow "پوشه ${config_path} وجود ندارد، رد شد"
        fi
    done

    # افزودن اطلاعات سیستم
    {
        echo "=== System Information ==="
        echo "Hostname: $(hostname)"
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "IP: $(hostname -I | awk '{print $1}')"
        echo
        echo "=== Installed Packages ==="
        dpkg -l | grep -E 'gost|socat|haproxy|ufw' || echo "None"
        echo
        echo "=== Active Services ==="
        systemctl list-units --type=service --state=running | grep -E 'gost|socat|haproxy' || echo "None"
    } > "${backup_content}/system_info.txt"

    # ایجاد فایل zip
    green "ایجاد آرشیو zip..."
    local zip_file="${BACKUP_DIR}/${BACKUP_NAME}.zip"
    mkdir -p "${BACKUP_DIR}"

    cd "${temp_dir}"
    zip -r -q -9 "${zip_file}" "${BACKUP_NAME}/"

    # بررسی موفقیت
    if [[ -f "${zip_file}" ]]; then
        green "✓ فایل zip ایجاد شد: ${zip_file}"
        ls -lh "${zip_file}"
    else
        red "✗ خطا در ایجاد فایل zip"
        exit 1
    fi

    # رمزنگاری با GPG
    green "رمزنگاری فایل با GPG..."
    gpg --batch --yes \
        --passphrase-file "${ENCRYPTION_PASSWORD_FILE}" \
        --symmetric --cipher-algo AES256 \
        "${zip_file}"

    if [[ -f "${zip_file}.gpg" ]]; then
        green "✓ فایل رمزنگاری شد: ${zip_file}.gpg"
        rm -f "${zip_file}"  # حذف فایل رمزنگاری نشده
        ls -lh "${zip_file}.gpg"
    else
        red "✗ خطا در رمزنگاری"
        exit 1
    fi

    # پاکسازی
    rm -rf "${temp_dir}"

    green "بک‌آپ با موفقیت ایجاد شد!"
    echo "فایل بک‌آپ: ${zip_file}.gpg"
    echo "برای بازیابی:"
    echo "  gpg --decrypt ${zip_file}.gpg > ${BACKUP_NAME}.zip"
    echo "  unzip ${BACKUP_NAME}.zip"
}

# پاکسازی بک‌آپ‌های قدیمی
cleanup_old_backups() {
    local retention_days="${1:-7}"
    green "پاکسازی بک‌آپ‌های قدیمی‌تر از ${retention_days} روز..."

    find "${BACKUP_DIR}" -name "tunnel-config-*.zip.gpg" -mtime +${retention_days} -delete
    green "پاکسازی انجام شد"
}

# بازیابی بک‌آپ
restore_backup() {
    local backup_file="$1"

    if [[ ! -f "${backup_file}" ]]; then
        red "خطا: فایل بک‌آپ یافت نشد: ${backup_file}"
        exit 1
    fi

    green "بازیابی از ${backup_file}..."

    # رمزگشایی
    local decrypted_file="${backup_file%.gpg}"
    gpg --batch --yes \
        --passphrase-file "${ENCRYPTION_PASSWORD_FILE}" \
        --decrypt "${backup_file}" > "${decrypted_file}"

    # استخراج
    local restore_dir="/tmp/tunnel-restore-$(date +%s)"
    mkdir -p "${restore_dir}"
    unzip -q "${decrypted_file}" -d "${restore_dir}"

    green "فایل‌ها استخراج شدند در: ${restore_dir}"
    echo "برای بازگردانی، فایل‌ها را به محل اصلی کپی کنید"

    # پاکسازی فایل رمزگشایی شده
    rm -f "${decrypted_file}"
}

# انتقال امن به سرور دیگر
transfer_backup() {
    local backup_file="$1"
    local remote_host="$2"
    local remote_user="${3:-root}"

    green "انتقال ${backup_file} به ${remote_user}@${remote_host}..."

    # استفاده از SCP با فشرده‌سازی
    scp -C "${backup_file}" "${remote_user}@${remote_host}:/tmp/"

    if [[ $? -eq 0 ]]; then
        green "✓ انتقال موفق بود"
    else
        red "✗ خطا در انتقال"
        exit 1
    fi
}

# نمایش راهنما
show_usage() {
    echo "استفاده: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  backup              ایجاد بک‌آپ جدید"
    echo "  restore <file>      بازیابی از فایل بک‌آپ"
    echo "  cleanup [days]      پاکسازی بک‌آپ‌های قدیمی (پیش‌فرض: 7 روز)"
    echo "  transfer <file> <host> [user]  انتقال بک‌آپ به سرور دیگر"
    echo "  list                لیست بک‌آپ‌های موجود"
}

# لیست بک‌آپ‌ها
list_backups() {
    green "لیست بک‌آپ‌های موجود:"
    if [[ -d "${BACKUP_DIR}" ]]; then
        ls -lh "${BACKUP_DIR}"/tunnel-config-*.zip.gpg 2>/dev/null || echo "هیچ بک‌آپی یافت نشد"
    else
        yellow "دایرکتوری بک‌آپ وجود ندارد"
    fi
}

# تابع اصلی
main() {
    check_dependencies

    case "${1:-}" in
        backup)
            setup_encryption_password
            create_backup
            cleanup_old_backups 7
            ;;
        restore)
            [[ -z "${2:-}" ]] && { red "خطا: مسیر فایل بک‌آپ را مشخص کنید"; exit 1; }
            restore_backup "$2"
            ;;
        cleanup)
            cleanup_old_backups "${2:-7}"
            ;;
        transfer)
            [[ -z "${2:-}" || -z "${3:-}" ]] && { red "خطا: مسیر فایل و هاست را مشخص کنید"; exit 1; }
            transfer_backup "$2" "$3" "${4:-root}"
            ;;
        list)
            list_backups
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
```

---

## 5. اتوماسیون Firewall (UFW/iptables)

### 5.1 مدیریت پورت‌ها با UFW

```bash
#!/bin/bash
# firewall-manager.sh - مدیریت اتوماتیک فایروال

set -euo pipefail

# کدهای خروج
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2

# رنگ‌ها
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# لاگ
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# بررسی نصب UFW
check_ufw() {
    if ! command -v ufw &> /dev/null; then
        error "UFW نصب نیست"
        echo "برای نصب: sudo apt install ufw"
        exit ${EXIT_ERROR}
    fi
}

# فعال‌سازی UFW
enable_ufw() {
    log "فعال‌سازی UFW..."

    # اطمینان از باز بودن SSH
    ufw allow 22/tcp comment 'SSH access'

    # فعال‌سازی
    echo "y" | ufw enable

    if ufw status | grep -q "Status: active"; then
        log "UFW با موفقیت فعال شد"
    else
        error "خطا در فعال‌سازی UFW"
        exit ${EXIT_ERROR}
    fi
}

# غیرفعال‌سازی UFW
disable_ufw() {
    log "غیرفعال‌سازی UFW..."
    ufw disable
    log "UFW غیرفعال شد"
}

# افزودن قانون
add_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    local source_ip="${3:-any}"
    local comment="${4:-Manual rule}"

    log "افزودن قانون: port=${port}, protocol=${protocol}, source=${source_ip}"

    if [[ "${source_ip}" == "any" ]]; then
        ufw allow "${port}/${protocol}" comment "${comment}"
    else
        ufw allow from "${source_ip}" to any port "${port}" proto "${protocol}" comment "${comment}"
    fi

    log "قانون با موفقیت اضافه شد"
}

# حذف قانون
remove_rule() {
    local port="$1"
    local protocol="${2:-tcp}"

    log "حذف قانون برای پورت ${port}/${protocol}..."

    # دریافت شماره قانون
    local rule_number
    rule_number=$(ufw status numbered | grep "${port}/${protocol}" | head -1 | awk -F'[][]' '{print $2}')

    if [[ -n "${rule_number}" ]]; then
        echo "y" | ufw delete "${rule_number}"
        log "قانون حذف شد"
    else
        warning "قانونی برای پورت ${port}/${protocol} یافت نشد"
    fi
}

# باز کردن پورت‌های تونل
open_tunnel_ports() {
    log "باز کردن پورت‌های تونل..."

    local ports=(
        "1080:tcp:SOCKS5 proxy"
        "2087:tcp:Tunnel forward 2087"
        "2052:tcp:Tunnel forward 2052"
    )

    for port_config in "${ports[@]}"; do
        IFS=':' read -r port protocol comment <<< "${port_config}"
        add_rule "${port}" "${protocol}" "any" "${comment}"
    done

    log "همه پورت‌های تونل باز شدند"
}

# بستن پورت‌های تونل
close_tunnel_ports() {
    log "بستن پورت‌های تونل..."

    local ports=("1080" "2087" "2052")

    for port in "${ports[@]}"; do
        remove_rule "${port}" "tcp"
    done

    log "پورت‌های تونل بسته شدند"
}

# محدود کردن دسترسی به IP خاص
limit_to_ip() {
    local port="$1"
    local allowed_ip="$2"
    local protocol="${3:-tcp}"

    log "محدود کردن پورت ${port} به IP ${allowed_ip}..."

    # حذف قوانین قبلی
    remove_rule "${port}" "${protocol}"

    # افزودن قانون جدید
    add_rule "${port}" "${protocol}" "${allowed_ip}" "Limited access to ${allowed_ip}"
}

# محدودیت rate limiting
apply_rate_limit() {
    local port="$1"
    local protocol="${2:-tcp}"

    log "اعمال rate limiting روی پورت ${port}..."

    ufw limit "${port}/${protocol}" comment "Rate limited"
    log "Rate limiting اعمال شد"
}

# نمایش وضعیت
show_status() {
    echo -e "${BLUE}=== وضعیت Firewall ===${NC}"
    ufw status verbose

    echo -e "\n${BLUE}=== قوانین به صورت شماره‌دار ===${NC}"
    ufw status numbered
}

# پشتیبان‌گیری از قوانین
backup_rules() {
    local backup_file="/var/backups/ufw/rules-$(date +%Y%m%d_%H%M%S).bak"
    mkdir -p "$(dirname "${backup_file}")"

    log "پشتیبان‌گیری از قوانین فایروال..."

    # ذخیره قوانین IPv4 و IPv6
    cp /etc/ufw/user.rules "${backup_file}.ipv4"
    cp /etc/ufw/user6.rules "${backup_file}.ipv6"

    # ذخیره تنظیمات اصلی
    cp /etc/default/ufw "${backup_file}.default"

    log "پشتیبان ذخیره شد در: ${backup_file}.*"
}

# بازیابی قوانین
restore_rules() {
    local backup_file="$1"

    if [[ ! -f "${backup_file}.ipv4" ]]; then
        error "فایل بک‌آپ یافت نشد: ${backup_file}.ipv4"
        exit ${EXIT_ERROR}
    fi

    log "بازیابی قوانین از ${backup_file}..."

    # توقف UFW
    ufw disable

    # بازیابی فایل‌ها
    cp "${backup_file}.ipv4" /etc/ufw/user.rules
    cp "${backup_file}.ipv6" /etc/ufw/user6.rules
    [[ -f "${backup_file}.default" ]] && cp "${backup_file}.default" /etc/default/ufw

    # راه‌اندازی مجدد
    ufw enable

    log "قوانین با موفقیت بازیابی شدند"
}

# ریست کامل
reset_firewall() {
    warning "این عملیات تمام قوانین فایروال را حذف می‌کند!"
    read -p "آیا مطمئن هستید؟ (yes/no): " confirm

    if [[ "${confirm}" == "yes" ]]; then
        log "ریست کردن فایروال..."
        echo "y" | ufw reset
        log "فایروال ریست شد"
    else
        log "عملیات لغو شد"
    fi
}

# پیکربندی پیش‌فرض امن
setup_default_config() {
    log "تنظیم پیکربندی پیش‌فرض امن..."

    # پیش‌فرض‌ها
    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny routed

    # SSH
    ufw allow 22/tcp comment 'SSH'

    # مسدود کردن ping (اختیاری)
    # sed -i 's/^-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT$/-A ufw-before-input -p icmp --icmp-type echo-request -j DROP/' /etc/ufw/before.rules

    # فعال کردن logging
    ufw logging medium

    log "پیکربندی پیش‌فرض اعمال شد"
}

# مسدود کردن IP
block_ip() {
    local ip="$1"
    local comment="${2:-Blocked IP}"

    log "مسدود کردن IP: ${ip}..."
    ufw deny from "${ip}" comment "${comment}"
    log "IP ${ip} مسدود شد"
}

# رفع مسدودیت IP
unblock_ip() {
    local ip="$1"

    log "رفع مسدودیت IP: ${ip}..."

    local rule_number
    rule_number=$(ufw status numbered | grep "${ip}" | head -1 | awk -F'[][]' '{print $2}')

    if [[ -n "${rule_number}" ]]; then
        echo "y" | ufw delete "${rule_number}"
        log "مسدودیت IP ${ip} رفع شد"
    else
        warning "قانونی برای IP ${ip} یافت نشد"
    fi
}

# نمایش راهنما
show_usage() {
    cat << EOF
استفاده: $0 <command> [options]

Commands:
  enable                  فعال‌سازی UFW
  disable                 غیرفعال‌سازی UFW
  status                  نمایش وضعیت
  add <port> [proto] [ip] افزودن قانون
  remove <port> [proto]   حذف قانون
  open-tunnel             باز کردن پورت‌های تونل
  close-tunnel            بستن پورت‌های تونل
  limit-to <port> <ip>    محدود کردن به IP
  rate-limit <port>       اعمال rate limiting
  block <ip>              مسدود کردن IP
  unblock <ip>            رفع مسدودیت IP
  backup                  پشتیبان‌گیری از قوانین
  restore <file>          بازیابی قوانین
  reset                   ریست کامل فایروال
  setup-default           تنظیم پیکربندی پیش‌فرض امن

مثال‌ها:
  $0 add 8080 tcp
  $0 limit-to 1080 192.168.1.100
  $0 block 1.2.3.4
  $0 open-tunnel
EOF
}

# تابع اصلی
main() {
    [[ $EUID -ne 0 ]] && { error "این اسکریپت باید با sudo اجرا شود"; exit ${EXIT_ERROR}; }

    check_ufw

    case "${1:-}" in
        enable)
            enable_ufw
            ;;
        disable)
            disable_ufw
            ;;
        status)
            show_status
            ;;
        add)
            [[ $# -lt 2 ]] && { error "پورت را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            add_rule "${2}" "${3:-tcp}" "${4:-any}" "${5:-Manual rule}"
            ;;
        remove)
            [[ $# -lt 2 ]] && { error "پورت را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            remove_rule "${2}" "${3:-tcp}"
            ;;
        open-tunnel)
            open_tunnel_ports
            ;;
        close-tunnel)
            close_tunnel_ports
            ;;
        limit-to)
            [[ $# -lt 3 ]] && { error "پورت و IP را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            limit_to_ip "${2}" "${3}" "${4:-tcp}"
            ;;
        rate-limit)
            [[ $# -lt 2 ]] && { error "پورت را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            apply_rate_limit "${2}" "${3:-tcp}"
            ;;
        block)
            [[ $# -lt 2 ]] && { error "IP را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            block_ip "${2}" "${3:-Blocked IP}"
            ;;
        unblock)
            [[ $# -lt 2 ]] && { error "IP را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            unblock_ip "${2}"
            ;;
        backup)
            backup_rules
            ;;
        restore)
            [[ $# -lt 2 ]] && { error "مسیر فایل بک‌آپ را مشخص کنید"; exit ${EXIT_INVALID_ARGS}; }
            restore_rules "${2}"
            ;;
        reset)
            reset_firewall
            ;;
        setup-default)
            setup_default_config
            ;;
        *)
            show_usage
            exit ${EXIT_INVALID_ARGS}
            ;;
    esac
}

main "$@"
```

---

## 6. تشخیص نصب ابزارها

```bash
#!/bin/bash
# check-tools.sh - بررسی نصب و نسخه ابزارها

set -euo pipefail

# رنگ‌ها
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# آرایه ابزارها
declare -A TOOLS=(
    ["gost"]="GOST Tunnel"
    ["socat"]="Socat Network Tool"
    ["haproxy"]="HAProxy Load Balancer"
    ["ufw"]="Uncomplicated Firewall"
    ["iptables"]="IPTables Firewall"
    ["curl"]="cURL HTTP Client"
    ["wget"]="Wget Download Tool"
    ["jq"]="JSON Processor"
    ["systemctl"]="Systemd Control"
)

# بررسی نصب بودن
is_installed() {
    command -v "$1" &> /dev/null
}

# دریافت نسخه
get_version() {
    local tool="$1"
    local version="نامشخص"

    case "${tool}" in
        gost)
            if is_installed gost; then
                version=$(gost -V 2>&1 | head -1 || echo "نامشخص")
            fi
            ;;
        socat)
            if is_installed socat; then
                version=$(socat -V 2>&1 | head -1 | awk '{print $2}' || echo "نامشخص")
            fi
            ;;
        haproxy)
            if is_installed haproxy; then
                version=$(haproxy -v 2>&1 | head -1 | awk '{print $3}' || echo "نامشخص")
            fi
            ;;
        ufw)
            if is_installed ufw; then
                version=$(ufw version 2>&1 | head -1 | awk '{print $2}' || echo "نامشخص")
            fi
            ;;
        iptables)
            if is_installed iptables; then
                version=$(iptables --version 2>&1 | awk '{print $2}' || echo "نامشخص")
            fi
            ;;
        curl)
            if is_installed curl; then
                version=$(curl --version 2>&1 | head -1 | awk '{print $2}' || echo "نامشخص")
            fi
            ;;
        *)
            if is_installed "${tool}"; then
                version=$("${tool}" --version 2>&1 | head -1 || echo "نصب شده")
            fi
            ;;
    esac

    echo "${version}"
}

# نمایش وضعیت ابزار
check_tool() {
    local tool="$1"
    local description="$2"

    printf "%-20s %-30s " "${description}" "${tool}"

    if is_installed "${tool}"; then
        local version
        version=$(get_version "${tool}")
        echo -e "${GREEN}✓ نصب شده${NC} - نسخه: ${version}"
        return 0
    else
        echo -e "${RED}✗ نصب نشده${NC}"
        return 1
    fi
}

# پیشنهاد نصب
suggest_installation() {
    local tool="$1"

    case "${tool}" in
        gost)
            cat << 'EOF'
برای نصب GOST:
  # آخرین نسخه را از GitHub دانلود کنید
  wget -qO- https://github.com/go-gost/gost/releases/download/v3.0.0-rc10/gost_3.0.0-rc10_linux_amd64.tar.gz | tar xz
  sudo mv gost /usr/local/bin/
  sudo chmod +x /usr/local/bin/gost
EOF
            ;;
        socat)
            echo "  sudo apt install socat"
            ;;
        haproxy)
            cat << 'EOF'
  # نسخه پیش‌فرض
  sudo apt install haproxy

  # یا آخرین نسخه LTS از PPA
  sudo add-apt-repository ppa:vbernat/haproxy-3.0
  sudo apt update && sudo apt install haproxy
EOF
            ;;
        ufw)
            echo "  sudo apt install ufw"
            ;;
        *)
            echo "  sudo apt install ${tool}"
            ;;
    esac
}

# بررسی همه ابزارها
check_all_tools() {
    echo -e "${BLUE}=== بررسی ابزارهای نصب شده ===${NC}\n"

    local installed_count=0
    local total_count=${#TOOLS[@]}
    local missing_tools=()

    for tool in "${!TOOLS[@]}"; do
        if check_tool "${tool}" "${TOOLS[$tool]}"; then
            ((installed_count++))
        else
            missing_tools+=("${tool}")
        fi
    done

    echo
    echo -e "${BLUE}=== خلاصه ===${NC}"
    echo "تعداد کل: ${total_count}"
    echo -e "${GREEN}نصب شده: ${installed_count}${NC}"
    echo -e "${RED}نصب نشده: $((total_count - installed_count))${NC}"

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo
        echo -e "${YELLOW}=== ابزارهای نصب نشده ===${NC}"
        for tool in "${missing_tools[@]}"; do
            echo
            echo -e "${YELLOW}${tool}:${NC}"
            suggest_installation "${tool}"
        done
    fi
}

# بررسی یک ابزار خاص
check_specific_tool() {
    local tool="$1"

    if [[ -n "${TOOLS[$tool]:-}" ]]; then
        if check_tool "${tool}" "${TOOLS[$tool]}"; then
            exit 0
        else
            echo
            suggest_installation "${tool}"
            exit 1
        fi
    else
        echo -e "${RED}ابزار نامعتبر: ${tool}${NC}" >&2
        echo "ابزارهای قابل بررسی: ${!TOOLS[*]}"
        exit 2
    fi
}

# بررسی سرویس‌های systemd
check_services() {
    echo -e "${BLUE}=== بررسی سرویس‌های Systemd ===${NC}\n"

    local services=("gost-tunnel" "haproxy" "ufw")

    for service in "${services[@]}"; do
        printf "%-30s " "${service}"

        if systemctl list-unit-files | grep -q "^${service}.service"; then
            if systemctl is-active --quiet "${service}"; then
                echo -e "${GREEN}✓ فعال و در حال اجرا${NC}"
            elif systemctl is-enabled --quiet "${service}"; then
                echo -e "${YELLOW}! فعال اما متوقف${NC}"
            else
                echo -e "${YELLOW}! نصب شده اما غیرفعال${NC}"
            fi
        else
            echo -e "${RED}✗ سرویس یافت نشد${NC}"
        fi
    done
}

# نمایش اطلاعات سیستم
show_system_info() {
    echo -e "${BLUE}=== اطلاعات سیستم ===${NC}\n"

    echo "سیستم عامل: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
    echo "کرنل: $(uname -r)"
    echo "معماری: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "IP: $(hostname -I | awk '{print $1}')"
    echo
}

# تابع اصلی
main() {
    if [[ $# -eq 0 ]]; then
        show_system_info
        check_all_tools
        echo
        check_services
    else
        case "$1" in
            --all|-a)
                show_system_info
                check_all_tools
                echo
                check_services
                ;;
            --services|-s)
                check_services
                ;;
            --system|-S)
                show_system_info
                ;;
            *)
                check_specific_tool "$1"
                ;;
        esac
    fi
}

main "$@"
```

---

## 7. Error Handling و Logging

### 7.1 کتابخانه Error Handling پیشرفته

```bash
#!/bin/bash
# error-handler-lib.sh - کتابخانه مدیریت خطا

# Exit codes
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_INVALID_ARGS=2
readonly E_PERMISSION_DENIED=3
readonly E_NOT_FOUND=4
readonly E_NETWORK_ERROR=5
readonly E_TIMEOUT=6
readonly E_CONFIG_ERROR=7

# Log levels
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3
readonly LOG_FATAL=4

# تنظیمات logging
LOG_FILE="${LOG_FILE:-/var/log/script.log}"
LOG_LEVEL="${LOG_LEVEL:-${LOG_INFO}}"
ENABLE_SYSLOG="${ENABLE_SYSLOG:-false}"

# رنگ‌ها
readonly COLOR_DEBUG='\033[0;36m'    # Cyan
readonly COLOR_INFO='\033[0;32m'     # Green
readonly COLOR_WARN='\033[1;33m'     # Yellow
readonly COLOR_ERROR='\033[0;31m'    # Red
readonly COLOR_FATAL='\033[1;31m'    # Bold Red
readonly COLOR_RESET='\033[0m'

# نام‌های سطح log
declare -A LOG_LEVEL_NAMES=(
    [${LOG_DEBUG}]="DEBUG"
    [${LOG_INFO}]="INFO"
    [${LOG_WARN}]="WARN"
    [${LOG_ERROR}]="ERROR"
    [${LOG_FATAL}]="FATAL"
)

# رنگ‌های سطح log
declare -A LOG_LEVEL_COLORS=(
    [${LOG_DEBUG}]="${COLOR_DEBUG}"
    [${LOG_INFO}]="${COLOR_INFO}"
    [${LOG_WARN}]="${COLOR_WARN}"
    [${LOG_ERROR}]="${COLOR_ERROR}"
    [${LOG_FATAL}]="${COLOR_FATAL}"
)

# تابع اصلی logging
log_message() {
    local level=$1
    shift
    local message="$*"

    # بررسی سطح log
    if [[ ${level} -lt ${LOG_LEVEL} ]]; then
        return 0
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    local level_name="${LOG_LEVEL_NAMES[${level}]}"
    local level_color="${LOG_LEVEL_COLORS[${level}]}"

    # محل فراخوانی
    local caller_info=""
    if [[ ${level} -ge ${LOG_WARN} ]]; then
        caller_info="[${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}:${FUNCNAME[2]}]"
    fi

    # فرمت پیام
    local log_entry="[${timestamp}] [${level_name}] ${caller_info} ${message}"

    # خروجی به terminal با رنگ
    if [[ -t 1 ]]; then
        echo -e "${level_color}${log_entry}${COLOR_RESET}"
    else
        echo "${log_entry}"
    fi

    # خروجی به فایل
    if [[ -n "${LOG_FILE}" ]]; then
        echo "${log_entry}" >> "${LOG_FILE}" 2>/dev/null || true
    fi

    # خروجی به syslog
    if [[ "${ENABLE_SYSLOG}" == "true" ]] && command -v logger &> /dev/null; then
        local syslog_priority
        case ${level} in
            ${LOG_DEBUG}) syslog_priority="debug" ;;
            ${LOG_INFO})  syslog_priority="info" ;;
            ${LOG_WARN})  syslog_priority="warning" ;;
            ${LOG_ERROR}) syslog_priority="err" ;;
            ${LOG_FATAL}) syslog_priority="crit" ;;
        esac
        logger -t "$(basename "$0")" -p "user.${syslog_priority}" "${message}"
    fi
}

# توابع کمکی logging
log_debug() { log_message ${LOG_DEBUG} "$@"; }
log_info()  { log_message ${LOG_INFO} "$@"; }
log_warn()  { log_message ${LOG_WARN} "$@"; }
log_error() { log_message ${LOG_ERROR} "$@"; }
log_fatal() { log_message ${LOG_FATAL} "$@"; }

# مدیریت خطا با خروج
die() {
    local exit_code="${1:-${E_GENERAL}}"
    shift
    log_fatal "$@"
    exit "${exit_code}"
}

# نمایش stack trace
print_stack_trace() {
    log_error "Stack trace:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done | while read -r line func file; do
        log_error "  at ${func} (${file}:${line})"
    done
}

# Error handler برای trap
error_handler() {
    local exit_code=$?
    local line_number=$1

    log_error "خطا در خط ${line_number} با کد خروج ${exit_code}"
    print_stack_trace

    # cleanup در صورت نیاز
    if declare -F cleanup &>/dev/null; then
        log_info "اجرای cleanup..."
        cleanup
    fi

    exit "${exit_code}"
}

# فعال‌سازی error handling
enable_error_handling() {
    set -euo pipefail
    trap 'error_handler ${LINENO}' ERR
    trap cleanup EXIT
}

# Validation helpers
require_root() {
    if [[ $EUID -ne 0 ]]; then
        die ${E_PERMISSION_DENIED} "این اسکریپت باید با دسترسی root اجرا شود"
    fi
}

require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &> /dev/null; then
        die ${E_NOT_FOUND} "دستور مورد نیاز یافت نشد: ${cmd}"
    fi
}

require_file() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        die ${E_NOT_FOUND} "فایل یافت نشد: ${file}"
    fi
}

require_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        die ${E_NOT_FOUND} "دایرکتوری یافت نشد: ${dir}"
    fi
}

# Retry mechanism
retry() {
    local max_attempts="${1}"
    local delay="${2}"
    shift 2
    local cmd=("$@")
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log_info "تلاش ${attempt}/${max_attempts}: ${cmd[*]}"

        if "${cmd[@]}"; then
            log_info "دستور با موفقیت اجرا شد"
            return 0
        fi

        if [[ ${attempt} -lt ${max_attempts} ]]; then
            log_warn "تلاش ناموفق بود، انتظار ${delay} ثانیه..."
            sleep "${delay}"
        fi

        ((attempt++))
    done

    log_error "دستور پس از ${max_attempts} تلاش ناموفق بود"
    return 1
}

# مثال استفاده
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # تنظیمات
    LOG_FILE="/tmp/test-error-handling.log"
    LOG_LEVEL=${LOG_DEBUG}

    # فعال‌سازی error handling
    enable_error_handling

    # cleanup function
    cleanup() {
        log_info "پاکسازی..."
    }

    # تست‌ها
    log_debug "این یک پیام debug است"
    log_info "این یک پیام info است"
    log_warn "این یک هشدار است"
    log_error "این یک خطا است"

    # تست retry
    retry 3 2 ls /nonexistent || log_warn "دستور ناموفق بود"

    # تست validation
    require_command "bash"
    # require_root  # این خطا می‌دهد اگر با root نباشد

    log_info "تمام تست‌ها موفق بودند"
fi
```

---

## 8. Auto-Update از GitHub

```bash
#!/bin/bash
# self-update.sh - مکانیزم به‌روزرسانی خودکار

set -euo pipefail

# تنظیمات
readonly GITHUB_REPO="username/repo-name"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly VERSION_FILE="/var/lib/tunnel-script/version"
readonly UPDATE_CHECK_INTERVAL=86400  # 24 ساعت

# رنگ‌ها
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# دریافت نسخه فعلی
get_current_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}"
    else
        echo "0.0.0"
    fi
}

# دریافت آخرین نسخه از GitHub
get_latest_version() {
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

    if ! command -v jq &> /dev/null; then
        # بدون jq - استفاده از grep
        curl -s "${api_url}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
    else
        # با jq
        curl -s "${api_url}" | jq -r '.tag_name' | sed 's/^v//'
    fi
}

# مقایسه نسخه‌ها
version_gt() {
    local ver1="$1"
    local ver2="$2"

    # تبدیل به آرایه
    IFS='.' read -ra ver1_parts <<< "${ver1}"
    IFS='.' read -ra ver2_parts <<< "${ver2}"

    # مقایسه
    for i in {0..2}; do
        local v1="${ver1_parts[$i]:-0}"
        local v2="${ver2_parts[$i]:-0}"

        if [[ ${v1} -gt ${v2} ]]; then
            return 0
        elif [[ ${v1} -lt ${v2} ]]; then
            return 1
        fi
    done

    return 1
}

# بررسی نیاز به به‌روزرسانی
check_update_needed() {
    local last_check_file="/var/lib/tunnel-script/last_check"
    local current_time
    current_time=$(date +%s)

    # بررسی زمان آخرین چک
    if [[ -f "${last_check_file}" ]]; then
        local last_check
        last_check=$(cat "${last_check_file}")
        local elapsed=$((current_time - last_check))

        if [[ ${elapsed} -lt ${UPDATE_CHECK_INTERVAL} ]]; then
            log_info "آخرین بررسی اخیراً انجام شده است"
            return 1
        fi
    fi

    # ذخیره زمان چک فعلی
    mkdir -p "$(dirname "${last_check_file}")"
    echo "${current_time}" > "${last_check_file}"

    return 0
}

# دانلود و نصب به‌روزرسانی
download_and_install() {
    local version="$1"
    local download_url="https://raw.githubusercontent.com/${GITHUB_REPO}/v${version}/${SCRIPT_NAME}"

    log_info "در حال دانلود نسخه ${version}..."

    # ایجاد فایل موقت
    local temp_file
    temp_file=$(mktemp)

    # دانلود
    if ! curl -fsSL "${download_url}" -o "${temp_file}"; then
        log_error "خطا در دانلود فایل"
        rm -f "${temp_file}"
        return 1
    fi

    # بررسی اعتبار (syntax check)
    if ! bash -n "${temp_file}"; then
        log_error "فایل دانلود شده معتبر نیست"
        rm -f "${temp_file}"
        return 1
    fi

    # پشتیبان از نسخه فعلی
    local backup_file="${SCRIPT_PATH}.backup"
    cp "${SCRIPT_PATH}" "${backup_file}"
    log_info "پشتیبان ذخیره شد: ${backup_file}"

    # جایگزینی فایل
    if mv "${temp_file}" "${SCRIPT_PATH}"; then
        chmod +x "${SCRIPT_PATH}"

        # ذخیره نسخه جدید
        mkdir -p "$(dirname "${VERSION_FILE}")"
        echo "${version}" > "${VERSION_FILE}"

        log_info "به‌روزرسانی با موفقیت نصب شد!"
        return 0
    else
        log_error "خطا در نصب به‌روزرسانی"
        # بازگردانی از backup
        mv "${backup_file}" "${SCRIPT_PATH}"
        return 1
    fi
}

# بررسی و اعمال به‌روزرسانی
check_for_updates() {
    local force="${1:-false}"

    if [[ "${force}" != "true" ]] && ! check_update_needed; then
        return 0
    fi

    log_info "بررسی به‌روزرسانی..."

    local current_version
    current_version=$(get_current_version)
    log_info "نسخه فعلی: ${current_version}"

    local latest_version
    latest_version=$(get_latest_version)

    if [[ -z "${latest_version}" ]]; then
        log_warn "نتوانستیم آخرین نسخه را بررسی کنیم"
        return 1
    fi

    log_info "آخرین نسخه: ${latest_version}"

    if version_gt "${latest_version}" "${current_version}"; then
        log_info "نسخه جدید موجود است!"

        if [[ "${force}" == "true" ]]; then
            download_and_install "${latest_version}"
            return $?
        else
            echo
            read -p "آیا می‌خواهید به نسخه ${latest_version} به‌روزرسانی کنید؟ (y/n): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                download_and_install "${latest_version}"

                if [[ $? -eq 0 ]]; then
                    log_info "لطفاً اسکریپت را مجدداً اجرا کنید"
                    exit 0
                fi
            else
                log_info "به‌روزرسانی لغو شد"
            fi
        fi
    else
        log_info "شما از آخرین نسخه استفاده می‌کنید"
    fi
}

# به‌روزرسانی خودکار (برای cron)
auto_update() {
    log_info "اجرای به‌روزرسانی خودکار..."

    if check_for_updates true; then
        log_info "به‌روزرسانی با موفقیت انجام شد"

        # راه‌اندازی مجدد سرویس در صورت نیاز
        if systemctl is-active --quiet gost-tunnel; then
            log_info "راه‌اندازی مجدد سرویس..."
            systemctl restart gost-tunnel
        fi
    fi
}

# نصب cron job برای به‌روزرسانی خودکار
install_auto_update() {
    local cron_file="/etc/cron.daily/tunnel-auto-update"

    cat > "${cron_file}" << EOF
#!/bin/bash
# Auto-update script for tunnel management

${SCRIPT_PATH} --auto-update >> /var/log/tunnel-auto-update.log 2>&1
EOF

    chmod +x "${cron_file}"
    log_info "به‌روزرسانی خودکار نصب شد: ${cron_file}"
}

# حذف cron job
uninstall_auto_update() {
    local cron_file="/etc/cron.daily/tunnel-auto-update"

    if [[ -f "${cron_file}" ]]; then
        rm -f "${cron_file}"
        log_info "به‌روزرسانی خودکار حذف شد"
    else
        log_warn "به‌روزرسانی خودکار نصب نبود"
    fi
}

# نمایش راهنما
show_usage() {
    cat << EOF
استفاده: $0 [options]

Options:
  --check-update          بررسی دستی به‌روزرسانی
  --force-update          به‌روزرسانی اجباری
  --auto-update           به‌روزرسانی خودکار (برای cron)
  --install-auto-update   نصب به‌روزرسانی خودکار روزانه
  --uninstall-auto-update حذف به‌روزرسانی خودکار
  --version               نمایش نسخه فعلی
  --help                  نمایش این راهنما

مثال‌ها:
  $0 --check-update
  $0 --force-update
  sudo $0 --install-auto-update
EOF
}

# تابع اصلی
main() {
    case "${1:-}" in
        --check-update)
            check_for_updates false
            ;;
        --force-update)
            check_for_updates true
            ;;
        --auto-update)
            auto_update
            ;;
        --install-auto-update)
            [[ $EUID -ne 0 ]] && { log_error "نیاز به دسترسی root"; exit 1; }
            install_auto_update
            ;;
        --uninstall-auto-update)
            [[ $EUID -ne 0 ]] && { log_error "نیاز به دسترسی root"; exit 1; }
            uninstall_auto_update
            ;;
        --version)
            echo "نسخه فعلی: $(get_current_version)"
            ;;
        --help)
            show_usage
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
```

---

## منابع و مراجع

### Systemd Management
- [SUSE Linux Enterprise Server - Managing systemd Services](https://documentation.suse.com/smart/systems-management/html/systemd-management/index.html)
- [Linux Bash - Understanding and using systemd services in Bash scripts](https://www.linuxbash.sh/post/understanding-and-using-systemd-services-in-bash-scripts)
- [LINUXMIND.DEV - All About systemd: Start, Stop, and Manage Services](https://linuxmind.dev/2025/09/02/all-about-systemd-start-stop-and-manage-services/)

### GOST Authentication
- [GOST Authentication Documentation](https://gost.run/en/concepts/auth/)
- [GitHub - ginuerzh/gost README](https://github.com/ginuerzh/gost/blob/master/README_en.md)
- [GOST HTTP Tutorial](https://gost.run/en/tutorials/protocols/http/)

### Proxy Health Checking
- [UMA Technology - Advanced Proxy Configurations](https://umatechnology.org/advanced-proxy-configurations-for-advanced-bash-automation-deployed-in-24-7-environments/)
- [GitHub - PeterDaveHello/ProxyScrape.sh](https://github.com/PeterDaveHello/ProxyScrape.sh)

### Firewall Management
- [Ubuntu Wiki - UncomplicatedFirewall](https://wiki.ubuntu.com/UncomplicatedFirewall)
- [DigitalOcean - UFW Essentials](https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands)
- [Linux Bash - Understanding and Configuring UFW Firewall](https://www.linuxbash.sh/post/understanding-and-configuring-ufw-firewall)

### Error Handling & Logging
- [MoldStud - Best Practices for Error Handling in Bash](https://moldstud.com/articles/p-best-practices-and-techniques-for-error-handling-in-bash-scripts)
- [DevOps Training Institute - Logging and Error Handling](https://www.devopstraininginstitute.com/blog/how-do-you-log-and-handle-errors-gracefully-in-shell-scripting)
- [CLIMB - 10 Bash Script Logging Best Practices](https://climbtheladder.com/10-bash-script-logging-best-practices/)

### Self-Update Mechanisms
- [GitHub - SCOTTY0101/bash-script-auto-update](https://github.com/SCOTTY0101/bash-script-auto-update)
- [GitHub Gist - Self-updating bash script](https://gist.github.com/cubedtear/54434fc66439fc4e04e28bd658189701)

### Secure Archives
- [W3Schools - Bash zip Command](https://www.w3schools.com/bash/bash_zip.php)
- [Hostinger - SSH compression](https://www.hostinger.com/tutorials/how-to-extract-or-make-archives-via-ssh)
- [TecMint - Create Password Protected ZIP File](https://www.tecmint.com/create-password-protected-zip-file-in-linux/)

---

## نتیجه‌گیری

این مستند شامل تمام ابزارها و تکنیک‌های مورد نیاز برای ساخت یک سیستم مدیریت تونل حرفه‌ای است:

1. **مدیریت سرویس‌ها**: ایجاد، نظارت، و کنترل کامل سرویس‌های systemd
2. **احراز هویت**: مدیریت کاربران GOST با فایل‌های credential امن
3. **مانیتورینگ**: بررسی سلامت، latency، و DNS leak detection
4. **بک‌آپ امن**: فشرده‌سازی و رمزنگاری با GPG
5. **فایروال**: اتوماسیون کامل UFW با قابلیت‌های پیشرفته
6. **تشخیص ابزارها**: بررسی خودکار نصب و نسخه‌ها
7. **Error Handling**: سیستم logging حرفه‌ای با stack trace
8. **Auto-Update**: به‌روزرسانی خودکار از GitHub

تمام اسکریپت‌ها با استانداردهای 2024-2026 نوشته شده‌اند و شامل:
- `set -euo pipefail` برای امنیت
- Proper error handling با exit codes
- رنگ‌بندی خروجی برای خوانایی
- Documentation کامل
- مثال‌های کاربردی

فایل ذخیره شد در: `c:\Users\TS\Desktop\xtrtunnel\bash-best-practices-guide.md`
