#!/bin/bash
# ╔══════════════════════════════════════════════════════════════╗
#  ELITE-X DNSTT SCRIPT v3.3.1 - FALCON ENHANCED (NO 3PROXY)
#  + C EDNS Proxy (Multi-core, IPv4) + IPv6 Disabled
#  + BBR + 20MB Buffers + High Backlog + Nice -20
#  + Bandwidth GB Limits + Auto-Delete
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# VARIABLES
# ═══════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
ORANGE='\033[0;33m'
LIGHT_RED='\033[1;31m'
LIGHT_GREEN='\033[1;32m'
GRAY='\033[0;90m'
NC='\033[0m'

STATIC_PRIVATE_KEY="7f207e92ab7cb365aad1966b62d2cfbd3f450fe8e523a38ffc7ecfbcec315693"
STATIC_PUBLIC_KEY="40aa057fcb2574e1e9223ea46457f9fdf9d60a2a1c23da87602202d93b41aa04"
ACTIVATION_KEY="ELITE-X"
TIMEZONE="Africa/Dar_es_Salaam"

USER_DB="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
BANDWIDTH_DIR="/etc/elite-x/bandwidth"
PIDTRACK_DIR="$BANDWIDTH_DIR/pidtrack"
BANNED_DB="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
DELETED_DB="/etc/elite-x/deleted"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
EDNS_C_SOURCE="/usr/local/bin/dnstt-edns-proxy.c"
EDNS_C_BIN="/usr/local/bin/dnstt-edns-proxy"

# ═══════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════
show_banner() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}           ELITE-X SLOWDNS v3.3.1              ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${GREEN}${BOLD}    C Proxy • IPv6 Off • BBR • 20MB Buff •   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${CYAN}${BOLD}              TURBO BOOST EDITION - FULL OPTIMIZED            ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_color() { echo -e "${2}${1}${NC}"; }
set_timezone() { timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true; }

# ═══════════════════════════════════════════════════════════════
# KERNEL OPTIMIZATION + DISABLE IPv6 (SAFE VERSION)
# ═══════════════════════════════════════════════════════════════
optimize_kernel_and_disable_ipv6() {
    echo -e "${YELLOW}⚙️  Disabling IPv6 & Applying Kernel Optimizations...${NC}"

    # Disable IPv6 via sysctl
    cat >> /etc/sysctl.conf <<'SYSCTL'

# === ELITE-X: Disable IPv6 ===
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# === ELITE-X: BBR Congestion Control ===
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# === ELITE-X: UDP Buffers 20MB ===
net.core.rmem_max = 20971520
net.core.wmem_max = 20971520
net.ipv4.udp_rmem_min = 20971520
net.ipv4.udp_wmem_min = 20971520

# === ELITE-X: High Backlog ===
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535

# === ELITE-X: TCP Optimizations ===
net.ipv4.tcp_rmem = 4096 87380 20971520
net.ipv4.tcp_wmem = 4096 65536 20971520
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

SYSCTL

    echo -e "${YELLOW}   → Applying sysctl...${NC}"
    sysctl -p >/dev/null 2>&1 || true

    # Disable IPv6 in GRUB (safe)
    if [ -f /etc/default/grub ]; then
        if ! grep -q "ipv6.disable=1" /etc/default/grub 2>/dev/null; then
            echo -e "${YELLOW}   → Updating GRUB for IPv6 disable...${NC}"
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*/& ipv6.disable=1/' /etc/default/grub 2>/dev/null || true
            timeout 10 update-grub 2>/dev/null || true
        fi
    fi

    # Disable IPv6 systemd-networkd (safe)
    if [ -d /etc/systemd/network ]; then
        cat > /etc/systemd/network/10-no-ipv6.network <<NIPV6
[Network]
IPv6AcceptRA=false
LinkLocalAddressing=no
NIPV6
        timeout 5 systemctl restart systemd-networkd 2>/dev/null || true
    fi

    echo -e "${GREEN}✅ Kernel optimized & IPv6 disabled${NC}"
}

