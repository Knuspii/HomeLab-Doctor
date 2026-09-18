#!/usr/bin/env bash
# Server-VibeCheck
# MIT License
# Made by Knuspii
# Made for HomeLabs with <3

set -euo pipefail

VERSION="v0.2"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"
GREY="\033[90m"
WARN_COUNT=0
DEBUG=false
LOG_FILE=""

# ---------------- FUNCTIONS ----------------
ignore() {
    echo -e "${GREY}[IGNORE] $1 ${RESET}"
}

info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARN] $1 ${RESET}"
    WARN_COUNT=$((WARN_COUNT + 1))
}

debug() {
    if [[ "${DEBUG}" == true ]]; then
        echo -e "${GREY}[DEBUG] $1${RESET}"
    fi
}

log_output() {
    if [[ -n "${LOG_FILE}" ]]; then
        tee -a "${LOG_FILE}"
    else
        cat
    fi
}

usage() {
    cat <<EOF
Usage:
    server-vibecheck [OPTIONS]

Options:
  NO OPTION         Start scan
  -h, --help        Show this help message
  -l, --log <file>  Write output to log file
  -d, --debug       Enable debug output
  -v, --version     Show version

Made by Knuspii
EOF
}

version() {
    echo "Server-VibeCheck ${VERSION}"
    echo "Made by Knuspii"
}

# ---------------- ARGUMENT PARSING ----------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;

        -l|--log)
            if [[ -n "${2:-}" && "${2}" != -* ]]; then
                LOG_FILE="$2"
                shift 2
            else
                LOG_FILE="/var/log/server-vibecheck.log"
                shift
            fi
            ;;

        -d|--debug|--verbose)
            DEBUG=true
            shift
            ;;

        -v|--version)
            version
            exit 0
            ;;

        --)
            shift
            break
            ;;

        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Try 'server-vibecheck --help' for more information." >&2
            exit 2
            ;;

        *)
            echo "Error: Unexpected argument: $1" >&2
            echo "Try 'server-vibecheck --help' for more information." >&2
            exit 2
            ;;
    esac
done

# Logging
if [[ -n "${LOG_FILE}" ]]; then
    if ! touch "${LOG_FILE}" 2>/dev/null; then
        echo "Error: Cannot write to log file: ${LOG_FILE}" >&2
        exit 2
    fi

    exec > >(tee -a "${LOG_FILE}") 2>&1
fi

# ---------------- HEADER ----------------
echo ""
echo -e "${YELLOW} ███▀█▄${BLUE}                               ${YELLOW} ▓██ █▄ ${BLUE}   ██          ${YELLOW} ███▀██ ${BLUE}█▄                █▄ ▄▄"
echo -e "${YELLOW}▀███▄▄ ${BLUE} ▄█▀█▄ ▄█▀▀▄ ██ ▄▄ ▄█▀█▄ ▄█▀▀▄ ${YELLOW}▀███ ██ ${BLUE}▀▀ ██▀█▄ ▄█▀█▄ ${YELLOW}▄███    ${BLUE}██▀█▄ ▄█▀█▄ ▄█▀█▄ ██▀█▄"
echo -e "${YELLOW} ▄▄▄ ██${BLUE} ██▀▀  ██    ▐█ █▌ ██▀▀  ██    ${YELLOW} ▀██ █▀ ${BLUE}█▄ ██ ██ ██▀▀  ${YELLOW} ███ ▄▄ ${BLUE}██ ██ ██▀▀  ██ ▄▄ ██ ██"
echo -e "${YELLOW} ▀▀▀▀▀▀${BLUE}  ▀▀▀  ▀▀     ▀▀▀   ▀▀▀  ▀▀    ${YELLOW}  ▀▀▀▀  ${BLUE}▀▀ ▀▀▀▀   ▀▀▀  ${YELLOW}  ▀▀▀▀▀ ${BLUE}▀▀ ▀▀  ▀▀▀   ▀▀▀  ▀▀ ▀▀"
echo ""
echo "Server-VibeCheck ${VERSION}"
echo -e "${RESET}---"

