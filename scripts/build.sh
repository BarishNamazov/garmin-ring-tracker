#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
source "${script_dir}/env.sh"
cd "${project_dir}"
"${script_dir}/check-background-scope.sh"
python3 "${script_dir}/ci/check-devices.py"

mapfile -t devices < <(sed '/^#/d; /^$/d' supported-devices.txt)
simulator_pid=""
simulator_log=""

simulator_running() {
    local cmdline executable
    for cmdline in /proc/[0-9]*/cmdline; do
        [[ -r "${cmdline}" ]] || continue
        executable=""
        IFS= read -r -d '' executable <"${cmdline}" || true
        if [[ "${executable}" == "${CIQ_SDK_HOME}/bin/simulator" ]]; then
            return 0
        fi
    done
    return 1
}

simulator_alive() {
    if [[ -n "${simulator_pid}" ]]; then
        kill -0 "${simulator_pid}" 2>/dev/null
    else
        simulator_running
    fi
}

print_hashes() {
    local path
    for path in "$@"; do
        sha256sum "${path}"
    done
}

print_iq_prg_hashes() {
    java --class-path "${CIQ_SDK_HOME}/bin/monkeybrains.jar" \
        "${script_dir}/IqPrgHashes.java" "$1"
}

build_release_iq() {
    local output_dir="bin/release"
    mkdir -p "${output_dir}"
    monkeyc -e -f monkey.jungle -o "${output_dir}/RingTracker.iq" \
        -y "${CIQ_DEVELOPER_KEY}" -w -r
    print_iq_prg_hashes "${output_dir}/RingTracker.iq"
}

build_release() {
    local outputs=()
    local device parts_file
    build_release_iq
    parts_file="$(mktemp)"
    for device in "${devices[@]}"; do
        printf '%s\t%s\n' "${device}" \
            "$(jq -r '.partNumbers[0].number' "${CIQ_DEVICE_HOME}/${device}/compiler.json")" \
            >>"${parts_file}"
    done
    java --class-path "${CIQ_SDK_HOME}/bin/monkeybrains.jar" \
        "${script_dir}/ExtractIqPrgs.java" "bin/release/RingTracker.iq" \
        "${parts_file}" "bin/release"
    rm -f -- "${parts_file}"
    for device in "${devices[@]}"; do
        outputs+=("bin/release/RingTracker-${device}.prg")
    done
    outputs+=("bin/release/RingTracker.iq")
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
    local test_device="${2:-epix2pro47mm}"
    local test_prg="${output_dir}/RingTracker-tests-${test_device}.prg"
    local test_output runner_status summary passed failed errors
    local attempt max_attempts=30
    mkdir -p "${output_dir}"
    monkeyc -d "${test_device}" -f monkey.tests.jungle -o "${test_prg}" \
        -y "${CIQ_DEVELOPER_KEY}" -w --unit-test
    print_hashes "${test_prg}"

    if ! simulator_running; then
        simulator_log="${output_dir}/simulator.log"
        : >"${simulator_log}"
        set -m
        bash -c 'source "$1"; TZ=America/New_York ciq_headless_simulator' \
            _ "${script_dir}/env.sh" >"${simulator_log}" 2>&1 &
        simulator_pid=$!
        set +m
        trap 'if [[ -n "${simulator_pid}" ]]; then kill -- "-${simulator_pid}" 2>/dev/null || true; wait "${simulator_pid}" 2>/dev/null || true; fi' EXIT
        sleep 2
        if ! kill -0 "${simulator_pid}" 2>/dev/null; then
            printf 'Headless simulator failed to start. Log:\n' >&2
            sed -n '1,160p' "${simulator_log}" >&2
            exit 1
        fi
    fi

    for ((attempt = 1; attempt <= max_attempts; attempt++)); do
        set +e
        test_output="$(TZ=America/New_York monkeydo "${test_prg}" "${test_device}" -t 2>&1)"
        runner_status=$?
        set -e
        if [[ "${test_output}" != *"Unable to connect to simulator."* ]]; then
            break
        fi
        if ! simulator_alive; then
            printf 'Headless simulator exited before accepting connections. Log:\n' >&2
            [[ -n "${simulator_log}" ]] && sed -n '1,160p' "${simulator_log}" >&2
            exit 1
        fi
        if (( attempt < max_attempts )); then
            printf 'Simulator is not ready (attempt %s/%s); retrying.\n' \
                "${attempt}" "${max_attempts}"
            sleep 2
        fi
    done
    printf '%s\n' "${test_output}"
    printf 'monkeydo status: %s\n' "${runner_status}"
    if [[ "${test_output}" == *"Unable to connect to simulator."* ]]; then
        printf 'Simulator did not accept connections after %s attempts. Log:\n' \
            "${max_attempts}" >&2
        [[ -n "${simulator_log}" ]] && sed -n '1,160p' "${simulator_log}" >&2
    fi
    summary="$(printf '%s\n' "${test_output}" | sed -n \
        's/.*(passed=\([0-9][0-9]*\), failed=\([0-9][0-9]*\), errors=\([0-9][0-9]*\)).*/\1 \2 \3/p' | tail -n 1)"
    if [[ -z "${summary}" ]]; then
        printf 'Tests: unable to parse result (monkeydo status %s)\n' "${runner_status}" >&2
        exit 1
    fi
    read -r passed failed errors <<<"${summary}"
    printf 'Tests: passed=%s failed=%s errors=%s\n' "${passed}" "${failed}" "${errors}"
    if (( passed == 0 || failed != 0 || errors != 0 )); then
        exit 1
    fi
}

case "${1:-}" in
    release) build_release ;;
    release-iq) build_release_iq ;;
    debug) build_debug ;;
    test) run_tests "$@" ;;
    *)
        printf 'Usage: %s {release|release-iq|debug|test [device-id]}\n' "$0" >&2
        exit 2
        ;;
esac