# ═══════════════════════════════════════════════════════════════
# C EDNS PROXY (Multi-core, IPv4 Only, SO_REUSEPORT)
# ═══════════════════════════════════════════════════════════════
create_c_edns_proxy() {
    echo -e "${YELLOW}🔧 Creating High-Performance C EDNS Proxy...${NC}"

    cat > "$EDNS_C_SOURCE" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>

#define LISTEN_PORT 53
#define BACKEND_PORT 5300
#define BACKEND_IP "127.0.0.1"
#define MAX_WORKERS 4
#define BUFFER_SIZE 4096
#define EDNS_OPT 41
#define TARGET_MTU 1800

static volatile int running = 1;

static void signal_handler(int sig) {
    (void)sig;
    running = 0;
}

static unsigned char *skip_name(unsigned char *ptr, unsigned char *end) {
    while (ptr < end) {
        if (*ptr == 0) return ptr + 1;
        if ((*ptr & 0xC0) == 0xC0) return ptr + 2;
        ptr += *ptr + 1;
    }
    return ptr;
}

static int modify_edns(unsigned char *buf, int len, int max_size) {
    if (len < 12) return len;
    unsigned char *ptr = buf + 12;
    unsigned char *end = buf + len;
    int i;

    unsigned short qdcount = (buf[4] << 8) | buf[5];
    unsigned short ancount = (buf[6] << 8) | buf[7];
    unsigned short nscount = (buf[8] << 8) | buf[9];
    unsigned short arcount = (buf[10] << 8) | buf[11];

    for (i = 0; i < qdcount && ptr < end; i++) {
        ptr = skip_name(ptr, end);
        if (ptr + 4 > end) return len;
        ptr += 4;
    }

    for (i = 0; i < (ancount + nscount) && ptr < end; i++) {
        ptr = skip_name(ptr, end);
        if (ptr + 10 > end) return len;
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }

    for (i = 0; i < arcount && ptr < end; i++) {
        ptr = skip_name(ptr, end);
        if (ptr + 10 > end) return len;
        unsigned short rtype = (ptr[0] << 8) | ptr[1];
        if (rtype == EDNS_OPT) {
            ptr[2] = (max_size >> 8) & 0xFF;
            ptr[3] = max_size & 0xFF;
            return len;
        }
        unsigned short rdlength = (ptr[8] << 8) | ptr[9];
        ptr += 10 + rdlength;
    }
    return len;
}

typedef struct {
    int listen_fd;
    struct sockaddr_in client_addr;
    socklen_t client_len;
    unsigned char buffer[BUFFER_SIZE];
    int len;
} worker_data_t;

static void *worker_thread(void *arg) {
    worker_data_t *data = (worker_data_t *)arg;
    int backend_fd;
    struct sockaddr_in backend_addr;
    struct timeval tv = {5, 0};
    unsigned char rbuf[BUFFER_SIZE];
    int rlen;

    backend_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (backend_fd < 0) {
        free(data);
        return NULL;
    }
    setsockopt(backend_fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    memset(&backend_addr, 0, sizeof(backend_addr));
    backend_addr.sin_family = AF_INET;
    backend_addr.sin_port = htons(BACKEND_PORT);
    inet_pton(AF_INET, BACKEND_IP, &backend_addr.sin_addr);

    int mlen = modify_edns(data->buffer, data->len, TARGET_MTU);
    sendto(backend_fd, data->buffer, mlen, 0,
           (struct sockaddr *)&backend_addr, sizeof(backend_addr));

    socklen_t blen = sizeof(backend_addr);
    rlen = recvfrom(backend_fd, rbuf, sizeof(rbuf), 0,
                    (struct sockaddr *)&backend_addr, &blen);

    if (rlen > 0) {
        rlen = modify_edns(rbuf, rlen, 512);
        sendto(data->listen_fd, rbuf, rlen, 0,
               (struct sockaddr *)&data->client_addr, data->client_len);
    }

    close(backend_fd);
    free(data);
    return NULL;
}

int main(void) {
    int listen_fd;
    struct sockaddr_in listen_addr;
    int optval = 1;

    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);

    listen_fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return 1;
    }

    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEPORT, &optval, sizeof(optval));
    setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval));

    memset(&listen_addr, 0, sizeof(listen_addr));
    listen_addr.sin_family = AF_INET;
    listen_addr.sin_addr.s_addr = INADDR_ANY;
    listen_addr.sin_port = htons(LISTEN_PORT);

    if (bind(listen_fd, (struct sockaddr *)&listen_addr, sizeof(listen_addr)) < 0) {
        perror("bind");
        close(listen_fd);
        return 1;
    }

    fprintf(stderr, "C EDNS Proxy started on port %d (IPv4 only, %d workers)\n",
            LISTEN_PORT, MAX_WORKERS);

    while (running) {
        worker_data_t *data = malloc(sizeof(worker_data_t));
        if (!data) continue;

        data->listen_fd = listen_fd;
        data->client_len = sizeof(data->client_addr);
        data->len = recvfrom(listen_fd, data->buffer, sizeof(data->buffer), 0,
                             (struct sockaddr *)&data->client_addr, &data->client_len);
        if (data->len <= 0) {
            free(data);
            continue;
        }

        pthread_t tid;
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        pthread_create(&tid, &attr, worker_thread, data);
        pthread_attr_destroy(&attr);
    }

    close(listen_fd);
    return 0;
}
CEOF

    echo -e "${YELLOW}🔨 Compiling C EDNS Proxy (gcc -Ofast -march=native -flto)...${NC}"
    gcc -Ofast -march=native -flto -pthread -o "$EDNS_C_BIN" "$EDNS_C_SOURCE" 2>/dev/null || true

    if [ -f "$EDNS_C_BIN" ] && [ -x "$EDNS_C_BIN" ]; then
        echo -e "${GREEN}✅ C EDNS Proxy compiled successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ C EDNS Proxy compilation failed - will use Python fallback${NC}"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════
