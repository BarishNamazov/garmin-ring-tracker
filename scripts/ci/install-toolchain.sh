#!/usr/bin/env bash
set -euo pipefail

sdk_version="9.2.0"
sdk_archive="connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2.zip"
sdk_sha256="4907d8455b651c5a00a865e364cc4f1921c055b9279c7c8634c7a7a6773b5593"
sdk_url="https://developer.garmin.com/downloads/connect-iq/sdks/${sdk_archive}"

device_commit="cd073d7fc4083edf75eb3e1068d7ee4087c19423"
device_sha256="329ebb68bf55a07d86cda993a1381b20f7fc786eba059737abbf1d72778d2feb"
device_url="https://raw.githubusercontent.com/blackshadev/garmin-connectiq-tools/${device_commit}/devices.tar.gz"
devices=(epix2pro42mm epix2pro47mm epix2pro51mm)

font_image="ghcr.io/matco/connectiq-tester:v2.10.0"
font_layer="sha256:5ab73d22aa6d18bc1f0c8d6743bf0dafa1010e6a7b70a6619359a2889fac29d0"
font_layer_size=942680574

temurin_version="17.0.20.1_1"
temurin_sha256="3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e"
temurin_url="https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/OpenJDK17U-jdk_x64_linux_hotspot_${temurin_version}.tar.gz"

ciq_root="${HOME}/.Garmin/ConnectIQ"
sdk_dir="${ciq_root}/Sdks/${sdk_archive%.zip}"
device_dir="${ciq_root}/Devices"
font_dir="${ciq_root}/Fonts"
runtime_dir="${ciq_root}/Runtime"
patched_bin_dir="${ciq_root}/Runtime-patched-bin"
jdk_dir="${ciq_root}/Jdks/temurin-17"
downloaded_bytes=0

if [[ "$(uname -m)" != "x86_64" ]]; then
    printf 'The pinned Connect IQ Linux SDK requires x86_64.\n' >&2
    exit 1
fi

work_dir="$(mktemp -d /tmp/ring-tracker-toolchain.XXXXXX)"
cleanup() {
    if [[ "${work_dir}" == /tmp/ring-tracker-toolchain.* ]]; then
        rm -rf -- "${work_dir}"
    fi
}
trap cleanup EXIT

download_verified() {
    local label="$1" url="$2" expected="$3" output="$4" header="${5:-}" actual size
    printf 'Downloading %s...\n' "${label}"
    if [[ -n "${header}" ]]; then
        curl -fL --retry 4 --retry-all-errors -H "${header}" --output "${output}" "${url}"
    else
        curl -fL --retry 4 --retry-all-errors --output "${output}" "${url}"
    fi
    actual="$(sha256sum "${output}" | cut -d' ' -f1)"
    if [[ "${actual}" != "${expected}" ]]; then
        printf '%s SHA-256 mismatch: expected %s, got %s.\n' \
            "${label}" "${expected}" "${actual}" >&2
        exit 1
    fi
    size="$(stat -c %s "${output}")"
    downloaded_bytes=$((downloaded_bytes + size))
    printf '%s: %s bytes, SHA-256 verified.\n' "${label}" "${size}"
}

have_root_apt=false
if [[ "$(id -u)" == "0" ]]; then
    apt_prefix=()
    have_root_apt=true
elif command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
    apt_prefix=(sudo)
    have_root_apt=true
fi

if [[ "${have_root_apt}" == true ]]; then
    "${apt_prefix[@]}" apt-get update
    "${apt_prefix[@]}" apt-get install -y --no-install-recommends \
        ca-certificates curl jq openssl tar unzip \
        openjdk-17-jdk-headless xvfb xauth x11-xkb-utils \
        libatomic1 libegl1 libgstreamer-gl1.0-0 libgtk-3-0t64 libsecret-1-0 \
        libusb-1.0-0 libwayland-server0 libwebpdemux2
else
    printf 'Root apt is unavailable; installing Java and Xvfb support under %s.\n' "${ciq_root}"
fi

for command_name in curl jq openssl tar unzip sha256sum; do
    command -v "${command_name}" >/dev/null 2>&1 || {
        printf 'Required command is unavailable: %s\n' "${command_name}" >&2
        exit 1
    }
done

mkdir -p "${ciq_root}/Sdks" "${device_dir}" "${font_dir}" \
    "${runtime_dir}" "${patched_bin_dir}" "${ciq_root}/Jdks"

