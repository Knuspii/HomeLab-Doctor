<p align="center">
  <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?logo=gnubash&logoColor=fff" alt="Bash" /></a>
  <a href="https://github.com/knuspii/homelab-doctor/actions/workflows/shell.yml"><img src="https://github.com/knuspii/homelab-doctor/actions/workflows/shell.yml/badge.svg" alt="Build" /></a>
  <a href="https://github.com/knuspii/homelab-doctor/stargazers"><img src="https://img.shields.io/github/stars/knuspii/homelab-doctor?style=social" alt="GitHub Stars" /></a>
  <br>
  <img src="https://img.shields.io/github/license/knuspii/homelab-doctor" />
</p>

You quickly wanna check your server, but don't want to use 10+ tools to check everything? \
Well this script will help you with checking the most important things.

## Supports
- CPU, RAM, Disk checks
- DNS checks
- NTP checks
- RAID checks
- Package update checks
- Docker, Podman, Kubernetes

## 📥 How to install:
Latest Release:
```bash
sudo curl -fsSL https://raw.githubusercontent.com/knuspii/homelab-doctor/main/homelab-doctor.sh -o /usr/local/bin/homelab-doctor && sudo chmod +x /usr/local/bin/homelab-doctor
```