# BANDWIDTH MONITOR
# ═══════════════════════════════════════════════════════════════
create_bandwidth_monitor() {
    cat > /usr/local/bin/elite-x-bandwidth <<'BWEOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
PID_DIR="$BW_DIR/pidtrack"
SCAN_INTERVAL=30

mkdir -p "$BW_DIR" "$PID_DIR"

while true; do
    current_ts=$(date +%s)
    declare -A uid_to_user=()
    declare -A session_pids=()
    declare -A loginuid_pids=()

    while IFS=: read -r username _ uid _rest; do
        [[ -n "$username" && "$uid" =~ ^[0-9]+$ ]] && uid_to_user["$uid"]="$username"
    done < /etc/passwd

    while read -r ssh_pid ssh_owner; do
        [[ "$ssh_pid" =~ ^[0-9]+$ ]] || continue
        if [[ -n "$ssh_owner" && "$ssh_owner" != "root" && "$ssh_owner" != "sshd" ]]; then
            session_pids["$ssh_owner"]+="$ssh_pid "
        fi
    done < <(ps -C sshd -o pid=,user= 2>/dev/null)

    for p in /proc/[0-9]*/loginuid; do
        [[ -f "$p" ]] || continue
        login_uid=""
        read -r login_uid < "$p" || login_uid=""
        [[ "$login_uid" =~ ^[0-9]+$ && "$login_uid" != "4294967295" ]] || continue

        session_user="${uid_to_user[$login_uid]}"
        [[ -n "$session_user" ]] || continue

        pid_dir=$(dirname "$p")
        pid_num=$(basename "$pid_dir")
        comm=""
        read -r comm < "$pid_dir/comm" || comm=""
        [[ "$comm" == "sshd" ]] || continue

        ppid_val=""
        while read -r key value; do
            if [[ "$key" == "PPid:" ]]; then
                ppid_val="${value:-}"
                break
            fi
        done < "$pid_dir/status"
        [[ "$ppid_val" == "1" ]] && continue

        loginuid_pids["$session_user"]+="$pid_num "
    done

    for user_file in "$USER_DB"/*; do
        [[ -f "$user_file" ]] || continue
        username=$(basename "$user_file")

        bandwidth_gb=$(grep "Bandwidth_GB:" "$user_file" 2>/dev/null | awk '{print $2}')
        [[ -z "$bandwidth_gb" || "$bandwidth_gb" == "0" ]] && continue

        declare -A unique_pids=()
        pid_candidates=""
        [[ -n "${session_pids[$username]}" ]] && pid_candidates="${session_pids[$username]}"
        [[ -z "$pid_candidates" ]] && pid_candidates="${loginuid_pids[$username]}"

        for pid in $pid_candidates; do
            [[ "$pid" =~ ^[0-9]+$ ]] && unique_pids["$pid"]=1
        done

        if (( ${#unique_pids[@]} == 0 )); then
            rm -f "$PID_DIR/${username}__"*.last 2>/dev/null
            continue
        fi

        usagefile="$BW_DIR/${username}.usage"
        accumulated=0
        [[ -f "$usagefile" ]] && { read -r accumulated < "$usagefile"; [[ "$accumulated" =~ ^[0-9]+$ ]] || accumulated=0; }

        delta_total=0
        for pid in "${!unique_pids[@]}"; do
            io_file="/proc/$pid/io"
            cur=0
            if [[ -r "$io_file" ]]; then
                rchar=0; wchar=0
                while read -r key value; do
                    case "$key" in
                        rchar:) rchar=${value:-0} ;;
                        wchar:) wchar=${value:-0} ;;
                    esac
                done < "$io_file"
                cur=$((rchar + wchar))
            fi

            pidfile="$PID_DIR/${username}__${pid}.last"
            if [[ -f "$pidfile" ]]; then
                read -r prev < "$pidfile"
                [[ "$prev" =~ ^[0-9]+$ ]] || prev=0
                d=$(( cur >= prev ? cur - prev : cur ))
                delta_total=$((delta_total + d))
            fi
            printf "%s\n" "$cur" > "$pidfile"
        done

        for f in "$PID_DIR/${username}__"*.last; do
            [[ -f "$f" ]] || continue
            fpid=${f##*__}; fpid=${fpid%.last}
            [[ -d "/proc/$fpid" ]] || rm -f "$f"
        done

        new_total=$((accumulated + delta_total))
        printf "%s\n" "$new_total" > "$usagefile"

        quota_bytes=$(awk "BEGIN {printf \"%.0f\", $bandwidth_gb * 1073741824}")
        if [[ "$quota_bytes" =~ ^[0-9]+$ ]] && (( new_total >= quota_bytes )); then
            if ! passwd -S "$username" 2>/dev/null | grep -q "L"; then
                usermod -L "$username" 2>/dev/null
                killall -u "$username" -9 2>/dev/null
                echo "$(date '+%Y-%m-%d %H:%M:%S') - BLOCKED: Bandwidth quota exceeded (${bandwidth_gb}GB)" >> "/etc/elite-x/banned/$username"
            fi
        fi
    done

    sleep "$SCAN_INTERVAL"
done
BWEOF
    chmod +x /usr/local/bin/elite-x-bandwidth

    cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X Bandwidth Monitor (GB Limits)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-bandwidth
Restart=always
RestartSec=10
Nice=10
IOSchedulingClass=best-effort
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# CONNECTION MONITOR WITH AUTO-DELETE
# ═══════════════════════════════════════════════════════════════
create_connection_monitor() {
    cat > /usr/local/bin/elite-x-connmon <<'CONNEOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
BANNED_DB="/etc/elite-x/banned"
DELETED_DB="/etc/elite-x/deleted"
BW_DIR="/etc/elite-x/bandwidth"
PID_DIR="$BW_DIR/pidtrack"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
CONN_DB="/etc/elite-x/connections"
mkdir -p "$CONN_DB" "$BANNED_DB" "$DELETED_DB"

get_connection_count() {
    local username=$1
    local count=0
    who | grep -qw "$username" 2>/dev/null && count=$(who | grep -wc "$username" 2>/dev/null)
    [ "$count" -eq 0 ] && count=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    echo ${count:-0}
}

delete_expired_user() {
    local username=$1
    local reason=$2

    cp "$USER_DB/$username" "$DELETED_DB/${username}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    pkill -u "$username" 2>/dev/null || true
    killall -u "$username" -9 2>/dev/null || true
    userdel -r "$username" 2>/dev/null || true

    rm -f "$USER_DB/$username"
    rm -f "/etc/elite-x/data_usage/$username"
    rm -f "$CONN_DB/$username"
    rm -f "$BANNED_DB/$username"
    rm -f "$BW_DIR/${username}.usage"
    rm -f "$PID_DIR/${username}__"*.last 2>/dev/null

    logger -t "elite-x" "Auto-deleted user: $username ($reason)"
}

while true; do
    current_ts=$(date +%s)

    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] || continue
            username=$(basename "$user_file")

            if ! id "$username" &>/dev/null; then
                rm -f "$USER_DB/$username"
                continue
            fi

            expire_date=$(grep "Expire:" "$user_file" 2>/dev/null | awk '{print $2}')
            if [ -n "$expire_date" ]; then
                expire_ts=$(date -d "$expire_date" +%s 2>/dev/null || echo 0)
                if [ "$expire_ts" -gt 0 ] && [ "$current_ts" -gt "$expire_ts" ]; then
                    delete_expired_user "$username" "Account expired on $expire_date"
                    continue
                fi
            fi

            conn_limit=$(grep "Conn_Limit:" "$user_file" 2>/dev/null | awk '{print $2}')
            conn_limit=${conn_limit:-1}
            current_conn=$(get_connection_count "$username")
            echo "$current_conn" > "$CONN_DB/$username"

            autoban=$(cat "$AUTOBAN_FLAG" 2>/dev/null || echo "0")
            is_locked=$(passwd -S "$username" 2>/dev/null | grep -q "L" && echo "yes" || echo "no")

            if [ "$current_conn" -gt "$conn_limit" ] && [ "$is_locked" = "no" ] && [ "$autoban" = "1" ]; then
                usermod -L "$username" 2>/dev/null
                pkill -u "$username" 2>/dev/null || true
                echo "$(date) - BLOCKED: Exceeded connection limit ($current_conn/$conn_limit)" >> "$BANNED_DB/$username"
            fi
        done
    fi
    sleep 5
done
CONNEOF
    chmod +x /usr/local/bin/elite-x-connmon

    cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X Connection Monitor (Auto-Ban + Auto-Delete)
After=network.target ssh.service

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-connmon
Restart=always
RestartSec=5
CPUQuota=20%
MemoryMax=50M

[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# DATA USAGE MONITOR
# ═══════════════════════════════════════════════════════════════
create_data_usage_monitor() {
    cat > /usr/local/bin/elite-x-datausage <<'DATAEOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
BW_DIR="/etc/elite-x/bandwidth"
mkdir -p "$USAGE_DB" "$BW_DIR"
CURRENT_MONTH=$(date +%Y-%m)

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            [ -f "$user_file" ] || continue
            username=$(basename "$user_file")

            USAGE_FILE="$USAGE_DB/$username"
            BW_USAGE="$BW_DIR/${username}.usage"

            total_gb="0.00"
            if [ -f "$BW_USAGE" ]; then
                total_bytes=$(cat "$BW_USAGE" 2>/dev/null || echo 0)
                total_gb=$(echo "scale=2; $total_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")
            fi

            cat > "$USAGE_FILE" <<INFO
month: $CURRENT_MONTH
total_gb: $total_gb
last_updated: $(date)
INFO
        done
    fi
    sleep 30
done
DATAEOF
    chmod +x /usr/local/bin/elite-x-datausage

    cat > /etc/systemd/system/elite-x-datausage.service <<EOF
[Unit]
Description=ELITE-X Monthly Data Usage Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-datausage
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

# ═══════════════════════════════════════════════════════════════
# USER MANAGEMENT SCRIPT
# ═══════════════════════════════════════════════════════════════
create_user_script() {
    cat > /usr/local/bin/elite-x-user <<'USEREOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
WHITE='\033[1;37m';BOLD='\033[1m';ORANGE='\033[0;33m'
LIGHT_RED='\033[1;31m';LIGHT_GREEN='\033[1;32m';PURPLE='\033[0;35m';GRAY='\033[0;90m';NC='\033[0m'

UD="/etc/elite-x/users"
USAGE_DB="/etc/elite-x/data_usage"
DD="/etc/elite-x/deleted"
BD="/etc/elite-x/banned"
CONN_DB="/etc/elite-x/connections"
BW_DIR="/etc/elite-x/bandwidth"
PID_DIR="$BW_DIR/pidtrack"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"
mkdir -p "$UD" "$USAGE_DB" "$DD" "$BD" "$CONN_DB" "$BW_DIR" "$PID_DIR"

get_connection_count() {
    local username="$1"
    local count=0
    who | grep -qw "$username" 2>/dev/null && count=$(who | grep -wc "$username" 2>/dev/null)
    [ "$count" -eq 0 ] && count=$(ps aux | grep "sshd:" | grep "$username" | grep -v grep | grep -v "sshd:.*@notty" | wc -l)
    echo ${count:-0}
}

get_bandwidth_usage() {
    local username="$1"
    local bw_file="$BW_DIR/${username}.usage"
    if [ -f "$bw_file" ]; then
        local total_bytes=$(cat "$bw_file" 2>/dev/null || echo 0)
        echo "scale=2; $total_bytes / 1073741824" | bc 2>/dev/null || echo "0.00"
    else
        echo "0.00"
    fi
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER           ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"

    read -p "$(echo -e $GREEN"Username: "$NC)" username
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        return
    fi

    read -p "$(echo -e $GREEN"Password [auto-generate]: "$NC)" password
    [ -z "$password" ] && password=$(head /dev/urandom | tr -dc 'A-Za-z0-9' | head -c 8) && echo -e "${GREEN}🔑 Generated: ${YELLOW}$password${NC}"

    read -p "$(echo -e $GREEN"Expire (days) [30]: "$NC)" days; days=${days:-30}
    [[ ! "$days" =~ ^[0-9]+$ ]] && { echo -e "${RED}Invalid days!${NC}"; return; }

    read -p "$(echo -e $GREEN"Connection limit [1]: "$NC)" conn_limit; conn_limit=${conn_limit:-1}
    [[ ! "$conn_limit" =~ ^[0-9]+$ ]] && conn_limit=1

    read -p "$(echo -e $GREEN"Bandwidth limit in GB (0 = unlimited) [0]: "$NC)" bandwidth_gb; bandwidth_gb=${bandwidth_gb:-0}
    [[ ! "$bandwidth_gb" =~ ^[0-9]+\.?[0-9]*$ ]] && bandwidth_gb=0

    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"

    cat > "$UD/$username" <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Bandwidth_GB: $bandwidth_gb
Created: $(date +"%Y-%m-%d %H:%M:%S")
INFO

    echo "0" > "$BW_DIR/${username}.usage"

    local bw_disp="Unlimited"; [ "$bandwidth_gb" != "0" ] && bw_disp="${bandwidth_gb} GB"
    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")

    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER CREATED SUCCESSFULLY                    ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username   :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password   :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server     :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Expire     :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login  :${CYAN} $conn_limit${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth  :${CYAN} $bw_disp${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

list_users() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                    ACTIVE USERS                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"

    if [ -z "$(ls -A "$UD" 2>/dev/null)" ]; then
        echo -e "${CYAN}║${RED}                                    No users found                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        return
    fi

    printf "${CYAN}║${WHITE} %-14s %-12s %-8s %-14s %-18s${CYAN} ║${NC}\n" "USERNAME" "EXPIRE" "LOGIN" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}╟──────────────────────────────────────────────────────────────────────────────────────────────────╢${NC}"

    for user in "$UD"/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(grep "Expire:" "$user" | cut -d' ' -f2)
        limit=$(grep "Conn_Limit:" "$user" | awk '{print $2}'); limit=${limit:-1}
        bw_limit=$(grep "Bandwidth_GB:" "$user" | awk '{print $2}'); bw_limit=${bw_limit:-0}

        total_gb=$(get_bandwidth_usage "$u")
        current_conn=$(get_connection_count "$u")

        expire_ts=$(date -d "$ex" +%s 2>/dev/null || echo 0)
        current_ts=$(date +%s)
        days_left=$(( (expire_ts - current_ts) / 86400 ))

        if passwd -S "$u" 2>/dev/null | grep -q "L"; then
            status="${RED}🔒 LOCKED${NC}"
        elif [ "$current_conn" -gt 0 ]; then
            status="${LIGHT_GREEN}🟢 ONLINE${NC}"
        elif [ $days_left -le 0 ]; then
            status="${RED}⛔ EXPIRED${NC}"
        elif [ $days_left -le 3 ]; then
            status="${LIGHT_RED}⚠️ CRITICAL${NC}"
        elif [ $days_left -le 7 ]; then
            status="${YELLOW}⚠️ WARNING${NC}"
        else
            status="${YELLOW}⚫ OFFLINE${NC}"
        fi

        if [ "$bw_limit" != "0" ] && [ -n "$bw_limit" ]; then
            bw_percent=$(echo "scale=1; ($total_gb / $bw_limit) * 100" | bc 2>/dev/null || echo "0")
            if [ "$(echo "$bw_percent >= 100" | bc 2>/dev/null)" = "1" ]; then
                bw_display="${RED}${total_gb}/${bw_limit}GB${NC}"
            elif [ "$(echo "$bw_percent > 80" | bc 2>/dev/null)" = "1" ]; then
                bw_display="${YELLOW}${total_gb}/${bw_limit}GB${NC}"
            else
                bw_display="${GREEN}${total_gb}/${bw_limit}GB${NC}"
            fi
        else
            bw_display="${GRAY}${total_gb}GB/∞${NC}"
        fi

        [ "$current_conn" -ge "$limit" ] && login_display="${RED}${current_conn}/${limit}${NC}" || login_display="${GREEN}${current_conn}/${limit}${NC}"
        [ "$current_conn" -eq 0 ] && login_display="${GRAY}0/${limit}${NC}"

        [ $days_left -le 0 ] && exp_display="${RED}${ex}${NC}" || exp_display="${GREEN}${ex}${NC}"
        [ $days_left -le 7 ] && [ $days_left -gt 0 ] && exp_display="${YELLOW}${ex}${NC}"

        printf "${CYAN}║${WHITE} %-14s %-12b %-8b %-14b %-18b${CYAN} ║${NC}\n" "$u" "$exp_display" "$login_display" "$bw_display" "$status"
    done

    TOTAL_USERS=$(ls "$UD" 2>/dev/null | wc -l)
    TOTAL_ONLINE=$(who | wc -l)
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${YELLOW}   Users: ${GREEN}${TOTAL_USERS}${YELLOW} | Online: ${GREEN}${TOTAL_ONLINE}${NC}                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

renew_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}User not found!${NC}"; return; }
    read -p "$(echo -e $GREEN"Additional days: "$NC)" days
    current_expire=$(grep "Expire:" "$UD/$username" | cut -d' ' -f2)
    new_expire=$(date -d "$current_expire +$days days" +"%Y-%m-%d")
    sed -i "s/Expire: .*/Expire: $new_expire/" "$UD/$username"
    chage -E "$new_expire" "$username" 2>/dev/null
    usermod -U "$username" 2>/dev/null
    echo -e "${GREEN}✅ User renewed until $new_expire${NC}"
}