if [[ ! -x "${sdk_dir}/bin/monkeyc" ]]; then
    sdk_download="${work_dir}/${sdk_archive}"
    sdk_stage="${work_dir}/sdk"
    download_verified "Connect IQ SDK ${sdk_version}" "${sdk_url}" "${sdk_sha256}" "${sdk_download}"
    mkdir -p "${sdk_stage}" "${sdk_dir}"
    unzip -q "${sdk_download}" -d "${sdk_stage}"
    if [[ -x "${sdk_stage}/bin/monkeyc" ]]; then
        sdk_source="${sdk_stage}"
    else
        sdk_source="$(find "${sdk_stage}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    fi
    if [[ -z "${sdk_source}" || ! -x "${sdk_source}/bin/monkeyc" ]]; then
        printf 'The SDK archive did not contain the expected bin/monkeyc.\n' >&2
        exit 1
    fi
    cp -a "${sdk_source}/." "${sdk_dir}/"
fi
printf '%s\n' "${sdk_dir}" >"${ciq_root}/current-sdk.cfg"

devices_ready=true
for device in "${devices[@]}"; do
    [[ -f "${device_dir}/${device}/simulator.json" ]] || devices_ready=false
done
if [[ "${devices_ready}" != true || ! -f "${device_dir}/.ring-tracker-${device_commit}" ]]; then
    device_download="${work_dir}/devices.tar.gz"
    device_stage="${work_dir}/devices"
    download_verified "pinned device archive" "${device_url}" "${device_sha256}" "${device_download}"
    mkdir -p "${device_stage}"
    tar -xzf "${device_download}" -C "${device_stage}" \
        ./epix2pro42mm ./epix2pro47mm ./epix2pro51mm
    for device in "${devices[@]}"; do
        mkdir -p "${device_dir}/${device}"
        cp -a "${device_stage}/${device}/." "${device_dir}/${device}/"
    done
    : >"${device_dir}/.ring-tracker-${device_commit}"
fi

font_list="${work_dir}/fonts.txt"
for device in "${devices[@]}"; do
    jq -r '.fonts[].fonts[] | select(.filename | contains(" ") | not) |
        .filename + (if .type == "system_ttf" then ".ttf" else ".cft" end)' \
        "${device_dir}/${device}/simulator.json"
done | sort -u >"${font_list}"

fonts_ready=true
while IFS= read -r font; do
    [[ -f "${font_dir}/${font}" ]] || fonts_ready=false
done <"${font_list}"

if [[ "${fonts_ready}" != true || ! -f "${font_dir}/.ring-tracker-${font_layer#sha256:}" ]]; then
    token="$(curl -fsSL 'https://ghcr.io/token?scope=repository:matco/connectiq-tester:pull' | jq -r .token)"
    font_blob="${work_dir}/font-layer.tar.gz"
    download_verified "Connect IQ font layer (${font_layer_size} bytes)" \
        "https://ghcr.io/v2/matco/connectiq-tester/blobs/${font_layer}" \
        "${font_layer#sha256:}" "${font_blob}" "Authorization: Bearer ${token}"

    font_paths="${work_dir}/font-paths.txt"
    while IFS= read -r font; do
        printf 'root/.Garmin/ConnectIQ/Fonts/%s\n' "${font}"
    done <"${font_list}" >"${font_paths}"
    font_stage="${work_dir}/selected-fonts"
    mkdir -p "${font_stage}"
    tar -xzf "${font_blob}" -C "${font_stage}" --strip-components=4 \
        --files-from "${font_paths}"
    while IFS= read -r font; do
        [[ -f "${font_stage}/${font}" ]] || {
            printf 'Required font was absent from the pinned image: %s\n' "${font}" >&2
            exit 1
        }
        cp -a "${font_stage}/${font}" "${font_dir}/${font}"
    done <"${font_list}"
    : >"${font_dir}/.ring-tracker-${font_layer#sha256:}"
fi

