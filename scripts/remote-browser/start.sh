#!/usr/bin/env bash

set -Eeuo pipefail

umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${SCRIPT_DIR}/.state"
CONNECT_FILE="${SCRIPT_DIR}/CONNECT.txt"
PASSWORD_FILE="${STATE_DIR}/vnc-password"
ACTIVE_CONFIG_FILE="${STATE_DIR}/active-config"
SCREENSHOT_FILE="${SCRIPT_DIR}/garmin-signin.png"
PROFILE_DIR="/tmp/remote-browser-profile"

DISPLAY_NUMBER="${REMOTE_BROWSER_DISPLAY:-99}"
DISPLAY_VALUE=":${DISPLAY_NUMBER}"
VNC_PORT="${REMOTE_BROWSER_VNC_PORT:-5999}"
NOVNC_PORT="${REMOTE_BROWSER_NOVNC_PORT:-6080}"
CDP_PORT="${REMOTE_BROWSER_CDP_PORT:-9222}"

TIGERVNC_VERSION="1.16.2"
NOVNC_VERSION="1.7.0"
TIGERVNC_DIR="${HOME}/.local/opt/tigervnc"
NOVNC_DIR="${HOME}/.local/opt/novnc"
X11VNC_DIR="${HOME}/.local/opt/x11vnc"
CIQ_RUNTIME="${CIQ_SIM_RUNTIME:-${HOME}/.local/opt/ciq-runtime}"
CIQ_PATCHED_BIN="${CIQ_RUNTIME}-patched-bin"

mkdir -p "${STATE_DIR}" "${PROFILE_DIR}"
chmod 700 "${STATE_DIR}" "${PROFILE_DIR}"