set_bandwidth_limit() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}User not found!${NC}"; return; }
    current_bw=$(grep "Bandwidth_GB:" "$UD/$username" 2>/dev/null | awk '{print $2}')
    echo -e "${CYAN}Current: ${YELLOW}${current_bw:-Not set} GB${NC}"
    read -p "$(echo -e $GREEN"New limit (0=unlimited): "$NC)" new_bw
    [[ ! "$new_bw" =~ ^[0-9]+\.?[0-9]*$ ]] && { echo -e "${RED}Invalid!${NC}"; return; }
    grep -q "Bandwidth_GB:" "$UD/$username" && sed -i "s/Bandwidth_GB: .*/Bandwidth_GB: $new_bw/" "$UD/$username" || echo "Bandwidth_GB: $new_bw" >> "$UD/$username"
    [ "$new_bw" = "0" ] && usermod -U "$username" 2>/dev/null
    echo -e "${GREEN}✅ Bandwidth limit updated${NC}"
}

reset_bandwidth() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}User not found!${NC}"; return; }
    echo "0" > "$BW_DIR/${username}.usage"
    rm -rf "$PID_DIR/${username}" 2>/dev/null
    rm -f "$PID_DIR/${username}__"*.last 2>/dev/null
    usermod -U "$username" 2>/dev/null
    echo -e "${GREEN}✅ Bandwidth reset to 0${NC}"
}

