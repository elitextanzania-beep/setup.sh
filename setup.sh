#!/bin/bash
# ╔══════════════════════╗
#  ELITE-X DNSTT  SCRIPT
# ╚══════════════════════╝
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

print_color() { echo -e "${2}${1}${NC}"; }

self_destruct() {
    echo -e "${YELLOW}🧹 Cleaning installation traces...${NC}"
    
    history -c 2>/dev/null || true
    cat /dev/null > ~/.bash_history 2>/dev/null || true
    cat /dev/null > /root/.bash_history 2>/dev/null || true
    
    if [ -f "$0" ] && [ "$0" != "/usr/local/bin/elite-x" ]; then
        local script_path=$(readlink -f "$0")
        rm -f "$script_path" 2>/dev/null || true
    fi
    
    sed -i '/Elite-X-dns.sh/d' /var/log/auth.log 2>/dev/null || true
    sed -i '/elite-x/d' /var/log/auth.log 2>/dev/null || true
    
    echo -e "${GREEN}✅ Cleanup complete!${NC}"
}

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_banner() {
    clear
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${YELLOW}${BOLD}                   ELITE-X SLOWDNS v3.0                        ${RED}║${NC}"
    echo -e "${RED}║${GREEN}${BOLD}                    Stable Edition                              ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

ACTIVATION_KEY="ELITE-X"
TEMP_KEY="ELITE-X-TEST-0208"
ACTIVATION_FILE="/etc/elite-x/activated"
ACTIVATION_TYPE_FILE="/etc/elite-x/activation_type"
ACTIVATION_DATE_FILE="/etc/elite-x/activation_date"
EXPIRY_DAYS_FILE="/etc/elite-x/expiry_days"
KEY_FILE="/etc/elite-x/key"
TIMEZONE="Africa/Dar_es_Salaam"

set_timezone() {
    timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime 2>/dev/null || true
}

check_expiry() {
    if [ -f "$ACTIVATION_TYPE_FILE" ] && [ -f "$ACTIVATION_DATE_FILE" ] && [ -f "$EXPIRY_DAYS_FILE" ]; then
        local act_type=$(cat "$ACTIVATION_TYPE_FILE")
        if [ "$act_type" = "temporary" ]; then
            local act_date=$(cat "$ACTIVATION_DATE_FILE")
            local expiry_days=$(cat "$EXPIRY_DAYS_FILE")
            local current_date=$(date +%s)
            local expiry_date=$(date -d "$act_date + $expiry_days days" +%s)
            
            if [ $current_date -ge $expiry_date ]; then
                echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║${YELLOW}           TRIAL PERIOD EXPIRED                                  ${RED}║${NC}"
                echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${RED}║${WHITE}  Your 2-day trial has ended.                                  ${RED}║${NC}"
                echo -e "${RED}║${WHITE}  Script will now uninstall itself...                         ${RED}║${NC}"
                echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
                sleep 3
                      
                systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner 2>/dev/null || true
                systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner 2>/dev/null || true
                rm -f /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
                rm -rf /etc/dnstt /etc/elite-x
                rm -f /usr/local/bin/{dnstt-*,elite-x*}
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                systemctl restart sshd

                rm -f "$0"
                echo -e "${GREEN}✅ ELITE-X has been uninstalled.${NC}"
                exit 0
            else
                local days_left=$(( (expiry_date - current_date) / 86400 ))
                local hours_left=$(( ((expiry_date - current_date) % 86400) / 3600 ))
                echo -e "${YELLOW}⚠️  Trial: $days_left days $hours_left hours remaining${NC}"
            fi
        fi
    fi
}

activate_script() {
    local input_key="$1"
    mkdir -p /etc/elite-x
    
    if [ "$input_key" = "$ACTIVATION_KEY" ] || [ "$input_key" = "Whtsapp 0713628668" ]; then
        echo "$ACTIVATION_KEY" > "$ACTIVATION_FILE"
        echo "$ACTIVATION_KEY" > "$KEY_FILE"
        echo "lifetime" > "$ACTIVATION_TYPE_FILE"
        echo "Lifetime" > /etc/elite-x/expiry
        return 0
    elif [ "$input_key" = "$TEMP_KEY" ]; then
        echo "$TEMP_KEY" > "$ACTIVATION_FILE"
        echo "$TEMP_KEY" > "$KEY_FILE"
        echo "temporary" > "$ACTIVATION_TYPE_FILE"
        echo "$(date +%Y-%m-%d)" > "$ACTIVATION_DATE_FILE"
        echo "2" > "$EXPIRY_DAYS_FILE"
        echo "2 Days Trial" > /etc/elite-x/expiry
        return 0
    fi
    return 1
}

check_subdomain() {
    local subdomain="$1"
    local vps_ip=$(curl -4 -s ifconfig.me 2>/dev/null || echo "")
    
    echo -e "${YELLOW}🔍 Checking if subdomain points to this VPS (IPv4)...${NC}"
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  Subdomain: $subdomain${NC}"
    echo -e "${CYAN}║${WHITE}  VPS IPv4 : $vps_ip${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    if [ -z "$vps_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not detect VPS IPv4, continuing anyway...${NC}"
        return 0
    fi

    local resolved_ip=$(dig +short -4 "$subdomain" 2>/dev/null | head -1)
    
    if [ -z "$resolved_ip" ]; then
        echo -e "${YELLOW}⚠️  Could not resolve subdomain, continuing anyway...${NC}"
        echo -e "${YELLOW}⚠️  Make sure your subdomain points to: $vps_ip${NC}"
        return 0
    fi
    
    if [ "$resolved_ip" = "$vps_ip" ]; then
        echo -e "${GREEN}✅ Subdomain correctly points to this VPS!${NC}"
        return 0
    else
        echo -e "${RED}❌ Subdomain points to $resolved_ip, but VPS IP is $vps_ip${NC}"
        echo -e "${YELLOW}⚠️  Please update your DNS record and try again${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [ "$continue_anyway" != "y" ]; then
            exit 1
        fi
    fi
}

# ═══════════════════════════════════════════════════════════
# C: BANDWIDTH MONITOR (kutoka V5 - GB badala ya MB)
# ═══════════════════════════════════════════════════════════
setup_c_bandwidth_monitor() {
    echo -e "${YELLOW}📝 Compiling C Bandwidth Monitor...${NC}"
    cat > /tmp/bw_monitor.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <time.h>
#include <signal.h>
#include <pwd.h>
#include <ctype.h>

#define USER_DB      "/etc/elite-x/users"
#define BW_DIR       "/etc/elite-x/bandwidth"
#define PID_DIR      "/etc/elite-x/bandwidth/pidtrack"
#define BANNED_DIR   "/etc/elite-x/banned"
#define SCAN_INTERVAL 30
#define GB_BYTES      1073741824.0

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

static long long get_process_io(int pid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/io", pid);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    long long rchar = 0, wchar = 0;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "rchar:", 6) == 0) sscanf(line + 7, "%lld", &rchar);
        else if (strncmp(line, "wchar:", 6) == 0) sscanf(line + 7, "%lld", &wchar);
    }
    fclose(f);
    return rchar + wchar;
}

static int is_numeric(const char *str) {
    if (!str || !*str) return 0;
    for (; *str; str++) if (!isdigit((unsigned char)*str)) return 0;
    return 1;
}

static int get_sshd_pids(const char *username, int *pids, int max_pids) {
    int count = 0;
    DIR *proc = opendir("/proc");
    if (!proc) return 0;
    struct dirent *entry;
    while ((entry = readdir(proc)) && count < max_pids) {
        if (!is_numeric(entry->d_name)) continue;
        int pid = atoi(entry->d_name);
        char comm_path[256];
        snprintf(comm_path, sizeof(comm_path), "/proc/%d/comm", pid);
        FILE *f = fopen(comm_path, "r");
        if (!f) continue;
        char comm[64] = {0};
        fgets(comm, sizeof(comm), f);
        fclose(f);
        comm[strcspn(comm, "\n")] = 0;
        if (strcmp(comm, "sshd") != 0) continue;
        char status_path[256];
        snprintf(status_path, sizeof(status_path), "/proc/%d/status", pid);
        FILE *sf = fopen(status_path, "r");
        if (!sf) continue;
        char line[256], uid_str[32] = {0};
        while (fgets(line, sizeof(line), sf))
            if (strncmp(line, "Uid:", 4) == 0) { sscanf(line, "%*s %s", uid_str); break; }
        fclose(sf);
        int uid = atoi(uid_str);
        struct passwd *pw = getpwuid(uid);
        if (!pw || strcmp(pw->pw_name, username) != 0) continue;
        char stat_path[256];
        snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", pid);
        FILE *stf = fopen(stat_path, "r");
        if (!stf) continue;
        int ppid = 0;
        char stat_buf[1024];
        fgets(stat_buf, sizeof(stat_buf), stf);
        sscanf(stat_buf, "%*d %*s %*c %d", &ppid);
        fclose(stf);
        if (ppid != 1) pids[count++] = pid;
    }
    closedir(proc);
    return count;
}

int main(void) {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    mkdir(BW_DIR, 0755);
    mkdir(PID_DIR, 0755);
    mkdir(BANNED_DIR, 0755);

    while (running) {
        DIR *user_dir = opendir(USER_DB);
        if (!user_dir) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *user_entry;
        while ((user_entry = readdir(user_dir))) {
            if (user_entry->d_name[0] == '.') continue;
            char user_file[512];
            snprintf(user_file, sizeof(user_file), "%s/%s", USER_DB, user_entry->d_name);
            FILE *uf = fopen(user_file, "r");
            if (!uf) continue;
            double bandwidth_gb = 0;
            char line[256];
            while (fgets(line, sizeof(line), uf))
                if (strncmp(line, "Bandwidth_GB:", 13) == 0) sscanf(line + 13, "%lf", &bandwidth_gb);
            fclose(uf);
            if (bandwidth_gb <= 0) continue;
            int pids[100];
            int pid_count = get_sshd_pids(user_entry->d_name, pids, 100);
            if (pid_count == 0) {
                char cmd[512];
                snprintf(cmd, sizeof(cmd), "rm -f %s/%s__*.last 2>/dev/null", PID_DIR, user_entry->d_name);
                system(cmd);
                continue;
            }
            long long delta_total = 0;
            int i;
            for (i = 0; i < pid_count; i++) {
                long long cur_io = get_process_io(pids[i]);
                char pidfile[512];
                snprintf(pidfile, sizeof(pidfile), "%s/%s__%d.last", PID_DIR, user_entry->d_name, pids[i]);
                FILE *pf = fopen(pidfile, "r");
                if (pf) {
                    long long prev_io = 0;
                    fscanf(pf, "%lld", &prev_io);
                    fclose(pf);
                    long long d = (cur_io >= prev_io) ? (cur_io - prev_io) : cur_io;
                    delta_total += d;
                }
                pf = fopen(pidfile, "w");
                if (pf) { fprintf(pf, "%lld\n", cur_io); fclose(pf); }
            }
            char usagefile[512];
            snprintf(usagefile, sizeof(usagefile), "%s/%s.usage", BW_DIR, user_entry->d_name);
            long long accumulated = 0;
            FILE *accf = fopen(usagefile, "r");
            if (accf) { fscanf(accf, "%lld", &accumulated); fclose(accf); }
            long long new_total = accumulated + delta_total;
            accf = fopen(usagefile, "w");
            if (accf) { fprintf(accf, "%lld\n", new_total); fclose(accf); }
            long long quota_bytes = (long long)(bandwidth_gb * GB_BYTES);
            if (new_total >= quota_bytes) {
                char cmd[1024];
                snprintf(cmd, sizeof(cmd),
                    "passwd -S %s 2>/dev/null | grep -q 'L' || "
                    "(usermod -L %s 2>/dev/null && "
                    "killall -u %s -9 2>/dev/null && "
                    "echo '%s - BLOCKED: Bandwidth quota exceeded %.1fGB' >> %s/%s)",
                    user_entry->d_name, user_entry->d_name, user_entry->d_name,
                    "BLOCKED", bandwidth_gb, BANNED_DIR, user_entry->d_name);
                system(cmd);
            }
        }
        closedir(user_dir);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-bandwidth-c /tmp/bw_monitor.c 2>/dev/null
    rm -f /tmp/bw_monitor.c
    if [ -f /usr/local/bin/elite-x-bandwidth-c ]; then
        chmod +x /usr/local/bin/elite-x-bandwidth-c
        cat > /etc/systemd/system/elite-x-bandwidth.service <<EOF
[Unit]
Description=ELITE-X C Bandwidth Monitor
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-bandwidth-c
Restart=always
RestartSec=5
CPUQuota=20%
MemoryMax=50M
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable elite-x-bandwidth.service
        systemctl start elite-x-bandwidth.service
        echo -e "${GREEN}✅ C Bandwidth Monitor compiled and started${NC}"
    else
        echo -e "${RED}❌ Bandwidth Monitor compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: CONNECTION MONITOR (kutoka V5)
# ═══════════════════════════════════════════════════════════
setup_c_connection_monitor() {
    echo -e "${YELLOW}📝 Compiling C Connection Monitor...${NC}"
    cat > /tmp/conn_monitor.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <signal.h>
#include <time.h>
#include <pwd.h>
#include <ctype.h>

#define USER_DB      "/etc/elite-x/users"
#define CONN_DB      "/etc/elite-x/connections"
#define BANNED_DIR   "/etc/elite-x/banned"
#define BW_DIR       "/etc/elite-x/bandwidth"
#define PID_DIR      "/etc/elite-x/bandwidth/pidtrack"
#define AUTOBAN_FL   "/etc/elite-x/autoban_enabled"
#define SCAN_INTERVAL 5

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

static int is_numeric(const char *s) {
    if (!s || !*s) return 0;
    for (; *s; s++) if (!isdigit((unsigned char)*s)) return 0;
    return 1;
}

static int get_conn_count(const char *user) {
    int count = 0;
    DIR *proc = opendir("/proc"); if (!proc) return 0;
    struct dirent *e;
    while ((e = readdir(proc))) {
        if (!is_numeric(e->d_name)) continue;
        int pid = atoi(e->d_name);
        char cp[256]; snprintf(cp,sizeof(cp),"/proc/%d/comm",pid);
        FILE *f = fopen(cp,"r"); if (!f) continue;
        char comm[64]={0}; fgets(comm,sizeof(comm),f); fclose(f);
        comm[strcspn(comm,"\n")] = 0;
        if (strcmp(comm,"sshd") != 0) continue;
        char sp[256]; snprintf(sp,sizeof(sp),"/proc/%d/status",pid);
        FILE *sf = fopen(sp,"r"); if (!sf) continue;
        char line[256], uid_s[32]={0};
        while (fgets(line,sizeof(line),sf))
            if (strncmp(line,"Uid:",4)==0){sscanf(line,"%*s %s",uid_s);break;}
        fclose(sf);
        struct passwd *pw = getpwuid(atoi(uid_s));
        if (!pw || strcmp(pw->pw_name,user)!=0) continue;
        char stp[256]; snprintf(stp,sizeof(stp),"/proc/%d/stat",pid);
        FILE *stf = fopen(stp,"r"); if (!stf) continue;
        int ppid=0; char sb[1024]; fgets(sb,sizeof(sb),stf);
        sscanf(sb,"%*d %*s %*c %d",&ppid); fclose(stf);
        if (ppid != 1) count++;
    }
    closedir(proc);
    return count;
}

int main(void) {
    signal(SIGTERM, signal_handler); signal(SIGINT, signal_handler);
    mkdir(CONN_DB,0755); mkdir(BANNED_DIR,0755);
    mkdir(BW_DIR,0755); mkdir(PID_DIR,0755);

    while (running) {
        DIR *ud = opendir(USER_DB); if (!ud) { sleep(SCAN_INTERVAL); continue; }
        struct dirent *ue;
        while ((ue = readdir(ud))) {
            if (ue->d_name[0]=='.') continue;
            struct passwd *pw = getpwnam(ue->d_name);
            if (!pw) continue;
            char uf[512]; snprintf(uf,sizeof(uf),"%s/%s",USER_DB,ue->d_name);
            FILE *f = fopen(uf,"r"); if (!f) continue;
            int conn_lim=1; char line[256];
            while (fgets(line,sizeof(line),f))
                if (strncmp(line,"Conn_Limit:",11)==0) sscanf(line+12,"%d",&conn_lim);
            fclose(f);

            int cc = get_conn_count(ue->d_name);
            char cf[512]; snprintf(cf,sizeof(cf),"%s/%s",CONN_DB,ue->d_name);
            FILE *cfile = fopen(cf,"w");
            if (cfile) { fprintf(cfile,"%d\n",cc); fclose(cfile); }

            int autoban=0;
            FILE *abf = fopen(AUTOBAN_FL,"r");
            if (abf) { fscanf(abf,"%d",&autoban); fclose(abf); }

            if (cc > conn_lim && autoban == 1) {
                char cmd[1024];
                snprintf(cmd,sizeof(cmd),
                    "passwd -S %s 2>/dev/null | grep -q 'L' || "
                    "(usermod -L %s 2>/dev/null && pkill -u %s 2>/dev/null && "
                    "echo 'BLOCKED: Exceeded conn %d/%d' >> %s/%s)",
                    ue->d_name,ue->d_name,ue->d_name,cc,conn_lim,BANNED_DIR,ue->d_name);
                system(cmd);
            }
        }
        closedir(ud);
        sleep(SCAN_INTERVAL);
    }
    return 0;
}
CEOF
    gcc -O3 -o /usr/local/bin/elite-x-connmon-c /tmp/conn_monitor.c 2>/dev/null
    rm -f /tmp/conn_monitor.c
    if [ -f /usr/local/bin/elite-x-connmon-c ]; then
        chmod +x /usr/local/bin/elite-x-connmon-c
        cat > /etc/systemd/system/elite-x-connmon.service <<EOF
[Unit]
Description=ELITE-X C Connection Monitor
After=network.target ssh.service
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-connmon-c
Restart=always
RestartSec=5
CPUQuota=20%
MemoryMax=50M
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable elite-x-connmon.service
        systemctl start elite-x-connmon.service
        echo -e "${GREEN}✅ C Connection Monitor compiled and started${NC}"
    else
        echo -e "${RED}❌ Connection Monitor compilation failed${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════
# C: EDNS PROXY (badala ya Python)
# ═══════════════════════════════════════════════════════════
setup_c_edns_proxy() {
    echo -e "${YELLOW}📝 Compiling C EDNS Proxy (replaces Python)...${NC}"
    cat > /tmp/edns_proxy.c <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdint.h>
#include <sys/resource.h>

#define LISTEN_PORT  53
#define UPSTREAM_PORT 5300
#define BUF_SIZE     4096
#define MAX_WORKERS  32

static volatile int running = 1;
void signal_handler(int sig) { running = 0; }

/* Patch OPT record payload size in DNS message */
static void patch_edns_size(unsigned char *buf, int len, uint16_t new_size) {
    if (len < 12) return;
    int qdcount = (buf[4] << 8) | buf[5];
    int ancount = (buf[6] << 8) | buf[7];
    int nscount = (buf[8] << 8) | buf[9];
    int arcount = (buf[10] << 8) | buf[11];
    int off = 12;

    /* Helper: skip a DNS name */
    #define SKIP_NAME(b,o,l) do { \
        while ((o)<(l)) { \
            int _ll=(b)[(o)]; (o)++; \
            if(_ll==0) break; \
            if((_ll&0xC0)==0xC0){(o)++;break;} \
            (o)+=_ll; \
        } \
    } while(0)

    int i;
    for (i=0; i<qdcount && off<len; i++) { SKIP_NAME(buf,off,len); off+=4; }
    for (i=0; i<ancount+nscount && off<len; i++) {
        SKIP_NAME(buf,off,len);
        if (off+10>len) return;
        int rdlen=(buf[off+8]<<8)|buf[off+9];
        off+=10+rdlen;
    }
    for (i=0; i<arcount && off<len; i++) {
        SKIP_NAME(buf,off,len);
        if (off+10>len) return;
        uint16_t rtype=(buf[off]<<8)|buf[off+1];
        if (rtype==41) { /* OPT record */
            buf[off+2]=(new_size>>8)&0xFF;
            buf[off+3]=new_size&0xFF;
            return;
        }
        int rdlen=(buf[off+8]<<8)|buf[off+9];
        off+=10+rdlen;
    }
    #undef SKIP_NAME
}

typedef struct {
    int server_fd;
    unsigned char data[BUF_SIZE];
    int data_len;
    struct sockaddr_in client_addr;
    socklen_t client_len;
} work_t;

static void *handle_packet(void *arg) {
    work_t *w = (work_t *)arg;
    /* Forward to upstream with 1800 payload size */
    patch_edns_size(w->data, w->data_len, 1800);
    int up = socket(AF_INET, SOCK_DGRAM, 0);
    if (up < 0) { free(w); return NULL; }
    struct timeval tv = {5, 0};
    setsockopt(up, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    struct sockaddr_in upstream = {0};
    upstream.sin_family = AF_INET;
    upstream.sin_port = htons(UPSTREAM_PORT);
    inet_pton(AF_INET, "127.0.0.1", &upstream.sin_addr);
    sendto(up, w->data, w->data_len, 0, (struct sockaddr*)&upstream, sizeof(upstream));
    unsigned char resp[BUF_SIZE];
    socklen_t ul = sizeof(upstream);
    int rlen = recvfrom(up, resp, sizeof(resp), 0, (struct sockaddr*)&upstream, &ul);
    close(up);
    if (rlen > 0) {
        patch_edns_size(resp, rlen, 512);
        sendto(w->server_fd, resp, rlen, 0, (struct sockaddr*)&w->client_addr, w->client_len);
    }
    free(w);
    return NULL;
}

int main(void) {
    signal(SIGTERM, signal_handler);
    signal(SIGINT, signal_handler);
    struct rlimit rl = {1048576, 1048576};
    setrlimit(RLIMIT_NOFILE, &rl);

    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) { perror("socket"); return 1; }
    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(LISTEN_PORT);
    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind"); close(fd); return 1;
    }
    fprintf(stderr, "[ELITE-X] C EDNS Proxy v3.0 running (port %d → %d)\n",
            LISTEN_PORT, UPSTREAM_PORT);

    while (running) {
        work_t *w = malloc(sizeof(work_t));
        if (!w) { sleep(1); continue; }
        w->server_fd = fd;
        w->client_len = sizeof(w->client_addr);
        w->data_len = recvfrom(fd, w->data, BUF_SIZE, 0,
                               (struct sockaddr*)&w->client_addr, &w->client_len);
        if (w->data_len <= 0) { free(w); continue; }
        pthread_t tid;
        if (pthread_create(&tid, NULL, handle_packet, w) != 0) {
            free(w);
        } else {
            pthread_detach(tid);
        }
    }
    close(fd);
    return 0;
}
CEOF
    gcc -O2 -o /usr/local/bin/elite-x-edns-proxy-c /tmp/edns_proxy.c -lpthread
    local rc=$?
    rm -f /tmp/edns_proxy.c
    if [ $rc -eq 0 ] && [ -f /usr/local/bin/elite-x-edns-proxy-c ]; then
        chmod +x /usr/local/bin/elite-x-edns-proxy-c
        echo -e "${GREEN}✅ C EDNS Proxy compiled${NC}"
    else
        echo -e "${RED}❌ C EDNS Proxy compilation failed (exit $rc)${NC}"
        echo -e "${YELLOW}⚠️  Trying to install build-essential...${NC}"
        apt-get install -y gcc build-essential 2>/dev/null
        # retry
        cat > /tmp/edns_proxy2.c <<'CEOF2'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/resource.h>

#define LISTEN_PORT   53
#define UPSTREAM_PORT 5300
#define BUF_SIZE      4096

static volatile int running = 1;
void signal_handler(int sig) { (void)sig; running = 0; }

typedef struct {
    int srv_fd;
    unsigned char data[BUF_SIZE];
    int len;
    struct sockaddr_in caddr;
    socklen_t clen;
} pkt_t;

static void *handle(void *arg) {
    pkt_t *p = (pkt_t *)arg;
    int u = socket(AF_INET, SOCK_DGRAM, 0);
    if (u < 0) { free(p); return NULL; }
    struct timeval tv = {5, 0};
    setsockopt(u, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
    struct sockaddr_in up = {0};
    up.sin_family = AF_INET;
    up.sin_port = htons(UPSTREAM_PORT);
    up.sin_addr.s_addr = inet_addr("127.0.0.1");
    sendto(u, p->data, p->len, 0, (struct sockaddr*)&up, sizeof(up));
    unsigned char resp[BUF_SIZE];
    socklen_t ul = sizeof(up);
    int rlen = recvfrom(u, resp, sizeof(resp), 0, (struct sockaddr*)&up, &ul);
    close(u);
    if (rlen > 0)
        sendto(p->srv_fd, resp, rlen, 0, (struct sockaddr*)&p->caddr, p->clen);
    free(p);
    return NULL;
}

int main(void) {
    signal(SIGTERM, signal_handler);
    signal(SIGINT,  signal_handler);
    struct rlimit rl = {1048576, 1048576};
    setrlimit(RLIMIT_NOFILE, &rl);
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) { perror("socket"); return 1; }
    int opt = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(LISTEN_PORT);
    if (bind(fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind port 53"); close(fd); return 1;
    }
    fprintf(stderr, "[ELITE-X] EDNS Proxy running :%d -> :%d\n",
            LISTEN_PORT, UPSTREAM_PORT);
    while (running) {
        pkt_t *p = malloc(sizeof(pkt_t));
        if (!p) { sleep(1); continue; }
        p->srv_fd = fd;
        p->clen   = sizeof(p->caddr);
        p->len    = recvfrom(fd, p->data, BUF_SIZE, 0,
                             (struct sockaddr*)&p->caddr, &p->clen);
        if (p->len <= 0) { free(p); continue; }
        pthread_t tid;
        if (pthread_create(&tid, NULL, handle, p) == 0)
            pthread_detach(tid);
        else
            free(p);
    }
    close(fd);
    return 0;
}
CEOF2
        gcc -O2 -o /usr/local/bin/elite-x-edns-proxy-c /tmp/edns_proxy2.c -lpthread
        rm -f /tmp/edns_proxy2.c
        if [ -f /usr/local/bin/elite-x-edns-proxy-c ]; then
            chmod +x /usr/local/bin/elite-x-edns-proxy-c
            echo -e "${GREEN}✅ C EDNS Proxy compiled (retry ok)${NC}"
        else
            echo -e "${RED}❌ EDNS Proxy compilation failed completely. Check gcc installation.${NC}"
        fi
    fi
}

setup_manual_speed() {
    cat > /usr/local/bin/elite-x-speed <<'EOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

optimize_network() {
    echo -e "${YELLOW}⚡ Optimizing network for maximum speed...${NC}"
    
    sysctl -w net.core.rmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.core.wmem_max=134217728 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" >/dev/null 2>&1
    sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Network optimized!${NC}"
}

optimize_cpu() {
    echo -e "${YELLOW}⚡ Optimizing CPU performance...${NC}"
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "performance" > "$cpu" 2>/dev/null || true
    done
    
    echo -e "${GREEN}✅ CPU optimized!${NC}"
}

optimize_ram() {
    echo -e "${YELLOW}⚡ Optimizing RAM...${NC}"
    
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    
    echo -e "${GREEN}✅ RAM optimized!${NC}"
}

clean_junk() {
    echo -e "${YELLOW}🧹 Cleaning junk files...${NC}"
    
    apt clean 2>/dev/null
    apt autoclean 2>/dev/null
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
    
    echo -e "${GREEN}✅ Junk files cleaned!${NC}"
}

case "$1" in
    manual)
        optimize_network
        optimize_cpu
        optimize_ram
        clean_junk
        ;;
    clean)
        clean_junk
        ;;
    *)
        echo "Usage: elite-x-speed {manual|clean}"
        exit 1
        ;;
esac
EOF
    chmod +x /usr/local/bin/elite-x-speed
}