log() {
    printf '[remote-browser] %s\n' "$*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

pid_is_alive() {
    local pid="${1:-}"
    [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null
}

port_is_busy() {
    local port="$1"
    [[ -n "$(ss -ltnH "sport = :${port}" 2>/dev/null)" ]]
}

wait_for_port() {
    local port="$1"
    local pid="$2"
    local attempts="${3:-100}"
    local i
    for ((i = 0; i < attempts; i++)); do
        port_is_busy "${port}" && return 0
        pid_is_alive "${pid}" || return 1
        sleep 0.2
    done
    return 1
}

spawn() {
    local name="$1"
    shift
    nohup setsid "$@" >"${STATE_DIR}/${name}.log" 2>&1 </dev/null &
    local pid=$!
    printf '%s\n' "${pid}" >"${STATE_DIR}/${name}.pid"
    printf '%s\n' "${pid}"
}

stop_started_processes() {
    local name pid
    for name in cloudflared websockify chromium x11vnc xserver; do
        [[ -f "${STATE_DIR}/${name}.pid" ]] || continue
        pid="$(<"${STATE_DIR}/${name}.pid")"
        if pid_is_alive "${pid}"; then
            kill -TERM -- "-${pid}" 2>/dev/null || kill -TERM "${pid}" 2>/dev/null || true
        fi
    done
}

failed=1
on_exit() {
    if ((failed)); then
        stop_started_processes
        unlink "${CONNECT_FILE}" 2>/dev/null || true
        unlink "${PASSWORD_FILE}" 2>/dev/null || true
    fi
}
trap on_exit EXIT

if [[ -f "${STATE_DIR}/cloudflared.pid" ]] &&
   pid_is_alive "$(<"${STATE_DIR}/cloudflared.pid")" &&
   [[ -s "${CONNECT_FILE}" ]]; then
    if [[ -f "${ACTIVE_CONFIG_FILE}" ]] &&
       rg -qx "DISPLAY=${DISPLAY_VALUE}" "${ACTIVE_CONFIG_FILE}" &&
       rg -qx "VNC_PORT=${VNC_PORT}" "${ACTIVE_CONFIG_FILE}" &&
       rg -qx "NOVNC_PORT=${NOVNC_PORT}" "${ACTIVE_CONFIG_FILE}" &&
       rg -qx "CDP_PORT=${CDP_PORT}" "${ACTIVE_CONFIG_FILE}"; then
        cat "${CONNECT_FILE}"
        failed=0
        exit 0
    fi
    die "A remote browser is already running with different port settings; stop it first."
fi

for port in "${VNC_PORT}" "${NOVNC_PORT}" "${CDP_PORT}"; do
    if port_is_busy "${port}"; then
        die "TCP port ${port} is already in use; stop the owning service and retry."
    fi
done

display_lock="/tmp/.X${DISPLAY_NUMBER}-lock"
display_socket="/tmp/.X11-unix/X${DISPLAY_NUMBER}"
if [[ -f "${display_lock}" ]]; then
    display_pid="$(tr -d '[:space:]' <"${display_lock}")"
    if [[ "${display_pid}" =~ ^[0-9]+$ ]] && ! pid_is_alive "${display_pid}"; then
        log "Removing stale ${DISPLAY_VALUE} lock for departed PID ${display_pid}"
        unlink "${display_lock}" 2>/dev/null || true
        unlink "${display_socket}" 2>/dev/null || true
    fi
fi
if [[ -S "${display_socket}" ]] || [[ -e "${display_lock}" ]]; then
    die "X display ${DISPLAY_VALUE} is already in use."
fi

install_tigervnc() {
    local tmp_dir deb_root
    if [[ ! -x "${TIGERVNC_DIR}/usr/bin/Xvnc" ]]; then
        log "Installing TigerVNC ${TIGERVNC_VERSION} under ${TIGERVNC_DIR}"
        tmp_dir="$(mktemp -d /tmp/remote-browser-tigervnc.XXXXXX)"
        mkdir -p "${TIGERVNC_DIR}"
        curl -fL --retry 3 --max-time 180 \
            -o "${tmp_dir}/tigervnc.tar.gz" \
            "https://sourceforge.net/projects/tigervnc/files/stable/${TIGERVNC_VERSION}/tigervnc-${TIGERVNC_VERSION}.x86_64.tar.gz/download"
        tar -xzf "${tmp_dir}/tigervnc.tar.gz" -C "${TIGERVNC_DIR}" --strip-components=1
    fi

    if [[ ! -e "${TIGERVNC_DIR}/lib/libxcvt.so.0" ]]; then
        log "Installing TigerVNC's libxcvt runtime dependency locally"
        tmp_dir="$(mktemp -d /tmp/remote-browser-libxcvt.XXXXXX)"
        deb_root="${tmp_dir}/root"
        mkdir -p "${deb_root}" "${TIGERVNC_DIR}/lib"
        curl -fL --retry 3 --max-time 60 \
            -o "${tmp_dir}/libxcvt.deb" \
            'http://archive.ubuntu.com/ubuntu/pool/main/libx/libxcvt/libxcvt0_0.1.2-1build1_amd64.deb'
        dpkg-deb -x "${tmp_dir}/libxcvt.deb" "${deb_root}"
        cp -a "${deb_root}/usr/lib/x86_64-linux-gnu/." "${TIGERVNC_DIR}/lib/"
    fi

    mkdir -p "${TIGERVNC_DIR}/patched-bin" /tmp/ciq
    if [[ ! -x "${TIGERVNC_DIR}/patched-bin/Xvnc" ]] ||
       [[ "${TIGERVNC_DIR}/usr/bin/Xvnc" -nt "${TIGERVNC_DIR}/patched-bin/Xvnc" ]]; then
        cp "${TIGERVNC_DIR}/usr/bin/Xvnc" "${TIGERVNC_DIR}/patched-bin/Xvnc"
        # Xorg stores the xkbcomp directory as an eight-byte compile-time path.
        # /tmp/ciq is deliberately the same length as /usr/bin.
        perl -0pi -e 's{/usr/bin(?=\x00)}{/tmp/ciq}g' "${TIGERVNC_DIR}/patched-bin/Xvnc"
        chmod 755 "${TIGERVNC_DIR}/patched-bin/Xvnc"
    fi

    [[ -x "${CIQ_RUNTIME}/usr/bin/xkbcomp" ]] ||
        die "xkbcomp not found at ${CIQ_RUNTIME}/usr/bin/xkbcomp"
    ln -sfn "${CIQ_RUNTIME}/usr/bin/xkbcomp" /tmp/ciq/xkbcomp
}

install_novnc() {
    local tmp_dir
    if [[ ! -f "${NOVNC_DIR}/vnc.html" ]]; then
        log "Installing noVNC ${NOVNC_VERSION} under ${NOVNC_DIR}"
        tmp_dir="$(mktemp -d /tmp/remote-browser-novnc.XXXXXX)"
        mkdir -p "${NOVNC_DIR}"
        curl -fL --retry 3 --max-time 180 \
            -o "${tmp_dir}/novnc.zip" \
            "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.zip"
        unzip -q "${tmp_dir}/novnc.zip" -d "${tmp_dir}/unpacked"
        cp -a "${tmp_dir}/unpacked/noVNC-${NOVNC_VERSION}/." "${NOVNC_DIR}/"
    fi
}

install_websockify() {
    local tmp_dir
    if [[ ! -x "${HOME}/.local/bin/websockify" ]]; then
        if ! python3 -m pip --version >/dev/null 2>&1; then
            log "Bootstrapping pip in the user account"
            tmp_dir="$(mktemp -d /tmp/remote-browser-pip.XXXXXX)"
            curl -fL --retry 3 --max-time 120 \
                -o "${tmp_dir}/get-pip.py" \
                'https://bootstrap.pypa.io/get-pip.py'
            python3 "${tmp_dir}/get-pip.py" --user --break-system-packages
        fi
        log "Installing websockify in the user account"
        python3 -m pip install --user --break-system-packages 'websockify>=0.13,<0.14'
    fi
}

install_x11vnc_fallback() {
    local tmp_dir pkg root
    [[ -x "${X11VNC_DIR}/usr/bin/x11vnc" ]] && return 0
    log "Installing the user-local Ubuntu x11vnc fallback bundle"
    tmp_dir="$(mktemp -d /tmp/remote-browser-x11vnc.XXXXXX)"
    root="${tmp_dir}/root"
    mkdir -p "${root}" "${X11VNC_DIR}"
    for pkg in \
        'universe/x/x11vnc/x11vnc_0.9.16-10_amd64.deb' \
        'main/libv/libvncserver/libvncserver1_0.9.14+dfsg-1ubuntu0.2_amd64.deb' \
        'main/libv/libvncserver/libvncclient1_0.9.14+dfsg-1ubuntu0.2_amd64.deb'; do
        curl -fL --retry 3 --max-time 120 \
            -o "${tmp_dir}/package.deb" "http://archive.ubuntu.com/ubuntu/pool/${pkg}"
        dpkg-deb -x "${tmp_dir}/package.deb" "${root}"
    done
    cp -a "${root}/." "${X11VNC_DIR}/"
}

install_tigervnc
install_novnc
install_websockify

VNC_PASSWORD="$(openssl rand -hex 4)"
printf '%s\n' "${VNC_PASSWORD}" |
    "${TIGERVNC_DIR}/usr/bin/vncpasswd" -f >"${PASSWORD_FILE}"
chmod 600 "${PASSWORD_FILE}"

XVNC="${TIGERVNC_DIR}/patched-bin/Xvnc"
XVNC_LIBRARY_PATH="${TIGERVNC_DIR}/lib:${CIQ_RUNTIME}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
log "Starting TigerVNC Xvnc on ${DISPLAY_VALUE}"
xserver_pid="$(spawn xserver env \
    LD_LIBRARY_PATH="${XVNC_LIBRARY_PATH}" \
    "${XVNC}" "${DISPLAY_VALUE}" \
    -geometry 1280x900 -depth 24 -localhost -ac \
    -SecurityTypes VncAuth -PasswordFile "${PASSWORD_FILE}" \
    -rfbport "${VNC_PORT}")"

if ! wait_for_port "${VNC_PORT}" "${xserver_pid}" 75; then
    log "Xvnc did not become ready; falling back to Xvfb plus x11vnc"
    kill -TERM -- "-${xserver_pid}" 2>/dev/null || true
    for _ in {1..25}; do
        pid_is_alive "${xserver_pid}" || break
        sleep 0.2
    done
    install_x11vnc_fallback
    [[ -x "${CIQ_PATCHED_BIN}/Xvfb" ]] || die "Patched Xvfb not found at ${CIQ_PATCHED_BIN}/Xvfb"

    xserver_pid="$(spawn xserver env \
        LD_LIBRARY_PATH="${CIQ_RUNTIME}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
        "${CIQ_PATCHED_BIN}/Xvfb" "${DISPLAY_VALUE}" \
        -screen 0 1280x900x24 -nolisten tcp -ac)"
    for _ in {1..50}; do
        [[ -S "/tmp/.X11-unix/X${DISPLAY_NUMBER}" ]] && break
        pid_is_alive "${xserver_pid}" || die "Fallback Xvfb exited; see ${STATE_DIR}/xserver.log"
        sleep 0.2
    done

    x11vnc_pid="$(spawn x11vnc env \
        DISPLAY="${DISPLAY_VALUE}" \
        LD_LIBRARY_PATH="${X11VNC_DIR}/usr/lib/x86_64-linux-gnu:${CIQ_RUNTIME}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
        "${X11VNC_DIR}/usr/bin/x11vnc" \
        -display "${DISPLAY_VALUE}" -rfbport "${VNC_PORT}" -localhost \
        -no6 -forever -shared -rfbauth "${PASSWORD_FILE}")"
    wait_for_port "${VNC_PORT}" "${x11vnc_pid}" 75 ||
        die "Fallback x11vnc exited; see ${STATE_DIR}/x11vnc.log"
