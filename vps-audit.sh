#!/usr/bin/env bash

VPS_AUDIT_VERSION="0.2.0"

# Màu sắc cho đầu ra (Output)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # Không màu

# -----------------------------------------
# Cấu hình
# -----------------------------------------

# Các biến Thư mục/Tệp tin tĩnh phải thay đổi đúng với hệ thống thực tế
OS_RELEASE_FILE="/etc/os-release"
REBOOT_REQUIRED_FILE="/var/run/reboot-required"
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
AUTH_LOG_FILE="/var/log/auth.log"
SUDOERS_FILE="/etc/sudoers"
PASSWORD_QUALITY_CONF="/etc/security/pwquality.conf"
FAIL2BAN_CONFIG_DIR="/etc/fail2ban"

# Ngưỡng cảnh báo Tài nguyên (Đĩa/RAM/CPU %)
RESOURCE_WARN=50  # CẢNH BÁO nếu mức sử dụng >= 50%
RESOURCE_FAIL=80  # LỖI nếu mức sử dụng >= 80%

# Ngưỡng cảnh báo Dịch vụ đang chạy
SERVICES_WARN=20  # CẢNH BÁO nếu >= 20 dịch vụ đang chạy
SERVICES_FAIL=40  # LỖI nếu >= 40 dịch vụ đang chạy

# Ngưỡng Đăng nhập thất bại (Số lần)
LOGINS_WARN=10    # CẢNH BÁO nếu >= 10 lần đăng nhập sai
LOGINS_FAIL=50    # LỖI nếu >= 50 lần đăng nhập sai

# Ngưỡng Cổng đang mở (Số lượng)
OPEN_PORTS_WARN=10  # CẢNH BÁO nếu >= 10 cổng đang mở
OPEN_PORTS_FAIL=20  # LỖI nếu >= 20 cổng đang mở

# Chính sách Mật khẩu
PASSWORD_MINLEN=12  # ĐẠT (PASS) nếu pwquality minlen >= giá trị này

# Cấu hình Đầu ra Báo cáo

# Đặt tên Thư mục và Tệp
DEFAULT_REPORT_DIR="."   # Nơi lưu trữ báo cáo
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILENAME="vps-audit-report-${TIMESTAMP}.txt"
REPORT_FILE="${DEFAULT_REPORT_DIR}/${REPORT_FILENAME}"

# Quyền sở hữu (Ownership)
ENABLE_CHOWN=false  # Có thay đổi quyền sở hữu (chown) báo cáo hay không
# Mặc định thuộc về người dùng gọi sudo, để báo cáo không bị root sở hữu.
CHOWN_USER="${SUDO_USER:-$(id -un)}"
REPORT_CHOWN_OWNER="${CHOWN_USER}:$(id -gn "$CHOWN_USER" 2>/dev/null || id -gn)"

# Đảm bảo thư mục báo cáo tồn tại
if [ ! -d "$DEFAULT_REPORT_DIR" ]; then
    if mkdir -p "$DEFAULT_REPORT_DIR"; then
        # Chỉ áp dụng quyền sở hữu khi thư mục vừa được tạo
        if [ "$ENABLE_CHOWN" = true ]; then
            if ! chown "$REPORT_CHOWN_OWNER" "$DEFAULT_REPORT_DIR"; then
                echo -e "${RED}[LỖI] Không thể thay đổi quyền sở hữu của ${DEFAULT_REPORT_DIR}.${NC}" >&2
            fi
        fi
    else
        echo -e "${RED}[LỖI] Không thể tạo thư mục ${DEFAULT_REPORT_DIR}. Đang sử dụng thư mục hiện tại.${NC}" >&2
        DEFAULT_REPORT_DIR="."
        REPORT_FILE="./${REPORT_FILENAME}"
        ENABLE_CHOWN=false
    fi
fi

# -----------------------------------------
# Kết thúc Cấu hình
# -----------------------------------------

print_header() {
    local header="$1"
    echo -e "\n${BLUE}${BOLD}$header${NC}"
    echo -e "\n$header" >> "$REPORT_FILE"
    echo "================================" >> "$REPORT_FILE"
}

print_info() {
    local label="$1"
    local value="$2"
    echo -e "${BOLD}$label:${NC} $value"
    echo "$label: $value" >> "$REPORT_FILE"
}

