#!/bin/bash
#############################################################
# ReconX Extended - Dependency Installer
# Run this on Kali Linux to install all required tools
#############################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${CYAN}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[-]${NC} $1"; }

echo -e "${CYAN}=========================================="
echo "  ReconX Extended - Dependency Installer"
echo -e "==========================================${NC}\n"

if [[ $EUID -ne 0 ]]; then
   log_error "Please run with sudo: sudo bash install_deps.sh"
   exit 1
fi

log_info "Updating apt package list..."
apt update -y

# ---------- APT PACKAGES (mostly already in Kali repos) ----------
APT_TOOLS=(nmap whatweb gobuster smbclient curl dnsutils)

for tool in "${APT_TOOLS[@]}"; do
    if dpkg -s "$tool" &>/dev/null; then
        log_success "$tool already installed"
    else
        log_info "Installing $tool..."
        apt install -y "$tool" && log_success "$tool installed" || log_error "$tool failed to install"
    fi
done

# ---------- httpx (projectdiscovery, via apt or go) ----------
if command -v httpx &>/dev/null; then
    log_success "httpx already installed"
else
    log_info "Installing httpx (projectdiscovery)..."
    apt install -y httpx-toolkit &>/dev/null && log_success "httpx-toolkit installed (binary may be 'httpx-toolkit')" || \
    log_warn "apt httpx-toolkit failed - will try go install below"
fi

# ---------- theHarvester ----------
if command -v theHarvester &>/dev/null; then
    log_success "theHarvester already installed"
else
    log_info "Installing theHarvester..."
    apt install -y theharvester &>/dev/null && log_success "theHarvester installed" || log_warn "theHarvester apt install failed, try: pipx install theHarvester"
fi

# ---------- ffuf ----------
if command -v ffuf &>/dev/null; then
    log_success "ffuf already installed"
else
    log_info "Installing ffuf..."
    apt install -y ffuf &>/dev/null && log_success "ffuf installed" || log_warn "ffuf apt install failed, will try go install below"
fi

# ---------- subfinder ----------
if command -v subfinder &>/dev/null; then
    log_success "subfinder already installed"
else
    log_info "Installing subfinder..."
    apt install -y subfinder &>/dev/null && log_success "subfinder installed" || log_warn "subfinder apt install failed, will try go install below"
fi

# ---------- amass ----------
if command -v amass &>/dev/null; then
    log_success "amass already installed"
else
    log_info "Installing amass..."
    apt install -y amass &>/dev/null && log_success "amass installed" || log_warn "amass apt install failed, will try go install below"
fi

# ---------- nuclei ----------
if command -v nuclei &>/dev/null; then
    log_success "nuclei already installed"
else
    log_info "Installing nuclei..."
    apt install -y nuclei &>/dev/null && log_success "nuclei installed" || log_warn "nuclei apt install failed, will try go install below"
fi

# ---------- dirb wordlist (for ffuf/gobuster) ----------
if [[ -f /usr/share/wordlists/dirb/common.txt ]]; then
    log_success "dirb wordlist already present"
else
    log_info "Installing dirb (provides common.txt wordlist)..."
    apt install -y dirb &>/dev/null && log_success "dirb wordlist installed" || log_warn "dirb install failed"
fi

# ---------- seclists (bigger wordlists, optional but recommended) ----------
if [[ -d /usr/share/seclists ]]; then
    log_success "seclists already present"
else
    log_info "Installing seclists (optional, large wordlist collection)..."
    apt install -y seclists &>/dev/null && log_success "seclists installed" || log_warn "seclists install failed (optional, skip if low on space)"
fi

# ---------- GO-based fallback installs ----------
NEED_GO=0
for tool in httpx ffuf subfinder amass nuclei; do
    command -v "$tool" &>/dev/null || NEED_GO=1
done

if [[ "$NEED_GO" == "1" ]]; then
    log_info "Some projectdiscovery tools missing from apt - checking Go for manual install..."
    if ! command -v go &>/dev/null; then
        log_info "Installing Go..."
        apt install -y golang-go &>/dev/null && log_success "Go installed" || log_error "Go install failed - install manually from https://go.dev/dl/"
    fi

    if command -v go &>/dev/null; then
        export PATH=$PATH:$(go env GOPATH 2>/dev/null)/bin:/root/go/bin
        command -v httpx     &>/dev/null || { log_info "go install httpx..."; go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest; }
        command -v subfinder &>/dev/null || { log_info "go install subfinder..."; go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest; }
        command -v nuclei    &>/dev/null || { log_info "go install nuclei..."; go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest; }
        command -v ffuf      &>/dev/null || { log_info "go install ffuf..."; go install -v github.com/ffuf/ffuf/v2@latest; }
        log_warn "Go-installed binaries are in ~/go/bin - add to PATH: export PATH=\$PATH:~/go/bin (add this line to ~/.bashrc)"
    fi
fi

echo ""
echo -e "${CYAN}=========================================="
echo "  Installation Summary"
echo -e "==========================================${NC}"

ALL_TOOLS=(nmap whatweb gobuster smbclient curl host httpx theHarvester ffuf subfinder amass nuclei)
for tool in "${ALL_TOOLS[@]}"; do
    if command -v "$tool" &>/dev/null; then
        echo -e "${GREEN}[OK]${NC}   $tool"
    else
        echo -e "${RED}[MISSING]${NC} $tool"
    fi
done

echo ""
log_info "If nuclei is installed, run 'nuclei -update-templates' once to fetch CVE/vuln templates."
log_info "Done! Re-check any [MISSING] tools manually if needed."