fi

CHROMIUM="${HOME}/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome"
if [[ ! -x "${CHROMIUM}" ]]; then
    CHROMIUM="${HOME}/.cache/ms-playwright/chromium-1234/chrome-linux/chrome"
fi
[[ -x "${CHROMIUM}" ]] || die "Full Playwright Chromium 1234 build was not found"

log "Starting full Chromium on ${DISPLAY_VALUE} with CDP on 127.0.0.1:${CDP_PORT}"
chromium_pid="$(spawn chromium env DISPLAY="${DISPLAY_VALUE}" \
    "${CHROMIUM}" \
    --remote-debugging-address=127.0.0.1 \
    --remote-debugging-port="${CDP_PORT}" \
    --user-data-dir="${PROFILE_DIR}" \
    --no-sandbox \
    --no-first-run \
    --no-default-browser-check \
    --window-size=1280,900 \
    --start-maximized \
    'https://apps.garmin.com/developer/dashboard')"

wait_for_port "${CDP_PORT}" "${chromium_pid}" 150 ||
    die "Chromium did not expose CDP; see ${STATE_DIR}/chromium.log"

log "Starting noVNC/websockify on 127.0.0.1:${NOVNC_PORT}"
websockify_pid="$(spawn websockify \
    "${HOME}/.local/bin/websockify" \
    --web "${NOVNC_DIR}" \
    "127.0.0.1:${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}")"