# Bắt đầu kiểm tra (audit)
echo -e "${BLUE}${BOLD}Công cụ Kiểm tra Bảo mật VPS v${VPS_AUDIT_VERSION}${NC}"
echo -e "${GRAY}https://nuverlabs.com/vps-audit${NC}"
echo -e "${GRAY}Bắt đầu kiểm tra lúc $(date)${NC}\n"

echo "Công cụ Kiểm tra Bảo mật VPS v${VPS_AUDIT_VERSION}" > "$REPORT_FILE"
echo "https://nuverlabs.com/vps-audit" >> "$REPORT_FILE"
echo "Bắt đầu kiểm tra lúc $(date)" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

# Phần Thông tin Hệ thống
print_header "Thông tin Hệ thống"

# Lấy thông tin hệ thống
OS_INFO=$(grep PRETTY_NAME "$OS_RELEASE_FILE" | cut -d'"' -f2)
KERNEL_VERSION=$(uname -r)
HOSTNAME=$HOSTNAME
UPTIME=$(uptime -p)
UPTIME_SINCE=$(uptime -s)
CPU_INFO=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
TOTAL_DISK=$(df -h / | awk 'NR==2 {print $2}')
PUBLIC_IP=$(curl -s https://api.ipify.org)
LOAD_AVERAGE=$(uptime | awk -F'load average:' '{print $2}' | xargs)

# In thông tin hệ thống
print_info "Tên máy (Hostname)" "$HOSTNAME"
print_info "Hệ điều hành" "$OS_INFO"
print_info "Phiên bản Kernel" "$KERNEL_VERSION"
print_info "Thời gian hoạt động" "$UPTIME (từ $UPTIME_SINCE)"
print_info "Mô hình CPU" "$CPU_INFO"
print_info "Số nhân CPU" "$CPU_CORES"
print_info "Tổng Bộ nhớ (RAM)" "$TOTAL_MEM"
print_info "Tổng dung lượng Ổ cứng" "$TOTAL_DISK"
print_info "IP Công cộng" "$PUBLIC_IP"
print_info "Tải trung bình (Load)" "$LOAD_AVERAGE"

echo "" >> "$REPORT_FILE"

# Phần Kết quả Kiểm tra Bảo mật
print_header "Kết quả Kiểm tra Bảo mật"

# Hàm để kiểm tra và báo cáo với 3 trạng thái
check_security() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    case $status in
        "PASS")
            echo -e "${GREEN}[ĐẠT]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[ĐẠT] $test_name - $message" >> "$REPORT_FILE"
            ;;
        "WARN")
            echo -e "${YELLOW}[CẢNH BÁO]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[CẢNH BÁO] $test_name - $message" >> "$REPORT_FILE"
            ;;
        "FAIL")
            echo -e "${RED}[LỖI]${NC} $test_name ${GRAY}- $message${NC}"
            echo "[LỖI] $test_name - $message" >> "$REPORT_FILE"
            ;;
    esac
    echo "" >> "$REPORT_FILE"
}

# Kiểm tra thời gian hoạt động của hệ thống
UPTIME=$(uptime -p)
UPTIME_SINCE=$(uptime -s)
echo -e "\nThông tin Thời gian hoạt động:" >> "$REPORT_FILE"
echo "Thời gian hoạt động hiện tại: $UPTIME" >> "$REPORT_FILE"
echo "Hệ thống bật từ lúc: $UPTIME_SINCE" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo -e "Thời gian hoạt động: $UPTIME (từ $UPTIME_SINCE)"

# Kiểm tra xem hệ thống có cần khởi động lại không
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
    check_security "Khởi động lại Hệ thống" "WARN" "Hệ thống cần được khởi động lại để áp dụng các bản cập nhật"
else
    check_security "Khởi động lại Hệ thống" "PASS" "Không yêu cầu khởi động lại"
fi

# Kiểm tra ghi đè cấu hình SSH
SSH_CONFIG_OVERRIDES=$(grep "^Include" "$SSH_CONFIG_FILE" 2>/dev/null | awk '{print $2}')

