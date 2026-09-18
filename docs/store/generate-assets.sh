#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../.." && pwd)"
python_bin="${STORE_PYTHON:-python3}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

command -v rsvg-convert >/dev/null
"${python_bin}" -c 'import PIL, PIL.ImageCms' >/dev/null

mkdir -p "${script_dir}/screenshots"

# Preserve the launcher artwork and replace only its prohibited black Store
# background with the app's dark navy. The artwork already has more than the
# required 10 px of padding when rendered at 500 x 500.
sed 's/fill="#000000"/fill="#101B2D"/' \
  "${repo_root}/resources/drawables/launcher.svg" \
  >"${tmp_dir}/launcher-store.svg"
rsvg-convert --width 500 --height 500 \
  --output "${tmp_dir}/icon-500-rendered.png" \
  "${tmp_dir}/launcher-store.svg"

"${python_bin}" - "${repo_root}" "${script_dir}" "${tmp_dir}" <<'PY'
from pathlib import Path
import struct
import sys

from PIL import Image, ImageChops, ImageCms

repo_root = Path(sys.argv[1])
store_dir = Path(sys.argv[2])
tmp_dir = Path(sys.argv[3])

srgb_profile_bytes = bytearray(
    ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
)
# LittleCMS stamps newly created profiles with the current time, which makes
# otherwise identical PNGs change on every run. Use a fixed valid creation
# date and leave the optional profile ID unset so generated assets are
# byte-reproducible across runs with the same Pillow/libpng toolchain.
srgb_profile_bytes[24:36] = struct.pack(">6H", 2026, 9, 17, 0, 0, 0)
srgb_profile_bytes[84:100] = bytes(16)
srgb_profile = bytes(srgb_profile_bytes)


def save_srgb(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        image.convert("RGB").save(
            destination,
            format="PNG",
            icc_profile=srgb_profile,
            optimize=True,
            compress_level=9,
        )


save_srgb(tmp_dir / "icon-500-rendered.png", store_dir / "icon-500.png")

screenshots = [
    ("epix2pro47mm-main-ring-in.png", "01-main-ring-in.png"),
    ("epix2pro47mm-main-ring-free.png", "02-ring-free.png"),
    ("epix2pro47mm-upcoming-rows-1-3.png", "03-upcoming.png"),
    ("epix2pro47mm-glance-ring-in.png", "04-glance.png"),
    ("epix2pro47mm-main-temporary-out-2h50.png", "05-ring-out.png"),
    ("epix2pro47mm-main-overdue-insert.png", "06-overdue-alternate.png"),
    ("epix2pro47mm-history.png", "07-history-alternate.png"),
    ("epix2pro47mm-settings-reminder2-on.png", "08-settings-alternate.png"),
]

for source_name, destination_name in screenshots:
    save_srgb(
        repo_root / "docs" / "screenshots" / source_name,
        store_dir / "screenshots" / destination_name,
    )

with Image.open(store_dir / "icon-500.png") as icon:
    assert icon.size == (500, 500)
    assert icon.mode == "RGB"
    assert icon.info.get("icc_profile")
    background = Image.new("RGB", icon.size, (0x10, 0x1B, 0x2D))
    bounds = ImageChops.difference(icon, background).getbbox()
    assert bounds is not None
    left, top, right, bottom = bounds
    padding = min(left, top, 500 - right, 500 - bottom)
    assert padding >= 10
    print(f"icon-500.png: 500x500 RGB, sRGB ICC, minimum artwork padding {padding}px")

for _, destination_name in screenshots:
    path = store_dir / "screenshots" / destination_name
    with Image.open(path) as image:
        assert image.size == (416, 416)
        assert image.mode == "RGB"
        assert image.info.get("icc_profile")
        assert path.stat().st_size < 150 * 1024
        print(
            f"screenshots/{destination_name}: "
            f"416x416 RGB, sRGB ICC, {path.stat().st_size} bytes"
        )
PY