wait_for_port "${NOVNC_PORT}" "${websockify_pid}" 75 ||
    die "websockify did not become ready; see ${STATE_DIR}/websockify.log"
curl -fsS --max-time 5 "http://127.0.0.1:${NOVNC_PORT}/vnc.html" >/dev/null ||
    die "The local noVNC page did not answer"

log "Verifying Chromium through Playwright over CDP"
CDP_OUTPUT="$(
    CDP_URL="http://127.0.0.1:${CDP_PORT}" \
    SCREENSHOT_PATH="${SCREENSHOT_FILE}" \
    NODE_PATH=/tmp/pw/node_modules \
    node <<'NODE'
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.connectOverCDP(process.env.CDP_URL);
  let pages = browser.contexts().flatMap((context) => context.pages());
  if (!pages.length) throw new Error('CDP connected but Chromium has no pages');
  const seenGarminUrls = new Set();
  for (const page of pages) {
    if (!page.url().includes('garmin.com')) continue;
    if (seenGarminUrls.has(page.url())) await page.close();
    else seenGarminUrls.add(page.url());
  }
  pages = browser.contexts().flatMap((context) => context.pages());
  console.log(`Browser: ${browser.version()}`);
  console.log(`Pages: ${pages.length}`);
  for (const [index, page] of pages.entries()) {
    await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});
    console.log(`Page ${index + 1}: ${await page.title()} | ${page.url()}`);
  }
  await pages[0].screenshot({ path: process.env.SCREENSHOT_PATH });
  console.log(`Screenshot: ${process.env.SCREENSHOT_PATH}`);
  // Do not call browser.close(): over CDP that can terminate the owner's
  // persistent Chromium. Exiting this short verifier drops only this client.
  process.exit(0);
})().catch((error) => {
  console.error(error.stack || error);
  process.exit(1);
});
NODE
)" || die "Playwright CDP verification failed"
printf '%s\n' "${CDP_OUTPUT}" | tee "${STATE_DIR}/cdp-verification.txt" >&2

