#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/../.." && pwd)"
cd "${project_dir}"

manifest_version="$(sed -n '/<iq:application/,/>/s/.*version="\([^"]*\)".*/\1/p' manifest.xml | head -n 1)"
about_version="$(sed -n 's/.*<string id="ProductVersion">Ring Tracker v\([^<]*\)<\/string>.*/\1/p' resources/strings/strings.xml | head -n 1)"
changelog_version="$(sed -n 's/^## \[\([^]]*\)\].*/\1/p' CHANGELOG.md | head -n 1)"

if [[ -z "${about_version}" || -z "${changelog_version}" ]]; then
    printf 'Could not read the About or top CHANGELOG version.\n' >&2
    exit 1
fi

expected="${manifest_version:-${about_version}}"
status=0
for pair in "About:${about_version}" "CHANGELOG:${changelog_version}"; do
    label="${pair%%:*}"
    actual="${pair#*:}"
    if [[ "${actual}" != "${expected}" ]]; then
        printf '%s version %s does not match %s.\n' "${label}" "${actual}" "${expected}" >&2
        status=1
    fi
done

if [[ -n "${1:-}" ]]; then
    tag="${1}"
    tag_version="${tag#v}"
    if [[ "${tag}" != v* || "${tag_version}" != "${expected}" ]]; then
        printf 'Git tag %s does not match v%s.\n' "${tag}" "${expected}" >&2
        status=1
    fi
fi

if [[ ! "${expected}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
    printf 'Version is not semantic: %s\n' "${expected}" >&2
    status=1
fi

if (( status != 0 )); then
    exit "${status}"
fi
printf 'Version consistency check passed: %s\n' "${expected}"