# Kiểm tra đăng nhập Root qua SSH (Xử lý cả config chính và overrides)
if [ -n "$SSH_CONFIG_OVERRIDES" ] && [ -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_ROOT=$(grep "^PermitRootLogin" $SSH_CONFIG_OVERRIDES "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_ROOT=$(grep "^PermitRootLogin" "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_ROOT" ]; then
    SSH_ROOT="prohibit-password"
fi
if [ "$SSH_ROOT" = "no" ]; then
    check_security "Đăng nhập Root SSH" "PASS" "Đăng nhập Root đã được vô hiệu hóa an toàn trong cấu hình SSH"
else
    check_security "Đăng nhập Root SSH" "FAIL" "Đăng nhập Root hiện đang được phép - đây là một rủi ro bảo mật. Hãy tắt nó trong $SSH_CONFIG_FILE"
fi

# Kiểm tra xác thực mật khẩu SSH
if [ -n "$SSH_CONFIG_OVERRIDES" ] && [ -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_PASSWORD=$(grep "^PasswordAuthentication" $SSH_CONFIG_OVERRIDES "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_PASSWORD=$(grep "^PasswordAuthentication" "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_PASSWORD" ]; then
    SSH_PASSWORD="yes"
fi
if [ "$SSH_PASSWORD" = "no" ]; then
    check_security "Xác thực Mật khẩu SSH" "PASS" "Xác thực bằng mật khẩu đã bị vô hiệu hóa, chỉ cho phép dùng Khóa (Key-based)"
else
    check_security "Xác thực Mật khẩu SSH" "FAIL" "Xác thực bằng mật khẩu đang bật - cân nhắc chuyển sang chỉ sử dụng Khóa bảo mật (Key-based)"
fi

# Kiểm tra các cổng SSH mặc định/không an toàn 
UNPRIVILEGED_PORT_START=$(sysctl -n net.ipv4.ip_unprivileged_port_start)
SSH_PORT=""
if [ -n "$SSH_CONFIG_OVERRIDES" ] && [ -d "$(dirname "$SSH_CONFIG_OVERRIDES")" ]; then
    SSH_PORT=$(grep "^Port" $SSH_CONFIG_OVERRIDES "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
else
    SSH_PORT=$(grep "^Port" "$SSH_CONFIG_FILE" 2>/dev/null | head -1 | awk '{print $2}')
fi
if [ -z "$SSH_PORT" ]; then
    SSH_PORT="22"
fi

if [ "$SSH_PORT" = "22" ]; then
    check_security "Cổng SSH (Port)" "WARN" "Đang sử dụng cổng mặc định 22 - cân nhắc đổi sang cổng khác để tăng cường bảo mật"
elif [ "$SSH_PORT" -ge "$UNPRIVILEGED_PORT_START" ]; then
    check_security "Cổng SSH (Port)" "FAIL" "Đang sử dụng cổng không có đặc quyền $SSH_PORT - hãy dùng cổng dưới $UNPRIVILEGED_PORT_START để an toàn hơn"
else
    check_security "Cổng SSH (Port)" "PASS" "Đang sử dụng cổng không mặc định $SSH_PORT, điều này giúp ngăn chặn các đợt rà quét tự động"
fi

# Kiểm tra Trạng thái Tường lửa
check_firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -qw "active"; then
            check_security "Trạng thái Tường lửa (UFW)" "PASS" "Tường lửa UFW đang hoạt động và bảo vệ hệ thống"
        else
            check_security "Trạng thái Tường lửa (UFW)" "FAIL" "Tường lửa UFW không hoạt động - hệ thống của bạn đang bị phơi nhiễm trước các cuộc tấn công mạng"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            check_security "Trạng thái Tường lửa (firewalld)" "PASS" "Tường lửa Firewalld đang hoạt động và bảo vệ hệ thống"
        else
            check_security "Trạng thái Tường lửa (firewalld)" "FAIL" "Tường lửa Firewalld không hoạt động - hệ thống của bạn đang bị phơi nhiễm"
        fi
    elif command -v iptables >/dev/null 2>&1; then
        if iptables -L -n | grep -q "Chain INPUT"; then
            check_security "Trạng thái Tường lửa (iptables)" "PASS" "Các luật iptables đang hoạt động và bảo vệ hệ thống"
        else
            check_security "Trạng thái Tường lửa (iptables)" "FAIL" "Không tìm thấy luật iptables nào đang hoạt động - hệ thống có thể gặp nguy hiểm"
        fi
    elif command -v nft >/dev/null 2>&1; then
        if nft list ruleset | grep -q "table"; then
            check_security "Trạng thái Tường lửa (nftables)" "PASS" "Các luật nftables đang hoạt động và bảo vệ hệ thống"
        else
            check_security "Trạng thái Tường lửa (nftables)" "FAIL" "Không tìm thấy luật nftables nào đang hoạt động - hệ thống có thể gặp nguy hiểm"
        fi
    else
        check_security "Trạng thái Tường lửa" "FAIL" "Không tìm thấy công cụ tường lửa nào được cài đặt trên hệ thống này"
    fi
}

# Gọi hàm kiểm tra Tường lửa
check_firewall_status

# Kiểm tra cập nhật tự động (unattended-upgrades)
if dpkg -l | grep -q "unattended-upgrades"; then
    check_security "Cập nhật Tự động" "PASS" "Các bản cập nhật bảo mật tự động đã được cấu hình"
else
    check_security "Cập nhật Tự động" "FAIL" "Cập nhật bảo mật tự động chưa được cấu hình - hệ thống có thể bỏ lỡ các bản vá quan trọng"
fi

# Kiểm tra Hệ thống Ngăn chặn Xâm nhập (Fail2ban hoặc CrowdSec)
IPS_INSTALLED=0
IPS_ACTIVE=0

if dpkg -l | grep -q "fail2ban"; then
    IPS_INSTALLED=1
    systemctl is-active fail2ban >/dev/null 2>&1 && IPS_ACTIVE=1
fi

# Kiểm tra docker container chạy fail2ban
if command -v docker >/dev/null 2>&1; then
    if systemctl is-active --quiet docker; then
        if docker ps -a | awk '{print $2}' | grep "fail2ban" >/dev/null 2>&1; then
            IPS_INSTALLED=1
            docker ps | grep -q "fail2ban" && IPS_ACTIVE=1
        fi
    else
        check_security "Ngăn chặn Xâm nhập (IPS)" "WARN" "Docker đã cài đặt nhưng không chạy - không thể kiểm tra các container Fail2ban"
    fi
fi

if dpkg -l | grep -q "crowdsec"; then
    IPS_INSTALLED=1
    systemctl is-active crowdsec >/dev/null 2>&1 && IPS_ACTIVE=1
fi

# Kiểm tra docker container chạy crowdsec
if command -v docker >/dev/null 2>&1; then
    if systemctl is-active --quiet docker; then
        if docker ps -a | awk '{print $2}' | grep "crowdsec" >/dev/null 2>&1; then
            IPS_INSTALLED=1
            docker ps | grep -q "crowdsec" && IPS_ACTIVE=1
        fi
    else
        check_security "Ngăn chặn Xâm nhập (IPS)" "WARN" "Docker đã cài đặt nhưng không chạy - không thể kiểm tra các container CrowdSec"
    fi
fi

case "$IPS_INSTALLED$IPS_ACTIVE" in
    "11") check_security "Ngăn chặn Xâm nhập (IPS)" "PASS" "Fail2ban hoặc CrowdSec đã được cài đặt và đang chạy" ;;
    "10") check_security "Ngăn chặn Xâm nhập (IPS)" "WARN" "Fail2ban hoặc CrowdSec đã được cài đặt nhưng chưa hoạt động" ;;
    *)    check_security "Ngăn chặn Xâm nhập (IPS)" "FAIL" "Không có hệ thống ngăn chặn xâm nhập (Fail2ban hoặc CrowdSec) nào được cài đặt" ;;
esac

# Chuyển đổi mã thông báo (token) thành số cổng (vd: "ssh" thành "22")
resolve_port_token() {
    local token="$1"
    if [[ "$token" =~ ^[0-9]+$ ]]; then
        echo "$token"
    else
        getent services "$token" 2>/dev/null | head -1 | awk '{print $2}' | cut -d'/' -f1
    fi
}

# Kiểm tra xem danh sách cổng của fail2ban có bao gồm cổng được chỉ định không
port_list_contains() {
    local list="$1" target="$2" token start end resolved
    local IFS=','
    for token in $list; do
        token="${token//[[:space:]]/}"
        [ -z "$token" ] && continue
        if [[ "$token" == *:* ]]; then
            start=$(resolve_port_token "${token%%:*}")
            end=$(resolve_port_token "${token##*:}")
            if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
                if [ "$target" -ge "$start" ] && [ "$target" -le "$end" ]; then
                    return 0
                fi
            fi
        else
            resolved=$(resolve_port_token "$token")
            [ "$resolved" = "$target" ] && return 0
        fi
    done
    return 1
}

# Đọc tùy chọn từ phần jail (fail2ban)
get_jail_option() {
    local section="$1" option="$2" file value result=""
    for file in "$FAIL2BAN_CONFIG_DIR/jail.conf" \
                "$FAIL2BAN_CONFIG_DIR"/jail.d/*.conf \
                "$FAIL2BAN_CONFIG_DIR/jail.local" \
                "$FAIL2BAN_CONFIG_DIR"/jail.d/*.local; do
        [ -f "$file" ] || continue
        value=$(awk -v sect="$section" -v opt="$option" '
            $0 ~ /^[[:space:]]*\[/ {
                in_sect = ($0 ~ "^[[:space:]]*\\[" sect "\\][[:space:]]*$")
                next
            }
            in_sect && $0 ~ "^[[:space:]]*" opt "[[:space:]]*=" {
                sub(/^[^=]*=[[:space:]]*/, "")
                sub(/[[:space:]]+$/, "")
                val = $0
            }
            END { if (val != "") print val }
        ' "$file" 2>/dev/null)
        [ -n "$value" ] && result="$value"
    done
    echo "$result"
}