log "Starting Cloudflare Quick Tunnel"
cloudflared_pid="$(spawn cloudflared \
    cloudflared --no-autoupdate tunnel --protocol http2 \
    --url "http://127.0.0.1:${NOVNC_PORT}")"

TUNNEL_ORIGIN=""
for _ in {1..300}; do
    pid_is_alive "${cloudflared_pid}" ||
        die "cloudflared exited; see ${STATE_DIR}/cloudflared.log"
    TUNNEL_ORIGIN="$(rg -o 'https://[a-z0-9-]+\.trycloudflare\.com' \
        "${STATE_DIR}/cloudflared.log" | tail -n 1 || true)"
    if [[ -n "${TUNNEL_ORIGIN}" ]] &&
       rg -q 'Registered tunnel connection' "${STATE_DIR}/cloudflared.log"; then
        break
    fi
    sleep 0.2
done
[[ -n "${TUNNEL_ORIGIN}" ]] || die "Quick Tunnel URL was not found in cloudflared output"

PUBLIC_URL="${TUNNEL_ORIGIN}/vnc.html?autoconnect=1&resize=scale&path=websockify"
remote_ok=0
tunnel_host="${TUNNEL_ORIGIN#https://}"
for _ in {1..120}; do
    if curl -fsSL --max-time 10 "${TUNNEL_ORIGIN}/vnc.html" >/dev/null 2>&1; then
        remote_ok=1
        break
    fi
    # systemd-resolved can negatively cache a just-created random hostname.
    # Resolve it through Cloudflare DoH without changing the host's DNS setup,
    # then still curl the original HTTPS URL with normal certificate checks.
    tunnel_ip="$(
        curl -fsS --max-time 10 -H 'accept: application/dns-json' \
            "https://cloudflare-dns.com/dns-query?name=${tunnel_host}&type=A" 2>/dev/null |
        python3 -c 'import json, sys
try:
    answer = json.load(sys.stdin).get("Answer", [])
    print(next(item["data"] for item in answer if item.get("type") == 1))
except (StopIteration, KeyError, ValueError):
    pass' 2>/dev/null || true
    )"
    if [[ -n "${tunnel_ip}" ]] &&
       curl -fsSL --max-time 10 \
           --resolve "${tunnel_host}:443:${tunnel_ip}" \
           "${TUNNEL_ORIGIN}/vnc.html" >/dev/null 2>&1; then
        log "Verified the public noVNC page using DNS-over-HTTPS (local DNS had not propagated)"
        remote_ok=1
        break
    fi
    pid_is_alive "${cloudflared_pid}" || break
    sleep 0.5
done
((remote_ok)) || die "The Quick Tunnel did not return the noVNC page"

connect_tmp="${CONNECT_FILE}.tmp.$$"
printf '%s\nVNC password: %s\n' "${PUBLIC_URL}" "${VNC_PASSWORD}" >"${connect_tmp}"
chmod 600 "${connect_tmp}"
mv -f "${connect_tmp}" "${CONNECT_FILE}"
printf 'DISPLAY=%s\nVNC_PORT=%s\nNOVNC_PORT=%s\nCDP_PORT=%s\n' \
    "${DISPLAY_VALUE}" "${VNC_PORT}" "${NOVNC_PORT}" "${CDP_PORT}" >"${ACTIVE_CONFIG_FILE}"
chmod 600 "${ACTIVE_CONFIG_FILE}"

failed=0
cat "${CONNECT_FILE}"
