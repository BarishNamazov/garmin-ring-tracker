#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/env.sh"
cd "${project_dir}"

devices=(epix2pro42mm epix2pro47mm epix2pro51mm)
simulator_pid=""
simulator_log=""

print_hashes() {
    local path
    for path in "$@"; do
        sha256sum "${path}"
    done
}

build_release() {
    local output_dir="bin/release"
    local outputs=()
    local device output
    mkdir -p "${output_dir}"
    for device in "${devices[@]}"; do
        output="${output_dir}/RingTracker-${device}.prg"
        monkeyc -d "${device}" -f monkey.jungle -o "${output}" \
            -y "${CIQ_DEVELOPER_KEY}" -w -r
        outputs+=("${output}")
    done
    monkeyc -e -f monkey.jungle -o "${output_dir}/RingTracker.iq" \
        -y "${CIQ_DEVELOPER_KEY}" -w -r
    outputs+=("${output_dir}/RingTracker.iq")
    print_hashes "${outputs[@]}"
}

build_debug() {
    local output_dir="bin/debug"
    local outputs=()
    local device output
    mkdir -p "${output_dir}"
    for device in "${devices[@]}"; do
        output="${output_dir}/RingTracker-${device}.prg"
        monkeyc -d "${device}" -f monkey.debug.jungle -o "${output}" \
            -y "${CIQ_DEVELOPER_KEY}" -w
        outputs+=("${output}")
    done
    print_hashes "${outputs[@]}"
}

run_tests() {
    local output_dir="bin/test"
    local test_prg="${output_dir}/RingTracker-tests.prg"
    local test_output runner_status summary passed failed errors
    mkdir -p "${output_dir}"
    monkeyc -d epix2pro47mm -f monkey.tests.jungle -o "${test_prg}" \
        -y "${CIQ_DEVELOPER_KEY}" -w --unit-test
    print_hashes "${test_prg}"

    if ! pgrep -f "${CIQ_SDK_HOME}/bin/simulator" >/dev/null 2>&1; then
        simulator_log="$(mktemp /tmp/ring-tracker-simulator.XXXXXX.log)"
        setsid bash -c 'source "$1"; TZ=America/New_York ciq_headless_simulator' \
            _ "${script_dir}/env.sh" >"${simulator_log}" 2>&1 &
        simulator_pid=$!
        trap 'if [[ -n "${simulator_pid}" ]]; then kill -- "-${simulator_pid}" 2>/dev/null || true; wait "${simulator_pid}" 2>/dev/null || true; fi; if [[ -n "${simulator_log}" ]]; then rm -f "${simulator_log}"; fi' EXIT
        sleep 4
        if ! kill -0 "${simulator_pid}" 2>/dev/null; then
            printf 'Headless simulator failed to start. Log:\n' >&2
            sed -n '1,160p' "${simulator_log}" >&2
            exit 1
        fi
    fi

    set +e
    test_output="$(TZ=America/New_York monkeydo "${test_prg}" epix2pro47mm -t 2>&1)"
    runner_status=$?
    set -e
    printf '%s\n' "${test_output}"
    summary="$(printf '%s\n' "${test_output}" | sed -n \
        's/.*PASSED (passed=\([0-9][0-9]*\), failed=\([0-9][0-9]*\), errors=\([0-9][0-9]*\)).*/\1 \2 \3/p' | tail -n 1)"
    if [[ -z "${summary}" ]]; then
        printf 'Tests: unable to parse result (monkeydo status %s)\n' "${runner_status}" >&2
        exit 1
    fi
    read -r passed failed errors <<<"${summary}"
    printf 'Tests: passed=%s failed=%s errors=%s\n' "${passed}" "${failed}" "${errors}"
    if (( runner_status != 0 || failed != 0 || errors != 0 )); then
        exit 1
    fi
}

case "${1:-}" in
    release) build_release ;;
    debug) build_debug ;;
    test) run_tests ;;
    *)
        printf 'Usage: %s {release|debug|test}\n' "$0" >&2
        exit 2
        ;;
esac