# Kiểm tra xem jail SSH của fail2ban có khớp với cổng SSH đang dùng hay không.
check_fail2ban_port_alignment() {
    if ! command -v fail2ban-client >/dev/null 2>&1 || [ ! -d "$FAIL2BAN_CONFIG_DIR" ]; then
        return
    fi

    local ssh_effective_port
    ssh_effective_port=$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')
    [ -z "$ssh_effective_port" ] && ssh_effective_port="$SSH_PORT"
    if ! [[ "$ssh_effective_port" =~ ^[0-9]+$ ]]; then
        check_security "Đồng bộ Cổng Fail2ban" "WARN" "Không thể xác định cổng SSH thực tế - vui lòng kiểm tra thủ công cổng jail của fail2ban"
        return
    fi

    local jail_enabled jail_port jail_banaction
    jail_enabled=$(get_jail_option "sshd" "enabled")
    jail_port=$(get_jail_option "sshd" "port")
    jail_banaction=$(get_jail_option "sshd" "banaction")
    [ -z "$jail_banaction" ] && jail_banaction=$(get_jail_option "DEFAULT" "banaction")
    [ -z "$jail_port" ] && jail_port="ssh"

    if [ "$jail_enabled" != "true" ]; then
        check_security "Đồng bộ Cổng Fail2ban" "WARN" "Jail [sshd] của fail2ban chưa được bật - các cuộc tấn công brute force vào SSH không bị chặn"
        return
    fi

    if [[ "$jail_banaction" == *allports* ]]; then
        check_security "Đồng bộ Cổng Fail2ban" "PASS" "Jail [sshd] cấm mọi cổng (banaction=$jail_banaction), vì vậy SSH trên cổng $ssh_effective_port đã được bảo vệ"
        return
    fi

    if port_list_contains "$jail_port" "$ssh_effective_port"; then
        check_security "Đồng bộ Cổng Fail2ban" "PASS" "Jail [sshd] của fail2ban đang bảo vệ cổng SSH thực tế là $ssh_effective_port"
    else
        check_security "Đồng bộ Cổng Fail2ban" "FAIL" "Jail [sshd] đang chặn cổng '$jail_port' nhưng SSH lại chạy trên $ssh_effective_port - việc chặn sẽ vô tác dụng. Hãy thiết lập 'port = $ssh_effective_port' trong $FAIL2BAN_CONFIG_DIR/jail.local, hoặc sử dụng banaction = nftables[type=allports]"
    fi
}