setup_auto_remover() {
    cat > /usr/local/bin/elite-x-cleaner <<'EOF'
#!/bin/bash

USER_DB="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
CONN_DB="/etc/elite-x/connections"

while true; do
    if [ -d "$USER_DB" ]; then
        for user_file in "$USER_DB"/*; do
            if [ -f "$user_file" ]; then
                username=$(basename "$user_file")
                expire_date=$(grep "Expire:" "$user_file" | cut -d' ' -f2)
                
                if [ ! -z "$expire_date" ]; then
                    current_date=$(date +%Y-%m-%d)
                    if [[ "$current_date" > "$expire_date" ]] || [ "$current_date" = "$expire_date" ]; then
                        userdel -r "$username" 2>/dev/null || true
                        rm -f "$user_file"
                        rm -f "$BW_DIR/${username}.usage"
                        rm -f "$CONN_DB/$username"
                    fi
                fi
            fi
        done
    fi
    sleep 3600
done
EOF
    chmod +x /usr/local/bin/elite-x-cleaner

    cat > /etc/systemd/system/elite-x-cleaner.service <<EOF
[Unit]
Description=ELITE-X Auto Remover
[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-cleaner
Restart=always
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable elite-x-cleaner.service
    systemctl start elite-x-cleaner.service
}

setup_updater() {
    cat > /usr/local/bin/elite-x-update <<'EOF'
#!/bin/bash

echo -e "\033[1;33m🔄 Checking for updates...\033[0m"

BACKUP_DIR="/root/elite-x-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r /etc/elite-x "$BACKUP_DIR/" 2>/dev/null || true
cp -r /etc/dnstt "$BACKUP_DIR/" 2>/dev/null || true

cd /tmp
rm -rf Elite-X-dns.sh
git clone https://github.com/NoXFiQ/Elite-X-dns.sh.git 2>/dev/null || {
    echo -e "\033[0;31m❌ Failed to download update\033[0m"
    exit 1
}

cd Elite-X-dns.sh
chmod +x *.sh

cp -r "$BACKUP_DIR/elite-x" /etc/ 2>/dev/null || true
cp -r "$BACKUP_DIR/dnstt" /etc/ 2>/dev/null || true

echo -e "\033[0;32m✅ Update complete!\033[0m"
EOF
    chmod +x /usr/local/bin/elite-x-update
}

show_banner
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}                    ACTIVATION REQUIRED                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${WHITE}Available Keys:${NC}"
echo -e "${GREEN}  Lifetime : Whtsapp +255713-628-668${NC}"
echo -e "${YELLOW}  Trial    : ELITE-X-TEST-0208 (2 days)${NC}"
echo ""
read -p "$(echo -e $CYAN"Activation Key: "$NC)" ACTIVATION_INPUT

mkdir -p /etc/elite-x
if ! activate_script "$ACTIVATION_INPUT"; then
    echo -e "${RED}❌ Invalid activation key! Installation cancelled.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Activation successful!${NC}"
sleep 1

if [ -f "$ACTIVATION_TYPE_FILE" ] && [ "$(cat "$ACTIVATION_TYPE_FILE")" = "temporary" ]; then
    echo -e "${YELLOW}⚠️  Trial version activated - expires in 2 days${NC}"
fi
sleep 2

set_timezone

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}                  ENTER YOUR SUBDOMAIN                          ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${WHITE}  Example: ns-ex.elitex.sbs                                 ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Subdomain: "$NC)" TDOMAIN

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${WHITE}  You entered: ${GREEN}$TDOMAIN${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

check_subdomain "$TDOMAIN"

echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║${GREEN}           NETWORK LOCATION OPTIMIZATION                          ${YELLOW}║${NC}"
echo -e "${YELLOW}╠═══════════════════════════════════════════════════════════════╣${NC}"
echo -e "${YELLOW}║${WHITE}  Select your VPS location:                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${GREEN}  [1] South Africa (Default - MTU 1800)                        ${YELLOW}║${NC}"
echo -e "${YELLOW}║${CYAN}  [2] USA                                                       ${YELLOW}║${NC}"
echo -e "${YELLOW}║${BLUE}  [3] Europe                                                    ${YELLOW}║${NC}"
echo -e "${YELLOW}║${PURPLE}  [4] Asia                                                      ${YELLOW}║${NC}"
echo -e "${YELLOW}║${YELLOW}  [5] Auto-detect                                                ${YELLOW}║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "$(echo -e $GREEN"Select location [1-5] [default: 1]: "$NC)" LOCATION_CHOICE
LOCATION_CHOICE=${LOCATION_CHOICE:-1}

MTU=1800
SELECTED_LOCATION="South Africa"

case $LOCATION_CHOICE in
    2)
        SELECTED_LOCATION="USA"
        echo -e "${CYAN}✅ USA selected${NC}"
        NEED_USA_OPT=1
        ;;
    3)
        SELECTED_LOCATION="Europe"
        echo -e "${BLUE}✅ Europe selected${NC}"
        NEED_EUROPE_OPT=1
        ;;
    4)
        SELECTED_LOCATION="Asia"
        echo -e "${PURPLE}✅ Asia selected${NC}"
        NEED_ASIA_OPT=1
        ;;
    5)
        SELECTED_LOCATION="Auto-detect"
        echo -e "${YELLOW}✅ Auto-detect selected${NC}"
        NEED_AUTO_OPT=1
        ;;
    *)
        SELECTED_LOCATION="South Africa"
        echo -e "${GREEN}✅ Using South Africa configuration${NC}"
        ;;
esac

echo "$SELECTED_LOCATION" > /etc/elite-x/location
echo "$MTU" > /etc/elite-x/mtu

DNSTT_PORT=5300
DNS_PORT=53

echo "==> ELITE-X INSTALLATION STARTING..."

if [ "$(id -u)" -ne 0 ]; then
  echo "[-] Run as root"
  exit 1
fi

mkdir -p /etc/elite-x/{banner,users,bandwidth,connections,banned}
echo "$TDOMAIN" > /etc/elite-x/subdomain

cat > /etc/elite-x/banner/default <<'EOF'
╔═════════════════════════════════════════╗
      WELCOME TO ELITE-X VPN SERVICE
╠═════════════════════════════════════════╣
     High Speed • Secure • Unlimited
╚═════════════════════════════════════════╝
EOF

cat > /etc/elite-x/banner/ssh-banner <<'EOF'
╔═════════════════════════════════════════╗
           ELITE-X VPN SERVICE             
    High Speed • Secure • Unlimited     
╚═════════════════════════════════════════╝
EOF

echo "Configuring SSH for VPN tunneling..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null || true

# Clean old entries
sed -i '/^Banner/d; /^Match User/d; /Include \/etc\/ssh\/sshd_config.d\/\*\.conf/d' \
    /etc/ssh/sshd_config 2>/dev/null

mkdir -p /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/elite-x-base.conf <<'SSHCONF'
# ELITE-X VPN Base Configuration v3.0
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes

AllowTcpForwarding yes
AllowAgentForwarding yes
GatewayPorts yes
PermitTunnel yes
PermitOpen any

TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 6
MaxStartups 500:30:1000
MaxSessions 500

Compression no
UseDNS no
LogLevel VERBOSE
IPQoS lowdelay throughput
SSHCONF

# Per-user banner config
cat > /etc/ssh/sshd_config.d/elite-x-users.conf <<'SSHCONF2'
# ELITE-X User Banners v3.0
SSHCONF2

# Add global banner entry
echo "Banner /etc/elite-x/banner/ssh-banner" >> /etc/ssh/sshd_config.d/elite-x-base.conf

# Include all configs
if ! grep -q "Include /etc/ssh/sshd_config.d" /etc/ssh/sshd_config; then
    echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
fi

systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
echo -e "${GREEN}✅ SSH configured for VPN tunneling${NC}"

echo "Stopping old services..."
for svc in dnstt dnstt-server slowdns dnstt-smart dnstt-elite-x dnstt-elite-x-proxy; do
  systemctl disable --now "$svc" 2>/dev/null || true
done

if [ -f /etc/systemd/resolved.conf ]; then
  echo "Configuring systemd-resolved..."
  sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf || true
  grep -q '^DNS=' /etc/systemd/resolved.conf \
    && sed -i 's/^DNS=.*/DNS=8.8.8.8 8.8.4.4/' /etc/systemd/resolved.conf \
    || echo "DNS=8.8.8.8 8.8.4.4" >> /etc/systemd/resolved.conf
  systemctl restart systemd-resolved
  ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
fi

echo "Installing dependencies..."
apt update -y
apt install -y curl gcc build-essential jq nano iptables iptables-persistent ethtool dnsutils bc

echo "Installing dnstt-server..."
curl -fsSL https://dnstt.network/dnstt-server-linux-amd64 -o /usr/local/bin/dnstt-server
chmod +x /usr/local/bin/dnstt-server

echo "Generating keys..."
mkdir -p /etc/dnstt

if [ -f /etc/dnstt/server.key ]; then
    echo -e "${YELLOW}⚠️  Existing keys found, removing...${NC}"
    chattr -i /etc/dnstt/server.key 2>/dev/null || true
    rm -f /etc/dnstt/server.key
    rm -f /etc/dnstt/server.pub
fi

cd /etc/dnstt
dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
cd ~

chmod 600 /etc/dnstt/server.key
chmod 644 /etc/dnstt/server.pub

echo "Creating dnstt-elite-x.service..."
cat >/etc/systemd/system/dnstt-elite-x.service <<EOF
[Unit]
Description=ELITE-X DNSTT Server
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-server -udp :${DNSTT_PORT} -mtu ${MTU} -privkey-file /etc/dnstt/server.key ${TDOMAIN} 127.0.0.1:22
Restart=always
RestartSec=3
KillSignal=SIGTERM
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# ── Compile & install C EDNS Proxy (badala ya Python) ──
setup_c_edns_proxy

cat >/etc/systemd/system/dnstt-elite-x-proxy.service <<EOF
[Unit]
Description=ELITE-X C EDNS Proxy
After=network-online.target dnstt-elite-x.service
Requires=dnstt-elite-x.service

[Service]
Type=simple
ExecStart=/usr/local/bin/elite-x-edns-proxy-c
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

command -v ufw >/dev/null && ufw allow 22/tcp && ufw allow 53/udp || true

systemctl daemon-reload
systemctl enable dnstt-elite-x.service dnstt-elite-x-proxy.service
systemctl start dnstt-elite-x.service dnstt-elite-x-proxy.service

# ── C monitors (bandwidth + connections) ──
setup_c_bandwidth_monitor
setup_c_connection_monitor
setup_manual_speed
setup_auto_remover
setup_updater

if [ ! -z "${NEED_USA_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying USA optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X USA Optimization
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ USA optimizations applied${NC}"
elif [ ! -z "${NEED_EUROPE_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying Europe optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X Europe Optimization
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ Europe optimizations applied${NC}"
elif [ ! -z "${NEED_ASIA_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying Asia optimizations...${NC}"
    cat >> /etc/sysctl.conf <<EOF
# ELITE-X Asia Optimization
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_notsent_lowat = 8192
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl -p
    echo -e "${GREEN}✅ Asia optimizations applied${NC}"
elif [ ! -z "${NEED_AUTO_OPT:-}" ]; then
    echo -e "${YELLOW}🔄 Applying auto-detected optimizations...${NC}"
    usa_latency=$(ping -c 2 -W 2 8.8.8.8 2>/dev/null | tail -1 | awk -F '/' '{print $5}' | cut -d. -f1)
    if [ ! -z "$usa_latency" ] && [ "$usa_latency" -lt 200 ]; then
        cat >> /etc/sysctl.conf <<EOF
# ELITE-X Auto USA Optimization
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    else
        cat >> /etc/sysctl.conf <<EOF
# ELITE-X Auto Default Optimization
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 65536 33554432
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    fi
    sysctl -p
    echo -e "${GREEN}✅ Auto optimizations applied${NC}"
fi

for iface in $(ls /sys/class/net/ | grep -v lo); do
    ethtool -K $iface tx off sg off tso off 2>/dev/null || true
    ip link set dev $iface txqueuelen 10000 2>/dev/null || true
done

systemctl daemon-reload
systemctl restart dnstt-elite-x dnstt-elite-x-proxy

cat > /etc/cron.hourly/elite-x-expiry <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ]; then
    /usr/local/bin/elite-x --check-expiry
fi
EOF
chmod +x /etc/cron.hourly/elite-x-expiry

cat >/usr/local/bin/elite-x-user <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

UD="/etc/elite-x/users"
BW_DIR="/etc/elite-x/bandwidth"
CONN_DB="/etc/elite-x/connections"
mkdir -p $UD $BW_DIR $CONN_DB

# ── Get connection count via /proc ──
get_connection_count() {
    local u="$1" c=0
    local _uid; _uid=$(id -u "$u" 2>/dev/null || echo "")
    if [ -n "$_uid" ]; then
        for _pd in /proc/[0-9]*/; do
            [ -f "${_pd}comm" ] || continue
            [ "$(cat "${_pd}comm" 2>/dev/null)" = "sshd" ] || continue
            local _puid; _puid=$(awk '/^Uid:/{print $2}' "${_pd}status" 2>/dev/null)
            [ "$_puid" = "$_uid" ] || continue
            local _ppid; _ppid=$(awk '{print $4}' "${_pd}stat" 2>/dev/null)
            [ "$_ppid" = "1" ] && continue
            c=$((c + 1))
        done
    fi
    echo "${c:-0}"
}

# ── Get bandwidth usage in GB ──
get_bandwidth_usage_gb() {
    local u="$1"; local f="$BW_DIR/${u}.usage"
    if [ -f "$f" ]; then
        local raw; raw=$(cat "$f" 2>/dev/null | tr -d ' \n\r')
        [[ "$raw" =~ ^[0-9]+$ ]] || raw=0
        echo "scale=2; $raw / 1073741824" | bc 2>/dev/null || echo "0.00"
    else
        echo "0.00"
    fi
}

add_user() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}              CREATE SSH + DNS USER                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    read -p "$(echo -e $GREEN"Username: "$NC)" username
    read -p "$(echo -e $GREEN"Password: "$NC)" password
    read -p "$(echo -e $GREEN"Expire days: "$NC)" days
    read -p "$(echo -e $GREEN"Connection limit [1]: "$NC)" conn_limit
    conn_limit=${conn_limit:-1}
    [[ ! "$conn_limit" =~ ^[0-9]+$ ]] && conn_limit=1
    read -p "$(echo -e $GREEN"Bandwidth GB (0=unlimited) [0]: "$NC)" bw
    bw=${bw:-0}
    [[ ! "$bw" =~ ^[0-9]+\.?[0-9]*$ ]] && bw=0
    
    if id "$username" &>/dev/null; then
        echo -e "${RED}User already exists!${NC}"
        return
    fi
    
    useradd -m -s /bin/false "$username"
    echo "$username:$password" | chpasswd
    
    expire_date=$(date -d "+$days days" +"%Y-%m-%d")
    chage -E "$expire_date" "$username"
    
    cat > $UD/$username <<INFO
Username: $username
Password: $password
Expire: $expire_date
Conn_Limit: $conn_limit
Bandwidth_GB: $bw
Created: $(date +"%Y-%m-%d")
INFO
    
    echo "0" > "$BW_DIR/${username}.usage"

    # Register user in SSH config so tunneling/forwarding works
    mkdir -p /etc/ssh/sshd_config.d
    if [ ! -f /etc/ssh/sshd_config.d/elite-x-users.conf ]; then
        echo "# ELITE-X User Banners v3.0" > /etc/ssh/sshd_config.d/elite-x-users.conf
    fi
    # Remove old entry for this user if exists, then add fresh
    sed -i "/^Match User ${username}$/,/^$/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null || true
    printf "\nMatch User %s\n    AllowTcpForwarding yes\n    GatewayPorts yes\n    PermitTunnel yes\n    Banner /etc/elite-x/banner/ssh-banner\n" \
        "$username" >> /etc/ssh/sshd_config.d/elite-x-users.conf
    # Ensure Include line exists
    if ! grep -q "Include /etc/ssh/sshd_config.d" /etc/ssh/sshd_config; then
        echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config
    fi
    systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true

    SERVER=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "?")
    PUBKEY=$(cat /etc/dnstt/server.pub 2>/dev/null || echo "Not generated")
    local bw_disp="Unlimited"; [ "$bw" != "0" ] && bw_disp="${bw} GB"
    
    clear
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${YELLOW}                  USER DETAILS                                   ${GREEN}║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${WHITE}  Username  :${CYAN} $username${NC}"
    echo -e "${GREEN}║${WHITE}  Password  :${CYAN} $password${NC}"
    echo -e "${GREEN}║${WHITE}  Server    :${CYAN} $SERVER${NC}"
    echo -e "${GREEN}║${WHITE}  Public Key:${CYAN} $PUBKEY${NC}"
    echo -e "${GREEN}║${WHITE}  Expire    :${CYAN} $expire_date${NC}"
    echo -e "${GREEN}║${WHITE}  Max Login :${CYAN} $conn_limit${NC}"
    echo -e "${GREEN}║${WHITE}  Bandwidth :${CYAN} $bw_disp${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

list_users() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}                     ACTIVE USERS                               ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    
    if [ -z "$(ls -A $UD 2>/dev/null)" ]; then
        echo -e "${RED}No users found${NC}"
        return
    fi

    # Single /proc scan - build uid→sessions map
    declare -A _sess_map
    for _pd in /proc/[0-9]*/; do
        [ -f "${_pd}comm" ] || continue
        [ "$(cat "${_pd}comm" 2>/dev/null)" = "sshd" ] || continue
        local _ppid; _ppid=$(awk '{print $4}' "${_pd}stat" 2>/dev/null)
        [ "$_ppid" = "1" ] && continue
        local _puid; _puid=$(awk '/^Uid:/{print $2}' "${_pd}status" 2>/dev/null)
        [ -n "$_puid" ] && _sess_map[$_puid]=$(( ${_sess_map[$_puid]:-0} + 1 ))
    done

    printf "%-12s %-10s %-8s %-14s %-8s\n" "USERNAME" "EXPIRE" "LOGIN" "BANDWIDTH" "STATUS"
    echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"
    
    for user in $UD/*; do
        [ ! -f "$user" ] && continue
        u=$(basename "$user")
        ex=$(awk '/^Expire:/{print $2}' "$user" | tr -d ' \n')
        limit=$(awk '/^Conn_Limit:/{print $2}' "$user" | tr -d ' \n')
        [[ "$limit" =~ ^[0-9]+$ ]] || limit=1
        bw_limit=$(awk '/^Bandwidth_GB:/{print $2}' "$user" | tr -d ' \n')
        [[ "$bw_limit" =~ ^[0-9]+\.?[0-9]*$ ]] || bw_limit=0

        # Connection count from pre-built map
        local _uid; _uid=$(id -u "$u" 2>/dev/null || echo "")
        local cc=0
        [ -n "$_uid" ] && cc=${_sess_map[$_uid]:-0}
        [[ "$cc" =~ ^[0-9]+$ ]] || cc=0

        # Bandwidth in GB
        local raw_bytes=0
        [ -f "$BW_DIR/${u}.usage" ] && {
            raw_bytes=$(cat "$BW_DIR/${u}.usage" 2>/dev/null | tr -d ' \n\r')
            [[ "$raw_bytes" =~ ^[0-9]+$ ]] || raw_bytes=0
        }
        local total_gb; total_gb=$(echo "scale=2; $raw_bytes / 1073741824" | bc 2>/dev/null || echo "0.00")

        # Status
        local st
        if passwd -S "$u" 2>/dev/null | grep -q "L"; then
            st="${RED}LOCKED${NC}"
        elif [ "$cc" -gt 0 ]; then
            st="${GREEN}ONLINE${NC}"
        else
            st="${YELLOW}OFFLINE${NC}"
        fi

        # Display: connection as cc/limit  bandwidth as total_gb/bw_limit GB
        local ld; [ "$cc" -ge "$limit" ] && ld="${RED}${cc}/${limit}${NC}" || ld="${GREEN}${cc}/${limit}${NC}"
        local bd
        [ "$bw_limit" != "0" ] && bd="${total_gb}/${bw_limit}GB" || bd="${total_gb}GB/∞"

        printf "%-12s %-10s %-8b %-14s %-8b\n" "$u" "$ex" "$ld" "$bd" "$st"
    done
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    show_quote
}

lock_user() { 
    read -p "Username: " u
    usermod -L "$u" 2>/dev/null && echo -e "${GREEN}✅ Locked${NC}" || echo -e "${RED}❌ Failed${NC}"
    show_quote
}

unlock_user() { 
    read -p "Username: " u
    usermod -U "$u" 2>/dev/null && echo -e "${GREEN}✅ Unlocked${NC}" || echo -e "${RED}❌ Failed${NC}"
    show_quote
}

delete_user() { 
    read -p "Username: " u
    userdel -r "$u" 2>/dev/null
    rm -f $UD/$u "$BW_DIR/${u}.usage" "$CONN_DB/$u"
    # Remove from SSH config
    sed -i "/^Match User ${u}$/,/^$/d" /etc/ssh/sshd_config.d/elite-x-users.conf 2>/dev/null || true
    systemctl reload sshd 2>/dev/null || true
    echo -e "${GREEN}✅ Deleted${NC}"
    show_quote
}

case $1 in
    add) add_user ;;
    list) list_users ;;
    lock) lock_user ;;
    unlock) unlock_user ;;
    del) delete_user ;;
    *) echo "Usage: elite-x-user {add|list|lock|unlock|del}" ;;
esac
EOF
chmod +x /usr/local/bin/elite-x-user

# ========== MAIN MENU ==========
cat >/usr/local/bin/elite-x <<'EOF'
#!/bin/bash

RED='\033[0;31m';GREEN='\033[0;32m';YELLOW='\033[1;33m';CYAN='\033[0;36m'
PURPLE='\033[0;35m';WHITE='\033[1;37m';BOLD='\033[1m';NC='\033[0m'

show_quote() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}            Always Remember ELITE-X when you see X            ${CYAN}║${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

if [ -f /tmp/elite-x-running ]; then
    exit 0
fi
touch /tmp/elite-x-running
trap 'rm -f /tmp/elite-x-running' EXIT

check_expiry_menu() {
    if [ -f "/etc/elite-x/activation_type" ] && [ -f "/etc/elite-x/activation_date" ] && [ -f "/etc/elite-x/expiry_days" ]; then
        local act_type=$(cat "/etc/elite-x/activation_type")
        if [ "$act_type" = "temporary" ]; then
            local act_date=$(cat "/etc/elite-x/activation_date")
            local expiry_days=$(cat "/etc/elite-x/expiry_days")
            local current_date=$(date +%s)
            local expiry_date=$(date -d "$act_date + $expiry_days days" +%s)
            
            if [ $current_date -ge $expiry_date ]; then
                echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║${YELLOW}           TRIAL PERIOD EXPIRED                                  ${RED}║${NC}"
                echo -e "${RED}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${RED}║${WHITE}  Your 2-day trial has ended.                                  ${RED}║${NC}"
                echo -e "${RED}║${WHITE}  Script will now uninstall itself...                         ${RED}║${NC}"
                echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
                sleep 3
                
                systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner 2>/dev/null || true
                systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner 2>/dev/null || true
                rm -f /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
                rm -rf /etc/dnstt /etc/elite-x
                rm -f /usr/local/bin/{dnstt-*,elite-x*}
                sed -i '/^Banner/d' /etc/ssh/sshd_config
                systemctl restart sshd
                
                echo -e "${GREEN}✅ ELITE-X has been uninstalled.${NC}"
                rm -f /tmp/elite-x-running
                exit 0
            fi
        fi
    fi
}

check_expiry_menu

# ── Helper: get connection count from /proc ──
get_connection_count() {
    local u="$1" c=0
    local _uid; _uid=$(id -u "$u" 2>/dev/null || echo "")
    if [ -n "$_uid" ]; then
        for _pd in /proc/[0-9]*/; do
            [ -f "${_pd}comm" ] || continue
            [ "$(cat "${_pd}comm" 2>/dev/null)" = "sshd" ] || continue
            local _puid; _puid=$(awk '/^Uid:/{print $2}' "${_pd}status" 2>/dev/null)
            [ "$_puid" = "$_uid" ] || continue
            local _ppid; _ppid=$(awk '{print $4}' "${_pd}stat" 2>/dev/null)
            [ "$_ppid" = "1" ] && continue
            c=$((c + 1))
        done
    fi
    echo "${c:-0}"
}

