#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
source "${project_dir}/scripts/env.sh"
cd "${project_dir}"

fresh_dir="${1:-bin/release}"
expected_files=(
    RingTracker-epix2pro42mm.prg
    RingTracker-epix2pro47mm.prg
    RingTracker-epix2pro51mm.prg
    RingTracker.iq
    SHA256SUMS
)

for name in "${expected_files[@]}"; do
    [[ -f "release/${name}" ]] || { printf 'Missing tracked release/%s.\n' "${name}" >&2; exit 1; }
done
for path in release/*; do
    [[ -f "${path}" ]] || continue
    name="${path##*/}"
    expected=false
    for candidate in "${expected_files[@]}"; do
        [[ "${name}" == "${candidate}" ]] && expected=true
    done
    if [[ "${expected}" != true ]]; then
        printf 'Unexpected tracked release file: %s\n' "${path}" >&2
        exit 1
    fi
done

(
    cd release
    sha256sum --check --strict SHA256SUMS
)

payload_hash() {
    local path="$1" size payload_size magic
    size="$(stat -c %s "${path}")"
    if (( size <= 1556 )); then
        printf 'PRG is too short to contain a signing trailer: %s\n' "${path}" >&2
        return 1
    fi
    # Compare compiler output while ignoring the key-dependent 4096-bit RSA
    # signing block. The preceding eight-byte header remains in the digest.
    payload_size=$((size - 1548))
    magic="$(dd if="${path}" bs=1 skip="$((payload_size - 8))" count=4 status=none | od -An -tx1 | tr -d ' \n')"
    if [[ "${magic}" != "e1c0de12" ]]; then
        printf 'Unrecognized PRG signing trailer: %s\n' "${path}" >&2
        return 1
    fi
    head -c "${payload_size}" "${path}" | sha256sum | cut -d' ' -f1
}

status=0
for name in "${expected_files[@]:0:3}"; do
    tracked_hash="$(payload_hash "release/${name}")"
    fresh_hash="$(payload_hash "${fresh_dir}/${name}")"
    if [[ "${tracked_hash}" != "${fresh_hash}" ]]; then
        printf 'Tracked release/%s is stale.\n' "${name}" >&2
        status=1
    fi
done

tracked_iq="$(mktemp)"
fresh_iq="$(mktemp)"
trap 'rm -f "${tracked_iq}" "${fresh_iq}"' EXIT
java --class-path "${CIQ_SDK_HOME}/bin/monkeybrains.jar" \
    "${project_dir}/scripts/IqPrgHashes.java" --payload release/RingTracker.iq | sort >"${tracked_iq}"
java --class-path "${CIQ_SDK_HOME}/bin/monkeybrains.jar" \
    "${project_dir}/scripts/IqPrgHashes.java" --payload "${fresh_dir}/RingTracker.iq" | sort >"${fresh_iq}"
if ! diff -u "${tracked_iq}" "${fresh_iq}"; then
    printf 'Tracked release/RingTracker.iq contains stale PRG payloads.\n' >&2
    status=1
fi

if (( status != 0 )); then
    exit "${status}"
fi
printf 'Tracked release PRG payloads and checksums are current.\n'