# Chạy kiểm tra đồng bộ cổng fail2ban
check_fail2ban_port_alignment

# Kiểm tra các nỗ lực đăng nhập thất bại
if [ -f "$AUTH_LOG_FILE" ]; then
    FAILED_LOGINS=$(grep -c "Failed password" "$AUTH_LOG_FILE" 2>/dev/null || echo 0)

# nếu bản debian > 10, thông tin nằm trong journalctl
elif [ -f "/etc/debian_version" ]; then
    DEB_VERSION=$(cut -d'.' -f1 /etc/debian_version)
    if [ "$DEB_VERSION" -gt 10 ]; then
        FAILED_LOGINS=$(journalctl -u ssh --since "24 hours ago" 2>/dev/null | grep -c "Failed password" || echo 0)
    else
        FAILED_LOGINS=0
        check_security "Nhật ký Xác thực (Auth Log)" "WARN" "Không tìm thấy hoặc không đọc được tệp $AUTH_LOG_FILE. Giả định có 0 lần đăng nhập thất bại."
    fi
else
    FAILED_LOGINS=0
    check_security "Nhật ký Xác thực (Auth Log)" "WARN" "Không tìm thấy hoặc không đọc được tệp $AUTH_LOG_FILE. Giả định có 0 lần đăng nhập thất bại."