lock_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}User not found!${NC}"; return; }
    usermod -L "$u" 2>/dev/null
    pkill -u "$u" 2>/dev/null || true
    echo "$(date) - MANUALLY LOCKED" >> "$BD/$u"
    echo -e "${GREEN}✅ User locked${NC}"
}

unlock_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}User not found!${NC}"; return; }
    usermod -U "$u" 2>/dev/null
    echo "$(date) - MANUALLY UNLOCKED" >> "$BD/$u"
    echo -e "${GREEN}✅ User unlocked${NC}"
}

delete_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" u
    [ ! -f "$UD/$u" ] && { echo -e "${RED}User not found!${NC}"; return; }
    cp "$UD/$u" "$DD/${u}_$(date +%Y%m%d_%H%M%S)" 2>/dev/null
    pkill -u "$u" 2>/dev/null || true
    killall -u "$u" -9 2>/dev/null || true
    userdel -r "$u" 2>/dev/null
    rm -f "$UD/$u" "$USAGE_DB/$u" "$CONN_DB/$u" "$BD/$u" "$BW_DIR/${u}.usage"
    rm -rf "$PID_DIR/${u}" 2>/dev/null
    echo -e "${GREEN}✅ User deleted${NC}"
}

details_user() {
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    [ ! -f "$UD/$username" ] && { echo -e "${RED}User not found!${NC}"; return; }

    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              USER DETAILS                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    cat "$UD/$username" | while read line; do echo -e "${CYAN}║${WHITE}  $line${NC}"; done

    total_gb=$(get_bandwidth_usage "$username")
    bw_limit=$(grep "Bandwidth_GB:" "$UD/$username" 2>/dev/null | awk '{print $2}')
    bw_limit=${bw_limit:-0}
    current_conn=$(get_connection_count "$username")

    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Active Sessions: ${GREEN}${current_conn}${NC}"
    echo -e "${CYAN}║${WHITE}  Bandwidth Used: ${GREEN}${total_gb} GB${NC} / ${YELLOW}${bw_limit:-Unlimited} GB${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    details) details_user ;;
    renew) renew_user ;;
    setlimit) read -p "Username: " u; read -p "New limit: " l; [ -f "$UD/$u" ] && { sed -i "s/Conn_Limit: .*/Conn_Limit: $l/" "$UD/$u"; echo -e "${GREEN}✅ Updated${NC}"; } || echo -e "${RED}Not found${NC}" ;;
    setbw) set_bandwidth_limit ;;
    resetdata) reset_bandwidth ;;
    deleted) ls "$DD/" 2>/dev/null | head -20 || echo "No deleted users" ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    *) echo "Usage: elite-x-user {add|list|details|renew|setlimit|setbw|resetdata|deleted|lock|unlock|del}" ;;
esac
USEREOF
    chmod +x /usr/local/bin/elite-x-user
}