debug "Debug mode enabled"
debug "Running as user: $(id -un)"
debug "Hostname: $(hostname)"
debug "Kernel: $(uname -r)"

sleep 1

# ---------------- CPU, RAM, DISK ----------------
debug "Checking CPU load..."
load=$(awk '{print $1}' /proc/loadavg)
cores=$(nproc)

if awk "BEGIN {exit !(${load} < ${cores})}"; then
    ok "CPU load: ${load}/${cores}"
else
    warn "High CPU load: ${load}/${cores}"
fi

debug "Checking RAM..."
mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_available=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

if [[ -n "${mem_total}" && -n "${mem_available}" ]]; then
    mem_used=$((mem_total - mem_available))
    mem_pct=$((mem_used * 100 / mem_total))

    if [[ "${mem_pct}" -lt 90 ]]; then
        ok "RAM usage: ${mem_pct}%"
    else
        warn "RAM usage: ${mem_pct}%"
    fi
else
    warn "Unable to determine RAM usage"
fi

debug "Checking disk usage..."
EXCLUDES="tmpfs|devtmpfs|efivarfs|overlay|squashfs|proc|sysfs"
while read -r fs _ _ _ pct mount; do
    if echo "${fs}" | grep -Eq "${EXCLUDES}"; then
        continue
    fi

    case "${mount}" in
        /boot|/boot/efi|/var/lib/docker|/var/lib/containers|/run|/sys|/proc)
            continue
            ;;
    esac

    usage=${pct%\%}

    if [[ "${usage}" -lt 90 ]]; then
        ok "Disk ${mount}: ${pct} used"
    else
        warn "Disk ${mount}: ${pct} used"
    fi
done < <(df -P -x tmpfs -x devtmpfs | tail -n +2)

# ---------------- DNS ----------------
debug "Checking DNS resolution..."
if command -v getent >/dev/null; then
    if getent hosts go.dev >/dev/null 2>&1; then
        ok "DNS resolution working"
    else
        warn "DNS resolution failed"
    fi
else
    ignore "getent not available"
fi

# ---------------- NTP ----------------
debug "Checking NTP synchronization..."
if command -v timedatectl >/dev/null; then
    if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
        ok "NTP synchronized"
    else
        warn "NTP not synchronized"
    fi
else
    ignore "timedatectl not available"
fi

# ---------------- REBOOT ----------------
debug "Checking reboot requirement..."
if [[ -f /var/run/reboot-required ]]; then
    warn "System reboot required"
else
    ok "No reboot required"
fi

# ---------------- RAID, ZFS ----------------
debug "Checking software RAID..."
if [[ -f /proc/mdstat ]]; then
    if grep -qE '\[.*_.*\]' /proc/mdstat; then
        warn "Software RAID degraded"
    elif grep -q '^md' /proc/mdstat; then
        ok "Software RAID healthy"
    else
        info "No active software RAID detected"
    fi
else
    ignore "No RAID support detected"
fi

debug "Checking ZFS..."
if command -v zpool >/dev/null; then
    if zpool status -x | grep -q "all pools are healthy"; then
        ok "ZFS pools healthy"
    else
        warn "ZFS pool issue detected"
    fi
else
    ignore "No ZFS support detected"
fi

# ---------------- OPEN PORTS / FIREWALL ----------------
debug "Checking open ports..."
if command -v ss >/dev/null; then
    ports=$(ss -tulnH | awk '{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ')
    info "Open ports: ${ports:-none}"
else
    ignore "ss not available"
fi

debug "Checking firewall..."
if command -v ufw >/dev/null; then
    ufw_status=$(ufw status 2>/dev/null || true)

    if echo "${ufw_status}" | grep -q "Status: active"; then
        ok "Firewall (UFW): active"
    elif echo "${ufw_status}" | grep -q "root"; then
        info "Firewall (UFW): detected (Run as root to check status)"
    else
        warn "Firewall (UFW): INACTIVE"
    fi