fi

# Đảm bảo FAILED_LOGINS là số và xóa khoảng trắng
FAILED_LOGINS=$(echo "$FAILED_LOGINS" | tr -d '[:space:]')
FAILED_LOGINS=$((10#$FAILED_LOGINS))

if [ "$FAILED_LOGINS" -lt $LOGINS_WARN ]; then
    check_security "Đăng nhập Thất bại" "PASS" "Phát hiện $FAILED_LOGINS lần đăng nhập thất bại - ở mức bình thường"
elif [ "$FAILED_LOGINS" -lt $LOGINS_FAIL ]; then
    check_security "Đăng nhập Thất bại" "WARN" "Phát hiện $FAILED_LOGINS lần đăng nhập thất bại - có thể là dấu hiệu đang bị tấn công"
else
    check_security "Đăng nhập Thất bại" "FAIL" "Phát hiện $FAILED_LOGINS lần đăng nhập thất bại - có thể đang diễn ra cuộc tấn công brute force"
fi

# Kiểm tra cập nhật hệ thống
UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -P '^\d+ upgraded' | cut -d" " -f1)
if [ -z "$UPDATES" ]; then
    UPDATES=0
fi
if [ "$UPDATES" -eq 0 ]; then
    check_security "Cập nhật Hệ thống" "PASS" "Tất cả các gói hệ thống đã được cập nhật bản mới nhất"
else
    check_security "Cập nhật Hệ thống" "FAIL" "Có $UPDATES bản cập nhật bảo mật - hệ thống có thể bị dính các lỗ hổng đã biết"
fi

# Kiểm tra các dịch vụ đang chạy
SERVICES=$(systemctl list-units --type=service --state=running | grep -c "loaded active running")
if [ "$SERVICES" -lt $SERVICES_WARN ]; then
    check_security "Dịch vụ Đang chạy" "PASS" "Chạy tối thiểu các dịch vụ ($SERVICES) - tốt cho tính bảo mật"
elif [ "$SERVICES" -lt $SERVICES_FAIL ]; then
    check_security "Dịch vụ Đang chạy" "WARN" "Có $SERVICES dịch vụ đang chạy - cân nhắc giảm thiểu để tránh rủi ro"
else
    check_security "Dịch vụ Đang chạy" "FAIL" "Quá nhiều dịch vụ đang chạy ($SERVICES) - làm tăng bề mặt tấn công"
fi

# Kiểm tra các cổng sử dụng netstat hoặc ss
if command -v netstat >/dev/null 2>&1; then
    LISTENING_PORTS=$(netstat -tuln | grep LISTEN | awk '{print $4}')
elif command -v ss >/dev/null 2>&1; then
    LISTENING_PORTS=$(ss -tuln | grep LISTEN | awk '{print $5}')
else
    check_security "Quét Cổng (Port)" "FAIL" "Cả 'netstat' và 'ss' đều không có sẵn trên hệ thống này."
    LISTENING_PORTS=""
fi

# Xử lý LISTENING_PORTS để lấy các cổng công khai
if [ -n "$LISTENING_PORTS" ]; then
    PUBLIC_PORTS=$(echo "$LISTENING_PORTS" | awk -F':' '{print $NF}' | sort -n | uniq | tr '\n' ',' | sed 's/,$//')
    PORT_COUNT=$(echo "$PUBLIC_PORTS" | tr ',' '\n' | wc -w)
    INTERNET_PORTS=$(echo "$PUBLIC_PORTS" | tr ',' '\n' | wc -w)

    if [ "$PORT_COUNT" -lt $OPEN_PORTS_WARN ] && [ "$INTERNET_PORTS" -lt 3 ]; then
        check_security "Bảo mật Cổng" "PASS" "Cấu hình tốt (Tổng: $PORT_COUNT, Công khai: $INTERNET_PORTS cổng): $PUBLIC_PORTS"
    elif [ "$PORT_COUNT" -lt $OPEN_PORTS_FAIL ] && [ "$INTERNET_PORTS" -lt 5 ]; then
        check_security "Bảo mật Cổng" "WARN" "Đề nghị xem xét lại (Tổng: $PORT_COUNT, Công khai: $INTERNET_PORTS cổng): $PUBLIC_PORTS"
    else
        check_security "Bảo mật Cổng" "FAIL" "Mức độ phơi nhiễm cao (Tổng: $PORT_COUNT, Công khai: $INTERNET_PORTS cổng): $PUBLIC_PORTS"
    fi
else
    check_security "Quét Cổng (Port)" "WARN" "Việc quét cổng thất bại do thiếu công cụ. Vui lòng cài đặt 'ss' hoặc 'netstat'."
fi

# Hàm định dạng tin nhắn cho tệp báo cáo
format_for_report() {
    local message="$1"
    echo "$message" >> "$REPORT_FILE"
}

# Kiểm tra dung lượng Ổ cứng
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print int($5)}')
if [ "$DISK_USAGE" -lt $RESOURCE_WARN ]; then
    check_security "Dung lượng Ổ cứng" "PASS" "Dung lượng đĩa còn trống khỏe mạnh (Đã dùng ${DISK_USAGE}% - Đã dùng: ${DISK_USED}/${DISK_TOTAL}, Còn trống: ${DISK_AVAIL})"
