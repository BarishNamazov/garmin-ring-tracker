#!/usr/bin/env bash

# Source this file from Bash: source /home/agent/Dev/garmin-bc/scripts/env.sh
export JAVA_HOME="/home/agent/.local/jdks/temurin-17"
export CIQ_SDK_HOME="$(< /home/agent/.Garmin/ConnectIQ/current-sdk.cfg)"
export CIQ_DEVICE_HOME="/home/agent/.Garmin/ConnectIQ/Devices"
export CIQ_DEVELOPER_KEY="/home/agent/.Garmin/developer_key.der"

# User-local libraries installed for the optional headless simulator test.
export CIQ_SIM_RUNTIME="/home/agent/.local/opt/ciq-runtime"
export PATH="/home/agent/.local/opt/ciq-runtime-patched-bin:${CIQ_SIM_RUNTIME}/usr/bin:${JAVA_HOME}/bin:${CIQ_SDK_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CIQ_SIM_RUNTIME}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# The Ubuntu X server binary has /usr/bin/xkbcomp compiled into it. The
# user-local Xvfb copy redirects that lookup here because system apt access was
# unavailable on this host.
ciq_headless_simulator() {
    mkdir -p /tmp/ciq
    ln -sfn "${CIQ_SIM_RUNTIME}/usr/bin/xkbcomp" /tmp/ciq/xkbcomp
    xvfb-run -a connectiq
}