elif command -v firewall-cmd >/dev/null; then

    if firewall-cmd --state >/dev/null 2>&1; then
        ok "Firewall (Firewalld): active"
    else
        warn "Firewall (Firewalld): INACTIVE"
    fi

else
    ignore "Firewall: No standard manager detected"
fi

# ---------------- PACKAGE UPDATES ----------------
debug "Checking package updates..."
declare -A managers=(
    [apt]="apt list --upgradable 2>/dev/null | tail -n +2 | wc -l"
    [dnf]="dnf check-update -q 2>/dev/null | wc -l"
    [pacman]="pacman -Qu 2>/dev/null | wc -l"
    [zypper]="zypper list-updates 2>/dev/null | grep -c '|'"
)

for pm in "${!managers[@]}"; do
    if command -v "${pm}" >/dev/null; then

        debug "Checking updates using ${pm}..."

        raw_count=$(eval "${managers[${pm}]}" 2>/dev/null || echo 0)
        count=$(echo "${raw_count}" | tr -d '\r[:space:]')

        : "${count:=0}"

        if [[ "${count}" -gt 0 ]]; then
            warn "Updates (${pm}): ${count}"
        else
            info "Updates (${pm}): ${count}"
        fi
    else
        ignore "${pm} not installed"
    fi
done

# ---------------- SYSTEMD SERVICES ----------------
debug "Checking failed Systemd services..."
if command -v systemctl >/dev/null; then

    failed_services=$(
        systemctl list-units \
            --state=failed \
            --plain \
            --no-legend \
            2>/dev/null |
        awk '{print $1}' || true
    )

    if [[ -z "${failed_services}" ]]; then
        ok "All Systemd services running fine"
    else
        warn "Failed Systemd services: $(echo "${failed_services}" | tr '\n' ' ')"
    fi

else
    ignore "systemctl not available"
fi

# ---------------- DOCKER ----------------
debug "Checking Docker..."
if command -v docker >/dev/null; then

    if docker info >/dev/null 2>&1; then

        running=$(docker ps -q 2>/dev/null | wc -l)
        unhealthy=$(docker ps --filter health=unhealthy -q 2>/dev/null | wc -l)

        ok "Docker is working"
        ok "Docker containers running: ${running}"

        if [[ "${unhealthy}" -gt 0 ]]; then
            warn "Docker unhealthy containers: ${unhealthy}"
        fi

    else
        warn "docker installed but not accessible (daemon or permissions issue)"
    fi

else
    ignore "docker not installed"
fi

# ---------------- PODMAN ----------------
debug "Checking Podman..."
if command -v podman >/dev/null; then

    if podman info >/dev/null 2>&1; then

        running=$(podman ps -q 2>/dev/null | wc -l)

        ok "Podman is working"
        ok "Podman containers running: ${running}"

    else
        warn "podman installed but not working"
    fi

else
    ignore "podman not installed"
fi

# ---------------- KUBERNETES ----------------
debug "Checking Kubernetes..."
if command -v kubectl >/dev/null; then

    if kubectl get nodes --no-headers >/tmp/hd_k8s 2>/dev/null; then

        bad=$(grep -vc " Ready " /tmp/hd_k8s || true)

        rm -f /tmp/hd_k8s

        if [[ "${bad}" -eq 0 ]]; then
            ok "Kubernetes nodes healthy"
        else
            warn "Kubernetes unhealthy nodes: ${bad}"
        fi

    else

        rm -f /tmp/hd_k8s
        warn "kubectl installed but cluster not reachable"

    fi

else
    ignore "kubectl not installed"
fi

# ---------------- SUMMARY ----------------
debug "Printing Summary..."
echo "---"
echo "Warnings: ${WARN_COUNT}"
