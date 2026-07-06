#!/usr/bin/env bash
set -euo pipefail
/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -ExecutionPolicy Bypass -File /home/alfonso_ngel/HERMES_SECOND_BRAIN_APP/nexura-digital-web/.nexura_ssh_askpass.ps1 | tr -d '\r'