elif [ "$DISK_USAGE" -lt $RESOURCE_FAIL ]; then
    check_security "Dung lượng Ổ cứng" "WARN" "Dung lượng đĩa ở mức trung bình (Đã dùng ${DISK_USAGE}% - Đã dùng: ${DISK_USED}/${DISK_TOTAL}, Còn trống: ${DISK_AVAIL})"
else
    check_security "Dung lượng Ổ cứng" "FAIL" "Dung lượng đĩa ở mức nguy hiểm (Đã dùng ${DISK_USAGE}% - Đã dùng: ${DISK_USED}/${DISK_TOTAL}, Còn trống: ${DISK_AVAIL})"
fi

# Kiểm tra dung lượng RAM
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
MEM_USAGE=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$MEM_USAGE" -lt $RESOURCE_WARN ]; then
    check_security "Sử dụng RAM" "PASS" "Bộ nhớ RAM khỏe mạnh (Đã dùng ${MEM_USAGE}% - Đã dùng: ${MEM_USED}/${MEM_TOTAL}, Còn trống: ${MEM_AVAIL})"
elif [ "$MEM_USAGE" -lt $RESOURCE_FAIL ]; then
    check_security "Sử dụng RAM" "WARN" "Bộ nhớ RAM ở mức trung bình (Đã dùng ${MEM_USAGE}% - Đã dùng: ${MEM_USED}/${MEM_TOTAL}, Còn trống: ${MEM_AVAIL})"
else
    check_security "Sử dụng RAM" "FAIL" "Bộ nhớ RAM ở mức nguy hiểm (Đã dùng ${MEM_USAGE}% - Đã dùng: ${MEM_USED}/${MEM_TOTAL}, Còn trống: ${MEM_AVAIL})"
fi

# Kiểm tra mức sử dụng CPU
CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2)}')
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print int($8)}')
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | awk -F',' '{ print $1 }' | tr -d ' ')
if [ "$CPU_USAGE" -lt $RESOURCE_WARN ]; then
    check_security "Sử dụng CPU" "PASS" "Mức sử dụng CPU khỏe mạnh (Đã dùng ${CPU_USAGE}% - Chạy: ${CPU_USAGE}%, Rỗi: ${CPU_IDLE}%, Tải: ${CPU_LOAD}, Số nhân: ${CPU_CORES})"
elif [ "$CPU_USAGE" -lt $RESOURCE_FAIL ]; then
    check_security "Sử dụng CPU" "WARN" "Mức sử dụng CPU trung bình (Đã dùng ${CPU_USAGE}% - Chạy: ${CPU_USAGE}%, Rỗi: ${CPU_IDLE}%, Tải: ${CPU_LOAD}, Số nhân: ${CPU_CORES})"
else
    check_security "Sử dụng CPU" "FAIL" "Mức sử dụng CPU nguy hiểm (Đã dùng ${CPU_USAGE}% - Chạy: ${CPU_USAGE}%, Rỗi: ${CPU_IDLE}%, Tải: ${CPU_LOAD}, Số nhân: ${CPU_CORES})"
fi

# Kiểm tra cấu hình sudo
if grep -q "^Defaults.*logfile" "$SUDOERS_FILE"; then
    check_security "Nhật ký Sudo" "PASS" "Các lệnh Sudo đang được lưu log để phục vụ kiểm toán"
else
    check_security "Nhật ký Sudo" "FAIL" "Các lệnh Sudo không được lưu log - làm giảm khả năng kiểm soát an ninh"
fi

