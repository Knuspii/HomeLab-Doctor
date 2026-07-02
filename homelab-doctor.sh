#!/usr/bin/env bash
# HomeLab-Doctor
# MIT License
# Made by Knuspii
# Made for HomeLabs with <3

set -euo pipefail

VERSION="v0.1"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
RESET="\033[0m"
WARN_COUNT=0
CRIT_COUNT=0

info(){ echo -e "${BLUE}[INFO]${RESET} $1"; }
ok(){ echo -e "${GREEN}[OK]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $1"; (( WARN_COUNT++ )); }
crit(){ echo -e "${RED}[FAIL]${RESET} $1"; (( CRIT_COUNT++ )); }

echo -e "${BLUE}      __         ___            __      __   __   __  ___  __   __"
echo '|__| /  \  |\/| |__  |     /\  |__) __ |  \ /  \ /  `  |  /  \ |__)'
echo '|  | \__/  |  | |___ |___ /~~\ |__)    |__/ \__/ \__,  |  \__/ |  '\\
echo "${VERSION}"
echo "Made by Knuspii"
echo -e "${RESET}---"

# ---------------- CPU ----------------
load=$(awk '{print $1}' /proc/loadavg)
cores=$(nproc)

if awk "BEGIN {exit !(${load} < ${cores})}"; then
    ok "CPU load: ${load}/${cores}"
else
    warn "High CPU load: ${load}/${cores}"
fi

# ---------------- RAM ----------------
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
    crit "Unable to determine RAM usage"
fi

# ---------------- DISK ----------------
EXCLUDES="tmpfs|devtmpfs|efivarfs|overlay|squashfs|proc|sysfs"
df -P -x tmpfs -x devtmpfs | tail -n +2 | while read -r fs _ _ _ pct mount; do
    # skip unwanted mounts
    if echo "${fs}" | grep -Eq "${EXCLUDES}"; then
        continue
    fi

    # skip docker / system noise mounts
    case "${mount}" in
        /boot|/boot/efi|/var/lib/docker|/var/lib/containers|/run|/sys|/proc)
            continue
            ;;
    esac

    usage=${pct%\%}
    if [[ "${usage}" -lt 85 ]]; then
        ok "Disk ${mount}: ${pct} used"
    else
        warn "Disk ${mount}: ${pct} used"
    fi

done

# ---------------- DNS ----------------
if command -v getent >/dev/null; then
    if getent hosts go.dev >/dev/null 2>&1; then
        ok "DNS resolution working"
    else
        crit "DNS resolution failed"
    fi
else
    info "getent not available"
fi

# ---------------- NTP ----------------
if command -v timedatectl >/dev/null; then
    if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
        ok "NTP synchronized"
    else
        warn "NTP not synchronized"
    fi
else
    info "timedatectl not available"
fi

# ---------------- REBOOT ----------------
if [[ -f /var/run/reboot-required ]]; then
    warn "System reboot required"
else
    ok "No reboot required"
fi

# ---------------- RAID ----------------
if [[ -f /proc/mdstat ]]; then
    if grep -qE '\[.*_.*\]' /proc/mdstat; then
        crit "Software RAID degraded"
    elif grep -q '^md' /proc/mdstat; then
        ok "Software RAID healthy"
    else
        info "No active RAID detected"
    fi
else
    info "No RAID support detected"
fi

# ---------------- ZFS ----------------
if command -v zpool >/dev/null; then
    if zpool status -x | grep -q "all pools are healthy"; then
        ok "ZFS pools healthy"
    else
        crit "ZFS pool issue detected"
    fi
else
    info "No ZFS support detected"
fi

# ---------------- OPEN PORTS ----------------
if command -v ss >/dev/null; then
    ports=$(ss -tulnH | awk '{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ')
    info "Open ports: ${ports:-none}"
else
    info "ss not available"
fi

# ---------------- FIREWALL ----------------
if command -v ufw >/dev/null; then
    # UFW Status needs root
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
    info "Firewall: No standard manager detected"
fi

# ---------------- PACKAGE UPDATES ----------------
declare -A managers=(
    [apt]="apt list --upgradable 2>/dev/null | tail -n +2 | wc -l"
    [dnf]="dnf check-update -q 2>/dev/null | wc -l"
    [pacman]="pacman -Qu 2>/dev/null | wc -l"
    [zypper]="zypper list-updates 2>/dev/null | grep -c '|'"
)

for pm in "${!managers[@]}"; do
    if command -v "${pm}" >/dev/null; then
        count=$(eval "${managers[${pm}]}" || echo 0)
        # If updates > 0 = warn
        if [[ "${count}" -gt 0 ]]; then
            warn "Updates (${pm}): ${count}"
        else
            info "Updates (${pm}): ${count}"
        fi
    else
        info "${pm} not installed"
    fi
done

# ---------------- DOCKER ----------------
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
        warn "Docker installed but not accessible (daemon or permissions issue)"
    fi
else
    info "Docker not installed"
fi

# ---------------- PODMAN ----------------
if command -v podman >/dev/null; then
    if podman info >/dev/null 2>&1; then
        running=$(podman ps -q 2>/dev/null | wc -l)
        ok "Podman is working"
        ok "Podman containers running: ${running}"
    else
        warn "Podman installed but not working"
    fi
else
    info "Podman not installed"
fi

# ---------------- KUBERNETES ----------------
if command -v kubectl >/dev/null; then
    bad=$(kubectl get nodes --no-headers 2>/dev/null | grep -vc " Ready " || true)

    if [[ "${bad}" -eq 0 ]]; then
        ok "Kubernetes nodes healthy"
    else
        warn "Kubernetes unhealthy nodes: ${bad}"
    fi
else
    info "kubectl not installed"
fi

echo "---"
echo "Warnings: ${WARN_COUNT}"
echo "Errors:   ${CRIT_COUNT}"