apt_fetch_and_extract() {
    local series="$1" destination="$2"
    shift 2
    local apt_root="${work_dir}/apt-${series}" apt_user before after archive
    mkdir -p "${apt_root}/etc/apt" "${apt_root}/lists/partial" \
        "${apt_root}/cache/archives/partial" "${apt_root}/debs" "${destination}"
    {
        printf 'deb https://archive.ubuntu.com/ubuntu %s main universe\n' "${series}"
        printf 'deb https://archive.ubuntu.com/ubuntu %s-updates main universe\n' "${series}"
        printf 'deb https://security.ubuntu.com/ubuntu %s-security main universe\n' "${series}"
    } >"${apt_root}/etc/apt/sources.list"
    apt_user="$(id -un)"
    apt_options=(
        -o "Dir::Etc::sourcelist=${apt_root}/etc/apt/sources.list"
        -o "Dir::Etc::sourceparts=-"
        -o "Dir::State::lists=${apt_root}/lists"
        -o "Dir::Cache=${apt_root}/cache"
        -o "APT::Get::List-Cleanup=0"
        -o "APT::Sandbox::User=${apt_user}"
    )
    apt-get "${apt_options[@]}" update
    before="$(find "${apt_root}/debs" -type f -name '*.deb' -printf '%s\n' | awk '{s += $1} END {print s + 0}')"
    (
        cd "${apt_root}/debs"
        apt-get "${apt_options[@]}" download "$@"
    )
    after="$(find "${apt_root}/debs" -type f -name '*.deb' -printf '%s\n' | awk '{s += $1} END {print s + 0}')"
    downloaded_bytes=$((downloaded_bytes + after - before))
    for archive in "${apt_root}"/debs/*.deb; do
        dpkg-deb -x "${archive}" "${destination}"
    done
}

legacy_marker="${runtime_dir}/.ring-tracker-jammy-webkit4"
if [[ ! -f "${legacy_marker}" ]]; then
    apt_fetch_and_extract jammy "${runtime_dir}" \
        libenchant-2-2 libicu70 libjavascriptcoregtk-4.0-18 \
        libmanette-0.2-0 libsoup2.4-1 libwebkit2gtk-4.0-37 libwoff1
    : >"${legacy_marker}"
fi

if [[ "${have_root_apt}" != true ]]; then
    native_marker="${runtime_dir}/.ring-tracker-noble-runtime-v4"
    if [[ ! -f "${native_marker}" ]]; then
        apt_fetch_and_extract noble "${runtime_dir}" \
            libatomic1 libegl1 libfontenc1 libgstreamer-gl1.0-0 libsecret-1-0 \
            libwayland-server0 libwebpdemux2 libxfont2 libxkbfile1 \
            x11-xkb-utils xauth xserver-common xvfb
        if [[ ! -x "${runtime_dir}/usr/bin/Xvfb" || ! -x "${runtime_dir}/usr/bin/xkbcomp" ]]; then
            printf 'The local Xvfb runtime is incomplete.\n' >&2
            exit 1
        fi
        sed 's#/usr/bin#/tmp/ciq#g' "${runtime_dir}/usr/bin/Xvfb" \
            >"${patched_bin_dir}/Xvfb"
        chmod +x "${patched_bin_dir}/Xvfb"
        : >"${native_marker}"
    fi

    if [[ ! -x "${jdk_dir}/bin/java" ]]; then
        jdk_download="${work_dir}/temurin-17.tar.gz"
        jdk_stage="${work_dir}/jdk"
        download_verified "Temurin JDK 17" "${temurin_url}" "${temurin_sha256}" "${jdk_download}"
        mkdir -p "${jdk_stage}" "${jdk_dir}"
        tar -xzf "${jdk_download}" -C "${jdk_stage}"
        jdk_source="$(find "${jdk_stage}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
        if [[ -z "${jdk_source}" || ! -x "${jdk_source}/bin/java" ]]; then
            printf 'The JDK archive did not contain bin/java.\n' >&2
            exit 1
        fi
        cp -a "${jdk_source}/." "${jdk_dir}/"
    fi
fi

if [[ -x "${jdk_dir}/bin/java" ]]; then
    export JAVA_HOME="${jdk_dir}"
else
    java_binary="$(readlink -f "$(command -v java)")"
    export JAVA_HOME="$(cd "$(dirname "${java_binary}")/.." && pwd)"
fi
export PATH="${patched_bin_dir}:${runtime_dir}/usr/bin:${JAVA_HOME}/bin:${sdk_dir}/bin:${PATH}"
export LD_LIBRARY_PATH="${runtime_dir}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

missing_libraries="$(ldd "${sdk_dir}/bin/simulator" | sed -n 's/^[[:space:]]*\([^ ]*\) => not found$/\1/p')"
if [[ -n "${missing_libraries}" ]]; then
    printf 'Simulator libraries are missing:\n%s\n' "${missing_libraries}" >&2
    exit 1
fi

font_count="$(wc -l <"${font_list}")"
font_bytes=0
while IFS= read -r font; do
    size="$(stat -c %s "${font_dir}/${font}")"
    font_bytes=$((font_bytes + size))
done <"${font_list}"

cat >"${ciq_root}/ring-tracker-toolchain.txt" <<EOF
SDK_VERSION=${sdk_version}
SDK_SHA256=${sdk_sha256}
DEVICE_COMMIT=${device_commit}
DEVICE_SHA256=${device_sha256}
FONT_IMAGE=${font_image}
FONT_LAYER=${font_layer}
FONT_COUNT=${font_count}
FONT_BYTES=${font_bytes}
EOF

java -version
monkeyc --version
printf 'Installed %s required simulator fonts (%s bytes).\n' "${font_count}" "${font_bytes}"
printf 'Direct artifacts downloaded this run: %s bytes.\n' "${downloaded_bytes}"
printf 'Connect IQ toolchain is ready under %s.\n' "${ciq_root}"