# Kiểm tra chính sách mật khẩu
if [ -f "$PASSWORD_QUALITY_CONF" ]; then
    MINLEN_VALUE=$(grep -E '^[[:space:]]*minlen[[:space:]]*=' "$PASSWORD_QUALITY_CONF" | tail -1 | cut -d= -f2 | tr -d '[:space:]')
    if [ -z "$MINLEN_VALUE" ]; then
        check_security "Chính sách Mật khẩu" "FAIL" "Chưa cài đặt minlen trong $PASSWORD_QUALITY_CONF - hệ thống cho phép mật khẩu yếu"
    elif ! [[ "$MINLEN_VALUE" =~ ^[0-9]+$ ]]; then
        check_security "Chính sách Mật khẩu" "WARN" "Không thể phân tích giá trị minlen '$MINLEN_VALUE' trong $PASSWORD_QUALITY_CONF"
    elif [ "$MINLEN_VALUE" -ge "$PASSWORD_MINLEN" ]; then
        check_security "Chính sách Mật khẩu" "PASS" "Chính sách mật khẩu mạnh đang được áp dụng (độ dài tối thiểu=$MINLEN_VALUE)"
    else
        check_security "Chính sách Mật khẩu" "FAIL" "Chính sách mật khẩu yếu - độ dài tối thiểu=$MINLEN_VALUE dưới mức đề nghị là $PASSWORD_MINLEN"
    fi
else
    check_security "Chính sách Mật khẩu" "FAIL" "Không có chính sách mật khẩu nào được cấu hình - hệ thống cho phép mật khẩu yếu"
fi

# Kiểm tra các tệp SUID đáng ngờ
COMMON_SUID_PATHS='^/usr/bin/|^/bin/|^/sbin/|^/usr/sbin/|^/usr/lib|^/usr/libexec'
KNOWN_SUID_BINS='ping$|sudo$|mount$|umount$|su$|passwd$|chsh$|newgrp$|gpasswd$|chfn$'

SUID_FILES=$(find / -type f -perm -4000 2>/dev/null | \
    grep -v -E "$COMMON_SUID_PATHS" | \
    grep -v -E "$KNOWN_SUID_BINS" | \
    wc -l)

if [ "$SUID_FILES" -eq 0 ]; then
    check_security "Tệp SUID" "PASS" "Không tìm thấy tệp SUID đáng ngờ nào - tuân thủ tốt bảo mật"
else
    check_security "Tệp SUID" "WARN" "Tìm thấy $SUID_FILES tệp SUID nằm ngoài các vị trí tiêu chuẩn - vui lòng kiểm tra tính hợp lệ"
fi

# Thêm tóm tắt thông tin hệ thống vào báo cáo
echo "================================" >> "$REPORT_FILE"
echo "Tóm tắt Thông tin Hệ thống:" >> "$REPORT_FILE"
echo "Tên máy: $(hostname)" >> "$REPORT_FILE"
echo "Kernel: $(uname -r)" >> "$REPORT_FILE"
echo "Hệ điều hành: $(grep PRETTY_NAME "$OS_RELEASE_FILE" | cut -d'"' -f2)" >> "$REPORT_FILE"
echo "Số nhân CPU: $(nproc)" >> "$REPORT_FILE"
echo "Tổng Bộ nhớ RAM: $(free -h | awk '/^Mem:/ {print $2}')" >> "$REPORT_FILE"
echo "Tổng Dung lượng Ổ cứng: $(df -h / | awk 'NR==2 {print $2}')" >> "$REPORT_FILE"
echo "================================" >> "$REPORT_FILE"

echo -e "\nKiểm tra VPS hoàn tất. Báo cáo đầy đủ đã được lưu tại $REPORT_FILE"
echo -e "Vui lòng xem $REPORT_FILE để biết các khuyến nghị chi tiết."

# Thêm lời kết vào báo cáo
echo "================================" >> "$REPORT_FILE"
echo "Kết thúc Báo cáo Kiểm tra VPS" >> "$REPORT_FILE"
echo "Vui lòng xem xét tất cả các phần bị báo lỗi [LỖI] hoặc [CẢNH BÁO] và thực hiện các biện pháp khắc phục tương ứng." >> "$REPORT_FILE"

# Nếu bật chown, thiết lập lại quyền sở hữu cho tệp báo cáo
if [ "$ENABLE_CHOWN" = true ]; then
    if ! chown "$REPORT_CHOWN_OWNER" "$REPORT_FILE"; then
        echo -e "${RED}[LỖI] Không thể thay đổi quyền sở hữu của ${REPORT_FILE}." >&2
    fi
fi