show_dashboard() {
    clear
    
    IP=$(cat /etc/elite-x/cached_ip 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "Unknown")
    LOC=$(cat /etc/elite-x/cached_location 2>/dev/null || echo "Unknown")
    ISP=$(cat /etc/elite-x/cached_isp 2>/dev/null || echo "Unknown")
    RAM=$(free -m | awk '/^Mem:/{print $3"/"$2"MB"}')
    SUB=$(cat /etc/elite-x/subdomain 2>/dev/null || echo "Not configured")
    ACTIVATION_KEY=$(cat /etc/elite-x/key 2>/dev/null || echo "Unknown")
    EXP=$(cat /etc/elite-x/expiry 2>/dev/null || echo "Unknown")
    LOCATION=$(cat /etc/elite-x/location 2>/dev/null || echo "South Africa")
    CURRENT_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")

    # ── Count total connections ──
    TOTAL_CONN=0
    TOTAL_USERS=0
    BW_DIR="/etc/elite-x/bandwidth"
    UD="/etc/elite-x/users"
    TOTAL_USAGE_GB="0.00"

    if [ -d "$UD" ]; then
        # Single /proc scan
        declare -A _sess_map
        for _pd in /proc/[0-9]*/; do
            [ -f "${_pd}comm" ] || continue
            [ "$(cat "${_pd}comm" 2>/dev/null)" = "sshd" ] || continue
            _ppid=$(awk '{print $4}' "${_pd}stat" 2>/dev/null)
            [ "$_ppid" = "1" ] && continue
            _puid=$(awk '/^Uid:/{print $2}' "${_pd}status" 2>/dev/null)
            [ -n "$_puid" ] && _sess_map[$_puid]=$(( ${_sess_map[$_puid]:-0} + 1 ))
        done

        TOTAL_BYTES=0
        for ufile in "$UD"/*; do
            [ -f "$ufile" ] || continue
            TOTAL_USERS=$((TOTAL_USERS + 1))
            uname=$(basename "$ufile")
            _uid=$(id -u "$uname" 2>/dev/null || echo "")
            [ -n "$_uid" ] && TOTAL_CONN=$((TOTAL_CONN + ${_sess_map[$_uid]:-0}))
            if [ -f "$BW_DIR/${uname}.usage" ]; then
                rb=$(cat "$BW_DIR/${uname}.usage" 2>/dev/null | tr -d ' \n\r')
                [[ "$rb" =~ ^[0-9]+$ ]] && TOTAL_BYTES=$((TOTAL_BYTES + rb))
            fi
        done
        TOTAL_USAGE_GB=$(echo "scale=2; $TOTAL_BYTES / 1073741824" | bc 2>/dev/null || echo "0.00")
    fi

    DNS=$(systemctl is-active dnstt-elite-x 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    PRX=$(systemctl is-active dnstt-elite-x-proxy 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    BWM=$(systemctl is-active elite-x-bandwidth 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    CNM=$(systemctl is-active elite-x-connmon 2>/dev/null | grep -q active && echo "${GREEN}●${NC}" || echo "${RED}●${NC}")
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${YELLOW}${BOLD}                    ELITE-X SLOWDNS v3.0                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Subdomain :${GREEN} $SUB${NC}"
    echo -e "${CYAN}║${WHITE}  IP        :${GREEN} $IP${NC}"
    echo -e "${CYAN}║${WHITE}  Location  :${GREEN} $LOC${NC}"
    echo -e "${CYAN}║${WHITE}  ISP       :${GREEN} $ISP${NC}"
    echo -e "${CYAN}║${WHITE}  RAM       :${GREEN} $RAM${NC}"
    echo -e "${CYAN}║${WHITE}  VPS Loc   :${GREEN} $LOCATION${NC}"
    echo -e "${CYAN}║${WHITE}  MTU       :${GREEN} $CURRENT_MTU${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Users     :${GREEN} $TOTAL_USERS${NC}"
    echo -e "${CYAN}║${WHITE}  Connections:${GREEN} $TOTAL_CONN${NC}"
    echo -e "${CYAN}║${WHITE}  Usage     :${GREEN} $TOTAL_USAGE_GB GB${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Services  : DNS:$DNS PRX:$PRX BWM:$BWM CNM:$CNM${NC}"
    echo -e "${CYAN}║${WHITE}  Developer :${PURPLE} ELITE-X TEAM${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${WHITE}  Act Key   :${YELLOW} $ACTIVATION_KEY${NC}"
    echo -e "${CYAN}║${WHITE}  Expiry    :${YELLOW} $EXP${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${YELLOW}${BOLD}                      SETTINGS MENU                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${WHITE}  [8]  🔑 View Public Key${NC}"
        echo -e "${CYAN}║${WHITE}  [9]  Change MTU Value (Manual)${NC}"
        echo -e "${CYAN}║${WHITE}  [10] ⚡ Manual Speed Optimization${NC}"
        echo -e "${CYAN}║${WHITE}  [11] 🧹 Clean Junk Files${NC}"
        echo -e "${CYAN}║${WHITE}  [12] 🔄 Auto Expired Account Remover${NC}"
        echo -e "${CYAN}║${WHITE}  [13] 📦 Update Script${NC}"
        echo -e "${CYAN}║${WHITE}  [14] Restart All Services${NC}"
        echo -e "${CYAN}║${WHITE}  [15] Reboot VPS${NC}"
        echo -e "${CYAN}║${WHITE}  [16] Uninstall Script${NC}"
        echo -e "${CYAN}║${WHITE}  [17] 🌍 Re-apply Location Optimization${NC}"
        echo -e "${CYAN}║${WHITE}  [0]  Back to Main Menu${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Settings option: "$NC)" ch
        
        case $ch in
            8)
                echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${YELLOW}                    PUBLIC KEY (FULL)                           ${CYAN}║${NC}"
                echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${CYAN}║${GREEN}  $(cat /etc/dnstt/server.pub)${NC}"
                echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
                read -p "Press Enter to continue..."
                ;;
            9)
                echo "Current MTU: $(cat /etc/elite-x/mtu)"
                read -p "New MTU (1000-5000): " mtu
                [[ "$mtu" =~ ^[0-9]+$ ]] && [ $mtu -ge 1000 ] && [ $mtu -le 5000 ] && {
                    echo "$mtu" > /etc/elite-x/mtu
                    sed -i "s/-mtu [0-9]*/-mtu $mtu/" /etc/systemd/system/dnstt-elite-x.service
                    systemctl daemon-reload
                    systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                    echo -e "${GREEN}✅ MTU updated to $mtu${NC}"
                } || echo -e "${RED}❌ Invalid (must be 1000-5000)${NC}"
                read -p "Press Enter to continue..."
                ;;
            10) elite-x-speed manual; read -p "Press Enter to continue..." ;;
            11) elite-x-speed clean; read -p "Press Enter to continue..." ;;
            12)
                systemctl enable --now elite-x-cleaner.service
                echo -e "${GREEN}✅ Auto remover started${NC}"
                read -p "Press Enter to continue..."
                ;;
            13) elite-x-update; read -p "Press Enter to continue..." ;;
            14)
                systemctl restart dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon sshd
                echo -e "${GREEN}✅ Services restarted${NC}"
                read -p "Press Enter to continue..."
                ;;
            15)
                read -p "Reboot? (y/n): " c
                [ "$c" = "y" ] && reboot
                ;;
            16)
                read -p "Uninstall? (YES): " c
                [ "$c" = "YES" ] && {
                    systemctl stop dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner
                    systemctl disable dnstt-elite-x dnstt-elite-x-proxy elite-x-bandwidth elite-x-connmon elite-x-cleaner
                    rm -f /etc/systemd/system/{dnstt-elite-x*,elite-x-*}
                    rm -rf /etc/dnstt /etc/elite-x
                    rm -f /usr/local/bin/{dnstt-*,elite-x*}
                    sed -i '/^Banner/d' /etc/ssh/sshd_config
                    systemctl restart sshd
                    echo -e "${GREEN}✅ Uninstalled${NC}"
                    rm -f /tmp/elite-x-running
                    exit 0
                }
                read -p "Press Enter to continue..."
                ;;
            17)
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}           RE-APPLY LOCATION OPTIMIZATION                        ${NC}"
                echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
                echo -e "${WHITE}Select your VPS location:${NC}"
                echo -e "${GREEN}  1. South Africa (MTU 1800)${NC}"
                echo -e "${CYAN}  2. USA${NC}"
                echo -e "${BLUE}  3. Europe${NC}"
                echo -e "${PURPLE}  4. Asia${NC}"
                echo -e "${YELLOW}  5. Auto-detect${NC}"
                read -p "Choice: " opt_choice
                
                case $opt_choice in
                    1) echo "South Africa" > /etc/elite-x/location
                       echo "1800" > /etc/elite-x/mtu
                       sed -i "s/-mtu [0-9]*/-mtu 1800/" /etc/systemd/system/dnstt-elite-x.service
                       systemctl daemon-reload
                       systemctl restart dnstt-elite-x dnstt-elite-x-proxy
                       echo -e "${GREEN}✅ South Africa selected (MTU 1800)${NC}" ;;
                    2) echo "USA" > /etc/elite-x/location
                       echo -e "${GREEN}✅ USA selected${NC}" ;;
                    3) echo "Europe" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Europe selected${NC}" ;;
                    4) echo "Asia" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Asia selected${NC}" ;;
                    5) echo "Auto-detect" > /etc/elite-x/location
                       echo -e "${GREEN}✅ Auto-detect selected${NC}" ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu() {
    while true; do
        show_dashboard
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${GREEN}${BOLD}                         MAIN MENU                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${WHITE}  [1] Create SSH + DNS User${NC}"
        echo -e "${CYAN}║${WHITE}  [2] List All Users${NC}"
        echo -e "${CYAN}║${WHITE}  [3] Lock User${NC}"
        echo -e "${CYAN}║${WHITE}  [4] Unlock User${NC}"
        echo -e "${CYAN}║${WHITE}  [5] Delete User${NC}"
        echo -e "${CYAN}║${WHITE}  [6] Create/Edit Banner${NC}"
        echo -e "${CYAN}║${WHITE}  [7] Delete Banner${NC}"
        echo -e "${CYAN}║${RED}  [S] ⚙️  Settings${NC}"
        echo -e "${CYAN}║${WHITE}  [00] Exit${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "$(echo -e $GREEN"Main menu option: "$NC)" ch
        
        case $ch in
            1) elite-x-user add; read -p "Press Enter to continue..." ;;
            2) elite-x-user list; read -p "Press Enter to continue..." ;;
            3) elite-x-user lock; read -p "Press Enter to continue..." ;;
            4) elite-x-user unlock; read -p "Press Enter to continue..." ;;
            5) elite-x-user del; read -p "Press Enter to continue..." ;;
            6)
                [ -f /etc/elite-x/banner/custom ] || cp /etc/elite-x/banner/default /etc/elite-x/banner/custom
                nano /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/custom /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner saved${NC}"
                read -p "Press Enter to continue..."
                ;;
            7)
                rm -f /etc/elite-x/banner/custom
                cp /etc/elite-x/banner/default /etc/elite-x/banner/ssh-banner
                systemctl restart sshd
                echo -e "${GREEN}✅ Banner deleted${NC}"
                read -p "Press Enter to continue..."
                ;;
            [Ss]) settings_menu ;;
            00|0) 
                rm -f /tmp/elite-x-running
                show_quote
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu
EOF
chmod +x /usr/local/bin/elite-x

