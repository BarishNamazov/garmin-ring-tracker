#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${SCRIPT_DIR}/.state"
PROFILE_DIR="/tmp/remote-browser-profile"
WIPE=0

if [[ "${1:-}" == "--wipe" ]]; then
    WIPE=1
elif (($#)); then
    printf 'Usage: %s [--wipe]\n' "$0" >&2
    exit 2
fi

pid_is_alive() {
    local pid="${1:-}"
    [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null
}

stop_one() {
    local name="$1"
    local pid_file="${STATE_DIR}/${name}.pid"
    local pid
    [[ -f "${pid_file}" ]] || return 0
    pid="$(<"${pid_file}")"
    if pid_is_alive "${pid}"; then
        kill -TERM -- "-${pid}" 2>/dev/null || kill -TERM "${pid}" 2>/dev/null || true
        for _ in {1..50}; do
            pid_is_alive "${pid}" || break
            sleep 0.2
        done
        if pid_is_alive "${pid}"; then
            kill -KILL -- "-${pid}" 2>/dev/null || kill -KILL "${pid}" 2>/dev/null || true
        fi
    fi
    unlink "${pid_file}" 2>/dev/null || true
}

# Stop consumers before the display server.
for component in cloudflared websockify chromium x11vnc xserver; do
    stop_one "${component}"
done

unlink "${SCRIPT_DIR}/CONNECT.txt" 2>/dev/null || true
unlink "${STATE_DIR}/vnc-password" 2>/dev/null || true
unlink "${STATE_DIR}/active-config" 2>/dev/null || true

if ((WIPE)); then
    if [[ "${PROFILE_DIR}" != "/tmp/remote-browser-profile" ]]; then
        printf 'Refusing to wipe unexpected profile path: %s\n' "${PROFILE_DIR}" >&2
        exit 1
    fi
    if [[ -d "${PROFILE_DIR}" ]]; then
        find "${PROFILE_DIR}" -depth -delete
    fi
    printf 'Remote browser stopped; Chromium profile wiped.\n'
else
    printf 'Remote browser stopped; Chromium profile preserved at %s.\n' "${PROFILE_DIR}"
fi