# ═══════════════════════════════════════════════════════════════
# MAIN MENU
# ═══════════════════════════════════════════════════════════════
create_main_menu() {
    cat > /usr/local/bin/elite-x <<'MENUEOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'
ORANGE='\033[0;33m';LIGHT_RED='\033[1;31m';LIGHT_GREEN='\033[1;32m';GRAY='\033[0;90m'

UD="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
AUTOBAN_FLAG="/etc/elite-x/autoban_enabled"

show_dashboard() {
    clear
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || echo "Unknown")
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not set")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
    RAM=$(free -h | awk '/^Mem:/{print $3"/"$2}')

    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    BW=$(systemctl is-active elite-x-bandwidth 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")

    TOTAL_USERS=$(ls -1 "$UD" 2>/dev/null | wc -l)
    ONLINE=$(who | wc -l)

    TOTAL_BW=0
    if [ -d "$BW_DIR" ]; then
        for f in "$BW_DIR"/*.usage; do
            [ -f "$f" ] || continue
            b=$(cat "$f" 2>/dev/null || echo 0)
            gb=$(echo "scale=2; $b / 1073741824" | bc 2>/dev/null || echo "0")
            TOTAL_BW=$(echo "$TOTAL_BW + $gb" | bc 2>/dev/null || echo "$TOTAL_BW")
        done
    fi

    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${YELLOW}${BOLD}        ELITE-X v3.3.1 - FALCON       ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${WHITE}  NS        :${GREEN} $SUB${NC}"
    echo -e "${PURPLE}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${PURPLE}║${WHITE}  Location  :${GREEN} $LOCATION (MTU: $MTU)${NC}"
    echo -e "${PURPLE}║${WHITE}  RAM       :${GREEN} $RAM${NC}"
    echo -e "${PURPLE}║${WHITE}  Services  : DNS:$DNS PRX:$PRX BW:$BW${NC}"
    echo -e "${PURPLE}║${WHITE}  Users     :${GREEN} $TOTAL_USERS total, $ONLINE online${NC}"
    echo -e "${PURPLE}║${WHITE}  Total BW  :${YELLOW} ${TOTAL_BW} GB${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

settings_menu() {
    while true; do
        clear
        autoban=$(cat "$AUTOBAN_FLAG" 2>/dev/null || echo "0")
        [ "$autoban" = "1" ] && ABSTATUS="${RED}ENABLED${NC}" || ABSTATUS="${GREEN}DISABLED${NC}"

        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${YELLOW}${BOLD}                 SETTINGS MENU                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Change MTU  [2] Speed Optimize  [3] Clean Cache${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Edit Banner [5] Reset Banner     [6] Traffic Stats${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset All BW [8] Toggle Auto-Ban ($ABSTATUS)${WHITE}${NC}"
        echo -e "${PURPLE}║${WHITE}  [9] Restart All  [10] Reboot VPS      [11] Uninstall${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Back${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch

        case $ch in
            1)
                read -p "New MTU (1000-5000): " mtu
                [[ "$mtu" =~ ^[0-9]+$ ]] && [ $mtu -ge 1000 ] && [ $mtu -le 5000 ] && {
                    echo "$mtu" > /etc/elite-x/mtu
                    sed -i "s/-mtu [0-9]*/-mtu $mtu/" /etc/systemd/system/dnstt-elite-x.service
                    systemctl daemon-reload
                    systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                    echo -e "${GREEN}✅ MTU updated${NC}"
                } || echo -e "${RED}Invalid${NC}"
                read -p "Press Enter..."
                ;;
            2)
                sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
                sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
                echo -e "${GREEN}✅ Speed optimized${NC}"
                read -p "Press Enter..."
                ;;
            3) apt clean; sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null; echo -e "${GREEN}✅ Cleaned${NC}"; read -p "Press Enter..." ;;
            4) nano /etc/elite-x/banner/ssh-banner; systemctl restart sshd; echo -e "${GREEN}✅ Banner updated${NC}"; read -p "Press Enter..." ;;
            5) cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner; systemctl restart sshd; echo -e "${GREEN}✅ Reset${NC}"; read -p "Press Enter..." ;;
            6)
                iface=$(ip route | grep default | awk '{print $5}' | head -1)
                rx=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0)
                tx=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0)
                echo -e "RX: $(echo "scale=2; $rx/1073741824" | bc) GB"
                echo -e "TX: $(echo "scale=2; $tx/1073741824" | bc) GB"
                read -p "Press Enter..."
                ;;
            7)
                for f in "$BW_DIR"/*.usage; do [ -f "$f" ] && echo "0" > "$f"; done
                for u in "$UD"/*; do [ -f "$u" ] && usermod -U "$(basename "$u")" 2>/dev/null; done
                echo -e "${GREEN}✅ All bandwidth reset${NC}"
                read -p "Press Enter..."
                ;;
            8)
                [ "$autoban" = "1" ] && echo "0" > "$AUTOBAN_FLAG" || echo "1" > "$AUTOBAN_FLAG"
                systemctl restart elite-x-connmon 2>/dev/null
                echo -e "${GREEN}✅ Toggled${NC}"
                read -p "Press Enter..."
                ;;
            9)
                systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon sshd 2>/dev/null
                echo -e "${GREEN}✅ Restarted${NC}"
                read -p "Press Enter..."
                ;;
            10) read -p "Reboot? (y/n): " c; [ "$c" = "y" ] && reboot ;;
            11)
                read -p "Type 'YES' to confirm uninstall: " c
                [ "$c" = "YES" ] && {
                    for u in "$UD"/*; do
                        [ -f "$u" ] && { un=$(basename "$u"); pkill -u "$un" 2>/dev/null; userdel -r "$un" 2>/dev/null; }
                    done
                    for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon; do
                        systemctl stop "$s" 2>/dev/null; systemctl disable "$s" 2>/dev/null
                    done
                    rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*}
                    rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x
                    rm -f /usr/local/bin/{dnstt-*,elite-x*}
                    sed -i '/^Banner/d' /etc/ssh/sshd_config
                    systemctl restart sshd 2>/dev/null
                    rm -f /etc/profile.d/elite-x-dashboard.sh
                    sed -i '/elite-x/d' ~/.bashrc 2>/dev/null
                    systemctl daemon-reload
                    echo -e "${GREEN}✅ Uninstalled!${NC}"
                    exit 0
                }
                read -p "Press Enter..."
                ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard

        echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${GREEN}${BOLD}               MAIN MENU v3.3.1                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║${WHITE}  [1] Create User   [2] List Users      [3] User Details${NC}"
        echo -e "${PURPLE}║${WHITE}  [4] Renew User    [5] Set Conn Limit   [6] Set BW Limit${NC}"
        echo -e "${PURPLE}║${WHITE}  [7] Reset BW      [8] Lock User        [9] Unlock User${NC}"
        echo -e "${PURPLE}║${WHITE}  [10] Delete User  [11] Deleted List     [S] Settings${NC}"
        echo -e "${PURPLE}║${WHITE}  [0] Exit${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
        read -p "$(echo -e $GREEN"Option: "$NC)" ch

        case $ch in
            1) elite-x-user add; read -p "Press Enter..." ;;
            2) elite-x-user list; read -p "Press Enter..." ;;
            3) elite-x-user details; read -p "Press Enter..." ;;
            4) elite-x-user renew; read -p "Press Enter..." ;;
            5) elite-x-user setlimit; read -p "Press Enter..." ;;
            6) elite-x-user setbw; read -p "Press Enter..." ;;
            7) elite-x-user resetdata; read -p "Press Enter..." ;;
            8) elite-x-user lock; read -p "Press Enter..." ;;
            9) elite-x-user unlock; read -p "Press Enter..." ;;
            10) elite-x-user del; read -p "Press Enter..." ;;
            11) elite-x-user deleted; read -p "Press Enter..." ;;
            [Ss]) settings_menu ;;
            0) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid${NC}"; read -p "Press Enter..." ;;
        esac
    done
}

main_menu
MENUEOF
    chmod +x /usr/local/bin/elite-x
}

# ═══════════════════════════════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════════
show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

if [ "$ACTIVATION_INPUT" != "$ACTIVATION_KEY" ] && [ "$ACTIVATION_INPUT" != "Whatsapp +255713-628-668" ]; then
    echo -e "${RED}❌ Invalid activation key!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Activation successful${NC}"
sleep 1

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR NAMESERVER [NS]                    ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
read -p "$(echo -e $GREEN"Nameserver: "$NC)" TDOMAIN

echo -e "${YELLOW}Select VPS location:${NC}"
echo -e "  [1] South Africa (MTU 1800)"
echo -e "  [2] USA (MTU 1500)"
echo -e "  [3] Europe (MTU 1500)"
echo -e "  [4] Asia (MTU 1400)"
echo -e "  [5] Custom MTU"
read -p "$(echo -e $GREEN"Choice [1]: "$NC)" LOC
LOC=${LOC:-1}
case $LOC in
    2) SEL_LOC="USA"; MTU=1500 ;;
    3) SEL_LOC="Europe"; MTU=1500 ;;
    4) SEL_LOC="Asia"; MTU=1400 ;;
    5) SEL_LOC="Custom"; read -p "MTU: " MTU; [[ ! "$MTU" =~ ^[0-9]+$ ]] && MTU=1800 ;;
    *) SEL_LOC="South Africa"; MTU=1800 ;;
esac

echo -e "${YELLOW}🔄 Cleaning previous installation...${NC}"
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon; do
    systemctl stop "$s" 2>/dev/null || true
    systemctl disable "$s" 2>/dev/null || true
done
pkill -f dnstt-server 2>/dev/null || true
rm -rf /etc/systemd/system/{dnstt-elite-x*,elite-x*} 2>/dev/null || true
rm -rf /etc/dnstt /etc/elite-x /var/run/elite-x 2>/dev/null || true
rm -f /usr/local/bin/{dnstt-*,elite-x*} 2>/dev/null || true
sed -i '/^Banner/d' /etc/ssh/sshd_config 2>/dev/null || true
timeout 5 systemctl restart sshd 2>/dev/null || true
sleep 2

# Create directories
echo -e "${YELLOW}📁 Creating directory structure...${NC}"
mkdir -p /etc/elite-x/{banner,users,traffic,deleted,data_usage,connections,banned,traffic_stats,bandwidth/pidtrack}
mkdir -p /var/run/elite-x/bandwidth
echo "$TDOMAIN" > /etc/elite-x/subdomain
echo "$SEL_LOC" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu
echo "0" > "$AUTOBAN_FLAG"
echo "$STATIC_PRIVATE_KEY" > /etc/elite-x/private_key
echo "$STATIC_PUBLIC_KEY" > /etc/elite-x/public_key

# Create default banner
cat > /etc/elite-x/banner/default <<'EOF'
╔═══════════════════════════════════════════════════════════════╗
║              ELITE-X v3.3.1 FALCON            ║
║     C Proxy • IPv6 Off • BBR • 20MB Buff • Nice -20          ║
╚═══════════════════════════════════════════════════════════════╝
EOF
cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner
echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config
timeout 5 systemctl restart sshd 2>/dev/null || true

# Configure DNS
echo -e "${YELLOW}🔧 Configuring DNS...${NC}"
if [ -f /etc/systemd/resolved.conf ]; then
    sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
    timeout 5 systemctl restart systemd-resolved 2>/dev/null || true
fi
if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf
fi
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
apt update -y 2>/dev/null || true
apt install -y curl python3 jq iptables ethtool dnsutils net-tools iproute2 bc build-essential git gcc 2>/dev/null || true

# Apply kernel optimizations and disable IPv6
optimize_kernel_and_disable_ipv6

# Download DNSTT
echo -e "${YELLOW}📥 Downloading DNSTT server...${NC}"
if ! curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server 2>/dev/null; then
    curl -fsSL https://github.com/NoXFiQ/Elite-X-dns.sh/raw/main/dnstt-server -o /usr/local/bin/dnstt-server 2>/dev/null || true
fi
if [ -f /usr/local/bin/dnstt-server ]; then
    chmod +x /usr/local/bin/dnstt-server
    echo -e "${GREEN}✅ DNSTT server downloaded${NC}"
else
    echo -e "${RED}❌ Failed to download DNSTT server${NC}"
    exit 1
fi

# Setup DNSTT keys
mkdir -p /etc/dnstt
echo "$STATIC_PRIVATE_KEY" > /etc/dnstt/server.key
echo "$STATIC_PUBLIC_KEY" > /etc/dnstt/server.pub
chmod 600 /etc/dnstt/server.key

# Create DNSTT service (Nice -20, LimitNOFILE 1M, CPUQuota 200%)
echo -e "${YELLOW}🔧 Creating DNSTT service...${NC}"
cat > /etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server v3.3.1
After=network-online.target

[Service]
Type=simple
User=root
Nice=-20
ExecStart=/usr/local/bin/dnstt-server -udp :5300 -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=5
LimitNOFILE=1000000
CPUQuota=200%

[Install]
WantedBy=multi-user.target
EOF

# Compile C EDNS Proxy
create_c_edns_proxy

# Use C binary if available, otherwise fallback to Python
if [ -f "$EDNS_C_BIN" ] && [ -x "$EDNS_C_BIN" ]; then
    PROXY_EXEC="$EDNS_C_BIN"
    PROXY_TYPE="C (compiled, multi-core)"
else
    PROXY_EXEC="/usr/bin/python3 /usr/local/bin/dnstt-edns-proxy.py"
    PROXY_TYPE="Python (fallback)"
fi

# Create EDNS Proxy service (Nice -20, LimitNOFILE 1M, CPUQuota 200%)
echo -e "${YELLOW}🔧 Creating EDNS Proxy service (${PROXY_TYPE})...${NC}"
cat > /etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X EDNS Proxy (${PROXY_TYPE})
After=dnstt-elite-x.service

[Service]
Type=simple
User=root
Nice=-20
LimitNOFILE=1000000
ExecStart=${PROXY_EXEC}
Restart=always
RestartSec=3
CPUQuota=200%

[Install]
WantedBy=multi-user.target
EOF

# Keep Python proxy as fallback
cat > /usr/local/bin/dnstt-edns-proxy.py <<'EOF'
#!/usr/bin/env python3
import socket, threading, struct, sys, time, os, signal, logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
L=5300; running=True
def modify_edns(d, max_size):
    if len(d)<12: return d
    o=12
    def skip_name(b,o):
        while o<len(b):
            l=b[o];o+=1
            if l==0:break
            if l&0xC0==0xC0:o+=1;break
            o+=l
        return o
    try: q,a,n,r=struct.unpack("!HHHH",d[4:12])
    except: return d
    for _ in range(q): o=skip_name(d,o); o+=4
    for _ in range(a+n):
        o=skip_name(d,o)
        if o+10>len(d): return d
        try: _,_,_,l=struct.unpack("!HHIH",d[o:o+10])
        except: return d
        o+=10+l
    modified=bytearray(d)
    for _ in range(r):
        o=skip_name(d,o)
        if o+10>len(d): return d
        t=struct.unpack("!H",d[o:o+2])[0]
        if t==41: modified[o+2:o+4]=struct.pack("!H",max_size); return bytes(modified)
        _,_,l=struct.unpack("!HIH",d[o+2:o+10]); o+=10+l
    return d
def handle(sock,data,addr):
    c=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);c.settimeout(5)
    try:
        md=modify_edns(data,1800);c.sendto(md,('127.0.0.1',L))
        r,_=c.recvfrom(4096);mr=modify_edns(r,512);sock.sendto(mr,addr)
    except:pass
    finally:c.close()
def main():
    global running
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
    os.system("fuser -k 53/udp 2>/dev/null; sleep 1")
    try: s.bind(('0.0.0.0',53))
    except:
        os.system("fuser -k 53/udp 2>/dev/null; sleep 2")
        try: s.bind(('0.0.0.0',53))
        except: logging.error("Cannot bind port 53"); sys.exit(1)
    logging.info("EDNS Proxy on port 53 (Python fallback)")
    while running:
        try: data,addr=s.recvfrom(4096);threading.Thread(target=handle,args=(s,data,addr),daemon=True).start()
        except:pass
main()
EOF
chmod +x /usr/local/bin/dnstt-edns-proxy.py

# Create all monitoring scripts
echo -e "${YELLOW}📝 Creating monitoring scripts...${NC}"
create_bandwidth_monitor
create_connection_monitor
create_data_usage_monitor
create_user_script
create_main_menu

# Enable and start services
echo -e "${YELLOW}🚀 Starting all services...${NC}"
systemctl daemon-reload 2>/dev/null || true
for s in dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-datausage elite-x-connmon; do
    if [ -f "/etc/systemd/system/${s}.service" ]; then
        systemctl enable "$s" 2>/dev/null || true
        timeout 10 systemctl start "$s" 2>/dev/null || true
    fi
done

# Cache IP
echo -e "${YELLOW}🌍 Caching public IP...${NC}"
IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

# Setup auto-login dashboard
cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    /usr/local/bin/elite-x
fi
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

# Add aliases
cat >> ~/.bashrc <<'EOF'
alias menu='elite-x'
alias elitex='elite-x'
alias adduser='elite-x-user add'
alias users='elite-x-user list'
alias setbw='elite-x-user setbw'
EOF

# ═══════════════════════════════════════════════════════════════
# FINAL
# ═══════════════════════════════════════════════════════════════
clear
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${YELLOW}${BOLD}     ELITE-X v3.3.1 FALCON  INSTALLED!    ${GREEN}║${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║${WHITE}  Domain     :${CYAN} $TDOMAIN${NC}"
echo -e "${GREEN}║${WHITE}  Location   :${CYAN} $SEL_LOC (MTU: $MTU)${NC}"
echo -e "${GREEN}║${WHITE}  IP         :${CYAN} $IP${NC}"
echo -e "${GREEN}║${WHITE}  Proxy      :${CYAN} ${PROXY_TYPE}${NC}"
echo -e "${GREEN}║${WHITE}  IPv6       :${RED} DISABLED${NC}"
echo -e "${GREEN}║${WHITE}  Kernel     :${GREEN} BBR + 20MB Buffers + High Backlog${NC}"
echo -e "${GREEN}║${WHITE}  Nice       :${GREEN} -20 (Max Priority)${NC}"
echo -e "${GREEN}║${WHITE}  Version    :${CYAN} v3.3.1 Falcon ${NC}"
echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
systemctl is-active dnstt-elite-x >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ DNSTT Server: Running${NC}" || echo -e "${RED}║  ❌ DNSTT Server: Failed${NC}"
systemctl is-active dnstt-elite-x-proxy >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ EDNS Proxy (${PROXY_TYPE}): Running${NC}" || echo -e "${RED}║  ❌ EDNS Proxy: Failed${NC}"
systemctl is-active elite-x-bandwidth >/dev/null 2>&1 && echo -e "${GREEN}║  ✅ Bandwidth Monitor: Running${NC}" || echo -e "${RED}║  ❌ Bandwidth: Failed${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Commands: menu | elite-x | users | adduser | setbw${NC}"
echo -e "${YELLOW}Type 'exec bash' or re-login to access the dashboard${NC}"
