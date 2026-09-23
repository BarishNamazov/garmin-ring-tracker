#!/usr/bin/env bash

# Source this file from the repository root: source scripts/env.sh
ciq_root="${HOME}/.Garmin/ConnectIQ"

if [[ -z "${JAVA_HOME:-}" ]]; then
    if [[ -x "${ciq_root}/Jdks/temurin-17/bin/java" ]]; then
        JAVA_HOME="${ciq_root}/Jdks/temurin-17"
    elif command -v java >/dev/null 2>&1; then
        java_binary="$(readlink -f "$(command -v java)")"
        JAVA_HOME="$(cd "$(dirname "${java_binary}")/.." && pwd)"
    else
        printf 'Java 17 is not installed; run scripts/ci/install-toolchain.sh.\n' >&2
        return 1 2>/dev/null || exit 1
    fi
fi

export JAVA_HOME
export CIQ_SDK_HOME="${CIQ_SDK_HOME:-$(< "${ciq_root}/current-sdk.cfg")}"
export CIQ_DEVICE_HOME="${CIQ_DEVICE_HOME:-${ciq_root}/Devices}"
export CIQ_DEVELOPER_KEY="${CIQ_DEVELOPER_KEY:-${HOME}/.Garmin/developer_key.der}"

CIQ_SIM_RUNTIME="${CIQ_SIM_RUNTIME:-${ciq_root}/Runtime}"
ciq_patched_bin="${CIQ_SIM_RUNTIME}-patched-bin"
export CIQ_SIM_RUNTIME
export PATH="${ciq_patched_bin}:${CIQ_SIM_RUNTIME}/usr/bin:${JAVA_HOME}/bin:${CIQ_SDK_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CIQ_SIM_RUNTIME}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

ciq_headless_simulator() {
    if [[ -x "${CIQ_SIM_RUNTIME}/usr/bin/xkbcomp" ]]; then
        mkdir -p /tmp/ciq
        ln -sfn "${CIQ_SIM_RUNTIME}/usr/bin/xkbcomp" /tmp/ciq/xkbcomp
    fi
    xvfb-run -a connectiq
}