echo "Caching network information for fast login..."
IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "Unknown")
echo "$IP" > /etc/elite-x/cached_ip

if [ "$IP" != "Unknown" ]; then
    LOCATION_INFO=$(curl -s http://ip-api.com/json/$IP 2>/dev/null)
    echo "$LOCATION_INFO" | jq -r '.city + ", " + .country' 2>/dev/null > /etc/elite-x/cached_location || echo "Unknown" > /etc/elite-x/cached_location
    echo "$LOCATION_INFO" | jq -r '.isp' 2>/dev/null > /etc/elite-x/cached_isp || echo "Unknown" > /etc/elite-x/cached_isp
else
    echo "Unknown" > /etc/elite-x/cached_location
    echo "Unknown" > /etc/elite-x/cached_isp
fi

cat > /etc/profile.d/elite-x-dashboard.sh <<'EOF'
#!/bin/bash
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    rm -f /tmp/elite-x-running 2>/dev/null
    /usr/local/bin/elite-x
fi
EOF
chmod +x /etc/profile.d/elite-x-dashboard.sh

cat >> ~/.bashrc <<'EOF'
if [ -f /usr/local/bin/elite-x ] && [ -z "$ELITE_X_SHOWN" ]; then
    export ELITE_X_SHOWN=1
    rm -f /tmp/elite-x-running 2>/dev/null
    /usr/local/bin/elite-x
fi
EOF

echo "alias menu='elite-x'" >> ~/.bashrc
echo "alias elitex='elite-x'" >> ~/.bashrc

if [ ! -f /etc/elite-x/key ]; then
    if [ -f "$ACTIVATION_FILE" ]; then
        cp "$ACTIVATION_FILE" /etc/elite-x/key
    else
        echo "$ACTIVATION_KEY" > /etc/elite-x/key
    fi
fi

echo "╔════════════════════════════════════╗"
echo " ELITE-X INSTALLED SUCCESSFULLY "
echo "╚════════════════════════════════════╝"
EXPIRY_INFO=$(cat /etc/elite-x/expiry 2>/dev/null || echo "Lifetime")
FINAL_MTU=$(cat /etc/elite-x/mtu 2>/dev/null || echo "1800")
ACTIVATION_KEY=$(cat /etc/elite-x/key 2>/dev/null || echo "ELITE-X")
echo "DOMAIN  : ${TDOMAIN}"
echo "LOCATION: ${SELECTED_LOCATION}"
echo "KEY : ${ACTIVATION_KEY}"
echo "KEY EXPIRE  : ${EXPIRY_INFO}"
echo "╚════════════════════════════════════╝"
show_quote

read -p "Open menu now? (y/n): " open
if [ "$open" = "y" ]; then
    echo -e "${GREEN}Opening dashboard...${NC}"
    sleep 1
    /usr/local/bin/elite-x
else
    echo -e "${YELLOW}You can type 'menu' or 'elite-x' anytime to open the dashboard.${NC}"
fi

self_destruct
