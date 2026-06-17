#!/bin/bash
#############################################################
# NetherEye - Full Recon to Vulnerability Toolkit
# Author: Sonia
# Description: Single-target recon, enumeration, OSINT and
#              vulnerability assessment automation framework
#############################################################

# ===================== COLORS =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ===================== GLOBALS =====================
TARGET=""
OUTDIR=""
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
AUTO_MODE="0"

# ===================== BANNER =====================
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "    _   __     __  __              ______         "
    echo "   / | / /__  / /_/ /_  ___  _____/ ____/_  _____ "
    echo "  /  |/ / _ \\/ __/ __ \\/ _ \\/ ___/ __/ / / / / _ \\"
    echo " / /|  /  __/ /_/ / / /  __/ /  / /___/ /_/ /  __/"
    echo "/_/ |_/\\___/\\__/_/ /_/\\___/_/  /_____/\\__, /\\___/ "
    echo "                                     /____/       "
    echo -e "${NC}"
    echo -e "${YELLOW}        Full Recon -> Enumeration -> OSINT -> Vulnerability Toolkit${NC}"
    echo -e "${MAGENTA}                     For Authorized Testing Only${NC}"
    echo ""
}

# ===================== UTILS =====================
log_info()    { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[-]${NC} $1"; }
section()     { echo -e "\n${CYAN}${BOLD}========== $1 ==========${NC}\n"; }

# Check if a tool exists, else skip gracefully
check_tool() {
    local tool=$1
    if ! command -v "$tool" &> /dev/null; then
        log_warn "$tool not found - skipping this module. (install: sudo apt install $tool)"
        return 1
    fi
    return 0
}

press_enter() {
    echo ""
    read -p "Press Enter to continue..." dummy
}

# ===================== TARGET SETUP =====================
get_target() {
    echo -e "${YELLOW}Enter target domain or IP:${NC} "
    read -p "> " TARGET
    if [[ -z "$TARGET" ]]; then
        log_error "Target cannot be empty."
        get_target
    fi
    OUTDIR="nethereye_${TARGET//[^a-zA-Z0-9]/_}_${TIMESTAMP}"
    mkdir -p "$OUTDIR"
    log_success "Target set: $TARGET"
    log_success "Output directory: $OUTDIR"
}

#############################################################
# PHASE 1: IP & SUBDOMAIN DISCOVERY
#############################################################
module_ip_subdomain() {
    section "PHASE 1: IP & Subdomain Discovery"
    local out="$OUTDIR/01_ip_subdomain.txt"

    log_info "Resolving target IP..."
    {
        echo "--- IP Resolution ---"
        host "$TARGET" 2>/dev/null || getent hosts "$TARGET"
    } | tee "$out"

    if check_tool subfinder; then
        log_info "Running subfinder for subdomain enumeration..."
        echo -e "\n--- Subdomains (subfinder) ---" | tee -a "$out"
        subfinder -d "$TARGET" -silent 2>/dev/null | tee -a "$out"
    elif check_tool amass; then
        log_info "Running amass for subdomain enumeration..."
        echo -e "\n--- Subdomains (amass) ---" | tee -a "$out"
        amass enum -passive -d "$TARGET" 2>/dev/null | tee -a "$out"
    else
        log_warn "No subdomain tool found (subfinder/amass). Skipping subdomain enum."
    fi

    log_success "Phase 1 saved to $out"
}

#############################################################
# PHASE 2: LIVE HOST CHECK
#############################################################
module_live_host() {
    section "PHASE 2: Live Host Check"
    local out="$OUTDIR/02_live_host.txt"

    log_info "Pinging target..."
    {
        echo "--- Ping Test ---"
        ping -c 3 "$TARGET" 2>&1
    } | tee "$out"

    if check_tool httpx; then
        log_info "Checking HTTP/HTTPS live status with httpx..."
        echo -e "\n--- HTTP(S) Probe (httpx) ---" | tee -a "$out"
        echo "$TARGET" | httpx -silent -status-code -title 2>/dev/null | tee -a "$out"
    else
        log_warn "httpx not found, doing basic curl check instead."
        echo -e "\n--- Basic curl check ---" | tee -a "$out"
        for proto in http https; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$proto://$TARGET")
            echo "$proto://$TARGET -> HTTP $code" | tee -a "$out"
        done
    fi

    log_success "Phase 2 saved to $out"
}

#############################################################
# PHASE 3: PORT SCAN + SERVICE + OS DETECTION
#############################################################
module_port_scan() {
    section "PHASE 3: Open Ports, Services & OS Detection"
    local out="$OUTDIR/03_ports_services_os.txt"

    if ! check_tool nmap; then
        log_error "nmap is required for this module. Skipping."
        return
    fi

    local port_flag="--top-ports 1000"
    if [[ "$AUTO_MODE" == "1" ]]; then
        log_info "Auto mode: using fast scan (top 1000 ports). Use manual menu for full port scan."
    else
        echo -e "${YELLOW}Scan speed:${NC}"
        echo " 1) Fast (top 1000 ports)"
        echo " 2) Full (all 65535 ports - slow)"
        read -p "> " speed_choice
        [[ "$speed_choice" == "2" ]] && port_flag="-p-"
    fi

    log_info "Running nmap (service version + OS detection)... this may take a while."
    nmap -sV -O --osscan-guess -T4 $port_flag "$TARGET" -oN "$out" 2>&1
    cat "$out" 2>/dev/null

    log_success "Phase 3 saved to $out"
}

#############################################################
# PHASE 4: WEBSERVER, FRAMEWORK, CMS FINGERPRINT
#############################################################
module_web_fingerprint() {
    section "PHASE 4: Webserver / Framework / CMS Fingerprint"
    local out="$OUTDIR/04_web_fingerprint.txt"

    log_info "Grabbing HTTP headers..."
    {
        echo "--- HTTP Headers ---"
        curl -sI -m 10 "http://$TARGET"
        echo ""
        curl -sI -m 10 "https://$TARGET"
    } | tee "$out"

    if check_tool whatweb; then
        log_info "Running whatweb for CMS/framework/version fingerprinting..."
        echo -e "\n--- WhatWeb Fingerprint ---" | tee -a "$out"
        whatweb -a 3 "$TARGET" 2>/dev/null | tee -a "$out"
    else
        log_warn "whatweb not found. Install for CMS/framework detection: sudo apt install whatweb"
    fi

    log_success "Phase 4 saved to $out"
}

#############################################################
# PHASE 5: WEB API / HIDDEN RESOURCES / SHARED FILES
#############################################################
module_hidden_resources() {
    section "PHASE 5: Web API, Hidden Resources & Shared Files"
    local out="$OUTDIR/05_hidden_resources.txt"

    if check_tool ffuf; then
        log_info "Running ffuf directory/api brute-force (common wordlist)..."
        local wordlist="/usr/share/wordlists/dirb/common.txt"
        if [[ -f "$wordlist" ]]; then
            echo "--- FFUF Directory/API Discovery ---" | tee "$out"
            ffuf -u "http://$TARGET/FUZZ" -w "$wordlist" -mc 200,204,301,302,307,401,403 -t 40 -of csv -o "$OUTDIR/05_ffuf_raw.csv" 2>/dev/null | tee -a "$out"
        else
            log_warn "Default wordlist not found at $wordlist. Skipping ffuf scan."
        fi
    elif check_tool gobuster; then
        log_info "Running gobuster directory discovery..."
        gobuster dir -u "http://$TARGET" -w /usr/share/wordlists/dirb/common.txt -q | tee "$out"
    else
        log_warn "Neither ffuf nor gobuster found. Skipping hidden resource discovery."
    fi

    if check_tool smbclient; then
        log_info "Checking for SMB shared files..."
        echo -e "\n--- SMB Shares ---" | tee -a "$out"
        smbclient -L "$TARGET" -N 2>&1 | tee -a "$out"
    else
        log_warn "smbclient not found. Skipping SMB share check."
    fi

    log_success "Phase 5 saved to $out"
}

#############################################################
# PHASE 6: OSINT - EMAILS, USERNAMES
#############################################################
module_osint() {
    section "PHASE 6: OSINT - Emails & Usernames"
    local out="$OUTDIR/06_osint.txt"

    if check_tool theHarvester; then
        log_info "Running theHarvester for email/host OSINT..."
        theHarvester -d "$TARGET" -b all -f "$OUTDIR/06_harvester" 2>/dev/null | tee "$out"
    else
        log_warn "theHarvester not found. Skipping OSINT email/username module."
    fi

    log_success "Phase 6 saved to $out"
}

#############################################################
# PHASE 7: EXPOSED KEYS / SECRETS
#############################################################
module_exposed_keys() {
    section "PHASE 7: Exposed Keys & Secrets Check"
    local out="$OUTDIR/07_exposed_keys.txt"

    log_info "Checking common exposed config/secret paths..."
    local paths=(".env" ".git/config" "config.php.bak" "wp-config.php.bak" ".aws/credentials" "id_rsa" ".ssh/id_rsa")
    {
        echo "--- Common Exposed Path Probe ---"
        for p in "${paths[@]}"; do
            code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://$TARGET/$p")
            echo "/$p -> HTTP $code"
        done
    } | tee "$out"

    if check_tool trufflehog; then
        log_warn "trufflehog found - run it manually against a cloned repo if source code is available."
    fi

    log_success "Phase 7 saved to $out"
}

#############################################################
# PHASE 8: VULNERABILITY SCAN - CVE / MISCONFIG / INJECTION
#############################################################
module_vuln_scan() {
    section "PHASE 8: Vulnerability Scan (CVE / Misconfig / Injection)"
    local out="$OUTDIR/08_vuln_scan.txt"

    if check_tool nmap; then
        log_info "Running nmap vuln scripts..."
        echo "--- Nmap Vuln Scripts ---" | tee "$out"
        nmap --script vuln -T4 "$TARGET" -oN "$OUTDIR/08_nmap_vuln.txt" 2>&1 | tee -a "$out"
    else
        log_warn "nmap not found. Skipping nmap vuln scripts."
    fi

    if check_tool nuclei; then
        log_info "Running nuclei for CVE/misconfig/injection templates..."
        echo -e "\n--- Nuclei Scan ---" | tee -a "$out"
        nuclei -u "http://$TARGET" -severity low,medium,high,critical -o "$OUTDIR/08_nuclei_raw.txt" 2>/dev/null | tee -a "$out"
    else
        log_warn "nuclei not found. Install: https://github.com/projectdiscovery/nuclei"
    fi

    log_success "Phase 8 saved to $out"
}

#############################################################
# REPORT GENERATION
#############################################################
module_report() {
    section "Generating Summary Report"
    local report="$OUTDIR/REPORT_${TARGET//[^a-zA-Z0-9]/_}.txt"

    {
        echo "############################################"
        echo "  NetherEye Report"
        echo "  Target : $TARGET"
        echo "  Date   : $(date)"
        echo "############################################"
        for f in "$OUTDIR"/0*.txt; do
            [[ -f "$f" ]] || continue
            echo -e "\n\n=====================================" 
            echo " FILE: $(basename "$f")"
            echo "====================================="
            cat "$f"
        done
    } > "$report"

    log_success "Full report generated: $report"
}

#############################################################
# FULL AUTO MODE
#############################################################
run_full_auto() {
    AUTO_MODE="1"
    module_ip_subdomain
    module_live_host
    module_port_scan
    module_web_fingerprint
    module_hidden_resources
    module_osint
    module_exposed_keys
    module_vuln_scan
    module_report
    AUTO_MODE="0"
    log_success "Full automated scan complete. Check folder: $OUTDIR"
}

#############################################################
# MANUAL MENU
#############################################################
manual_menu() {
    while true; do
        echo ""
        echo -e "${CYAN}${BOLD}---------- NetherEye Menu ----------${NC}"
        echo " 1) IP & Subdomain Discovery"
        echo " 2) Live Host Check"
        echo " 3) Port Scan + Service + OS Detection"
        echo " 4) Webserver / Framework / CMS Fingerprint"
        echo " 5) Web API / Hidden Resources / Shared Files"
        echo " 6) OSINT - Emails & Usernames"
        echo " 7) Exposed Keys & Secrets Check"
        echo " 8) Vulnerability Scan (CVE/Misconfig/Injection)"
        echo " 9) Generate Report (combine all results so far)"
        echo " 0) Back to Main Menu"
        echo -e "${CYAN}--------------------------------------------${NC}"
        read -p "Select option: " choice
        case $choice in
            1) module_ip_subdomain; press_enter ;;
            2) module_live_host; press_enter ;;
            3) module_port_scan; press_enter ;;
            4) module_web_fingerprint; press_enter ;;
            5) module_hidden_resources; press_enter ;;
            6) module_osint; press_enter ;;
            7) module_exposed_keys; press_enter ;;
            8) module_vuln_scan; press_enter ;;
            9) module_report; press_enter ;;
            0) break ;;
            *) log_error "Invalid option" ;;
        esac
    done
}

#############################################################
# MAIN
#############################################################
main() {
    banner
    get_target

    while true; do
        echo ""
        echo -e "${YELLOW}${BOLD}Select Execution Mode:${NC}"
        echo " 1) Full Auto Scan (run all phases automatically)"
        echo " 2) Manual Menu (choose modules one by one)"
        echo " 3) Change Target"
        echo " 0) Exit"
        read -p "> " mode

        case $mode in
            1) run_full_auto ;;
            2) manual_menu ;;
            3) get_target ;;
            0) log_info "Exiting NetherEye. Bye Sonia!"; exit 0 ;;
            *) log_error "Invalid choice" ;;
        esac
    done
}

main
