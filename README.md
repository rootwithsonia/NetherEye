#  NetherEye

**Cyberpunk-themed Red Team Recon-to-Vulnerability Automation Toolkit**

NetherEye automates the full reconnaissance kill chain — from subdomain discovery to vulnerability detection — in a single, modular Bash framework. Built for authorized penetration testing and CEH-style lab practice.

---

## ⚡ Features

NetherEye runs through 8 phases, each independently runnable or chained in full-auto mode:

| Phase | Module | What it does |
|-------|--------|---------------|
| 1 | IP & Subdomain Discovery | Resolves target IP, enumerates subdomains (subfinder/amass) |
| 2 | Live Host Check | Confirms target is reachable (ping + httpx/curl) |
| 3 | Port Scan + Service + OS Detection | Open ports, service versions, OS fingerprint (nmap) |
| 4 | Web Fingerprint | Webserver, framework, CMS, version detection (whatweb) |
| 5 | Hidden Resources | Directory/API fuzzing + SMB share enumeration (ffuf/gobuster/smbclient) |
| 6 | OSINT | Email and username harvesting (theHarvester) |
| 7 | Exposed Keys & Secrets | Probes for leaked config/credential files |
| 8 | Vulnerability Scan | CVE, misconfig, injection detection (nmap --script vuln + nuclei) |

Plus an auto-generated combined report at the end of every run.

---

## 🚀 Quick Start

```bash
git clone https://github.com/yourusername/NetherEye.git
cd NetherEye
chmod +x nethereye.sh install_deps.sh
sudo bash install_deps.sh
./nethereye.sh
```

---

## 🛠️ Requirements

Install everything in one shot using the bundled installer:

```bash
sudo bash install_deps.sh
```

This installs (or attempts to install) the following tools:

- `nmap`
- `whatweb`
- `gobuster`
- `smbclient`
- `theHarvester`
- `ffuf`
- `subfinder`
- `amass`
- `nuclei`
- `httpx`
- `dirb` (wordlists)
- `seclists` (optional, larger wordlists)

> Missing tools are gracefully skipped during scans — NetherEye won't crash, it just logs a warning and moves to the next module.

After installing nuclei, update its templates:

```bash
nuclei -update-templates
```

---

## 📖 Usage

Run the script and follow the prompts:

```bash
./nethereye.sh
```

You'll be asked for a target (domain or IP), then choose:

- **Full Auto Scan** — runs all 8 phases back-to-back
- **Manual Menu** — pick individual modules one at a time

All results are saved into a timestamped folder: `nethereye_<target>_<timestamp>/`

---

## ⚠️ Disclaimer

This tool is intended **strictly for authorized security testing, CTF practice, and educational use** (e.g. on `scanme.nmap.org`, TryHackMe, HackTheBox, or systems you own/have explicit permission to test). Unauthorized scanning of systems you do not own or have permission to test is illegal.

---

## 👤 Author

Built by Sonia — MCA student, CCNA/CCNP/MCSE/MCSA certified, working toward CEH and red team / SOC roles.
