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
GREY="\033[90m"
WARN_COUNT=0

ignore(){ echo -e "${GREY}[IGNORE] $1 ${RESET}"; }
info(){ echo -e "${BLUE}[INFO]${RESET} $1"; }
ok(){ echo -e "${GREEN}[OK]${RESET} $1"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET} $1"; (( ++WARN_COUNT )); }

echo -e "${BLUE}      __         ___            __      __   __   __  ___  __   __"
echo '|__| /  \  |\/| |__  |     /\  |__) __ |  \ /  \ /  `  |  /  \ |__)'
echo '|  | \__/  |  | |___ |___ /~~\ |__)    |__/ \__/ \__,  |  \__/ |  '\\
echo "${VERSION}"
echo "Made by Knuspii"
echo -e "${RESET}---"

# ---------------- CPU RAM DISK ----------------
load=$(awk '{print $1}' /proc/loadavg)
cores=$(nproc)

if awk "BEGIN {exit !(${load} < ${cores})}"; then
    ok "CPU load: ${load}/${cores}"
else
    warn "High CPU load: ${load}/${cores}"
fi

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
if command -v getent >/dev/null; then
    if getent hosts go.devapt >/dev/null 2>&1; then
        ok "DNS resolution working"
    else
        warn "DNS resolution failed"
    fi
else
    ignore "getent not available"
fi

# ---------------- NTP ----------------
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
if [[ -f /var/run/reboot-required ]]; then
    warn "System reboot required"
else
    ok "No reboot required"
fi

# ---------------- RAID / ZFS ----------------
if [[ -f /proc/mdstat ]]; then
    if grep -qE '\[.*_.*\]' /proc/mdstat; then
        warn "Software RAID degraded"
    elif grep -q '^md' /proc/mdstat; then
        ok "Software RAID healthy"
    else
        warn "Config found but no active RAID detected"
    fi
else
    ignore "No RAID support detected"
fi

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
if command -v ss >/dev/null; then
    ports=$(ss -tulnH | awk '{print $5}' | awk -F: '{print $NF}' | sort -n | uniq | tr '\n' ' ')
    info "Open ports: ${ports:-none}"
else
    ignore "ss not available"
fi

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
declare -A managers=(
    [apt]="apt list --upgradable 2>/dev/null | tail -n +2 | wc -l"
    [dnf]="dnf check-update -q 2>/dev/null | wc -l"
    [pacman]="pacman -Qu 2>/dev/null | wc -l"
    [zypper]="zypper list-updates 2>/dev/null | grep -c '|'"
)

for pm in "${!managers[@]}"; do
    if command -v "${pm}" >/dev/null; then
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
    ignore "Docker not installed"
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
    ignore "Podman not installed"
fi

# ---------------- KUBERNETES ----------------
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

echo "---"
echo "Warnings: ${WARN_COUNT}"