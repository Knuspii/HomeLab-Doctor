<p align="center">
  <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/github/languages/top/Knuspii/Server-VibeCheck?color=green" alt="Bash" /></a>
  <a href="https://github.com/knuspii/server-vibecheck/actions/workflows/shell.yml"><img src="https://github.com/knuspii/server-vibecheck/actions/workflows/shell.yml/badge.svg" alt="Build" /></a>
  <a href="https://github.com/knuspii/server-vibecheck/stargazers"><img src="https://img.shields.io/github/stars/knuspii/server-vibecheck?style=social" alt="GitHub Stars" /></a>
  <br>
  <img src="https://img.shields.io/github/license/knuspii/server-vibecheck" />
</p>

<div align="center">
  <img src="assets/server-vibecheck_logo.png" width="400" height="400" alt="Preview">
</div>
<br>

You quickly wanna check your server, but don't want to use 10+ tools to check everything? \
Well this script will help you with checking the most important things.

## Supports
- Checks: CPU, RAM, Disk
- Checks: NTP, DNS, Firewall
- Checks: RAID, ZFS
- Checks: Package update
- Checks: Docker, Podman, Kubernetes

## 📥 How to install:
Latest Release:
```bash
curl -L https://github.com/Knuspii/Server-VibeCheck/releases/latest/download/server-vibecheck.sh -o hd && sudo install -m 755 hd /usr/local/bin/server-vibecheck && rm hd
```
