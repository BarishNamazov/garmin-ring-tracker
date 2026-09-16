#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
cd "${project_dir}"

status=0
while IFS= read -r symbol; do
    [[ -n "${symbol}" ]] || continue
    if ! grep -Eq "<string id=\"${symbol}\"[^>]*scope=\"background\"" resources/strings/strings.xml; then
        printf 'Background string is missing scope="background": %s\n' "${symbol}" >&2
        status=1
    fi
done < <(
    {
        grep -Eo 'Rez\.Strings\.[A-Za-z0-9_]+' source/ServiceDelegate.mc || true
        grep -Eo 'Rez\.Strings\.[A-Za-z0-9_]+' source/BackgroundRuntime.mc || true
    } | sed 's/.*Rez\.Strings\.//' | sort -u
)

exit_count="$({ grep -Eo 'Background\.exit\(' source/ServiceDelegate.mc || true; } | wc -l)"
if [[ "${exit_count}" != "1" ]]; then
    printf 'ServiceDelegate must contain exactly one Background.exit call; found %s\n' "${exit_count}" >&2
    status=1
fi

exit "${status}"
