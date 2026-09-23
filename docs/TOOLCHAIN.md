# Build an Epix Pro (Gen 2) device app from the command line

The project can compile signed Garmin Connect IQ device apps for the 55 round
watches in [`supported-devices.txt`](../supported-devices.txt) with Connect IQ
SDK 9.2.0. The setup is headless and stores the SDK and device definitions
outside this repository.

## Installed toolchain

| Component | Version or value | Path |
| --- | --- | --- |
| Connect IQ SDK | 9.2.0 | `~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2` |
| Active SDK pointer | SDK path above | `~/.Garmin/ConnectIQ/current-sdk.cfg` |
| Java | OpenJDK 17 | System package, or `~/.Garmin/ConnectIQ/Jdks/temurin-17` without root access |
| Device definitions | Snapshot from 2026-08-08 | `~/.Garmin/ConnectIQ/Devices` |
| Required simulator fonts | 515 CFT/TTF files | `~/.Garmin/ConnectIQ/Fonts` |
| RSA signing key | 4096-bit PKCS#8 DER | `~/.Garmin/developer_key.der` by default |

The SDK was selected from Garmin's [`sdks.json`](https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json). Its Linux archive is `connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2.zip`, SHA-256 `4907d8455b651c5a00a865e364cc4f1921c055b9279c7c8634c7a7a6773b5593`.

`scripts/ci/install-toolchain.sh` installs OpenJDK 17 with apt when root access is available. Without root access it installs Eclipse Temurin 17.0.20.1+1 under the Connect IQ tree; that archive has SHA-256 `3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e`.

Install the complete toolchain without a Garmin login:

```bash
./scripts/ci/install-toolchain.sh
```

The installer verifies the pinned SDK and device-archive SHA-256 values, verifies the pinned OCI font-layer digest, extracts the selected device directories and referenced fonts, installs the simulator runtime, and writes `~/.Garmin/ConnectIQ/current-sdk.cfg`. Repeating the command against a complete installation performs validation without downloading those artifacts again. The complete `~/.Garmin` tree is suitable for a CI cache.

## Shell environment

Source the checked-in environment file before invoking the SDK tools:

```bash
source scripts/env.sh
java -version
monkeyc --version
```

The observed compiler version is `Connect IQ Compiler version: 9.2.0`. The environment file exports `JAVA_HOME`, `CIQ_SDK_HOME`, `CIQ_DEVICE_HOME`, `CIQ_DEVELOPER_KEY`, and `CIQ_SIM_RUNTIME`; it adds Java, Connect IQ, and the optional user-local simulator support tools to `PATH`.

Garmin's documented minimal SDK-only PATH setup is:

```bash
export PATH="${PATH}:$(cat "${HOME}/.Garmin/ConnectIQ/current-sdk.cfg")/bin"
```

## Device definitions

Garmin's current device service at `https://api.gcs.garmin.com/ciq-product-onboarding/devices?sdkManagerVersion=1.0.5` returned HTTP 401 without a Garmin session. Plausible static device-index and per-device URLs under `https://developer.garmin.com/downloads/connect-iq/` returned HTTP 404. The official SDK Manager is a GUI executable: passing `--help` did not expose a device-download CLI. It can start under Xvfb once its legacy libraries are present, but login and device download still require the GUI and a Garmin account.

The community [`connect-iq-sdk-manager-cli`](https://github.com/lindell/connect-iq-sdk-manager-cli) provides headless SDK and device commands, but its device list and download commands use the same authenticated Garmin service. It therefore does not remove the account requirement.

The installed definitions instead came from the public [`blackshadev/garmin-connectiq-tools`](https://github.com/blackshadev/garmin-connectiq-tools) device archive pinned at commit [`cd073d7fc4083edf75eb3e1068d7ee4087c19423`](https://github.com/blackshadev/garmin-connectiq-tools/commit/cd073d7fc4083edf75eb3e1068d7ee4087c19423), dated 2026-08-08. That project's update script archives locally installed SDK Manager device directories. Archive SHA-256: `329ebb68bf55a07d86cda993a1381b20f7fc786eba059737abbf1d72778d2feb`.

Only these archive directories were extracted:

```text
~/.Garmin/ConnectIQ/Devices/epix2pro42mm  (67 files)
~/.Garmin/ConnectIQ/Devices/epix2pro47mm  (67 files)
~/.Garmin/ConnectIQ/Devices/epix2pro51mm  (77 files)
```

Each directory includes `compiler.json`, `simulator.json`, the compiled device API data, device image, personality stylesheet, icons, and other device resources required by `monkeyc`.

### Simulator system fonts

The device archive does not contain the separately downloaded system fonts. Device `simulator.json` files name those font resources without an extension; for example, the English `Graphics.FONT_MEDIUM` resources are `FNT_006B431200_CDPG_ROBOTO_32B`, `FNT_006B431300_CDPG_ROBOTO_34B`, and `FNT_006B431400_CDPG_ROBOTO_37B` for the 42, 47, and 51 mm devices respectively. The simulator resolves the corresponding `.cft` files from the shared directory:

```text
~/.Garmin/ConnectIQ/Fonts
```

This matches the SDK Manager layout and the implementation of the community [`connect-iq-sdk-manager-cli`](https://github.com/lindell/connect-iq-sdk-manager-cli), which extracts Garmin's per-font downloads into the shared `Fonts` directory. Garmin's font API requires an authenticated session, so the files were instead recovered from the public [`ghcr.io/matco/connectiq-tester:v2.10.0`](https://github.com/matco/connectiq-tester) image. That project documents that its tester image includes device bits, fonts, and the simulator; its resource Dockerfile copies `Fonts/*.cft` and `Fonts/*.ttf` from an SDK Manager installation.

The installer fetches the one OCI layer containing `/root/.Garmin/ConnectIQ/Fonts` directly through the GHCR Registry API. It extracts only the filenames referenced by the selected `simulator.json` files into `~/.Garmin/ConnectIQ/Fonts`. Provenance for the payload:

```text
Image:        ghcr.io/matco/connectiq-tester:v2.10.0
Source commit: 5508cf707cbd7435f7f1e9226d2303f4349bfc3b
Resource set: 2026-08-31
Layer digest: sha256:5ab73d22aa6d18bc1f0c8d6743bf0dafa1010e6a7b70a6619359a2889fac29d0
Layer size:   942,680,574 compressed bytes
Installed:    515 referenced .cft/.ttf files (535,047,097 bytes)
```

Every non-placeholder font filename referenced by the selected `simulator.json` files exists in the shared directory. Names such as `bitstreamVeraSans 16` are logical built-in font names rather than downloadable filenames; the SDK Manager CLI likewise skips references containing spaces.

These are third-party-redistributed Garmin assets, not an official anonymous Garmin download. Review Garmin's licensing terms before redistributing them further; an authenticated SDK Manager download should replace them when official provenance is required.

Exact `compiler.json` snapshots are checked in for reference:

- [`epix2pro42mm.compiler.json`](devices/epix2pro42mm.compiler.json)
- [`epix2pro47mm.compiler.json`](devices/epix2pro47mm.compiler.json)
- [`epix2pro51mm.compiler.json`](devices/epix2pro51mm.compiler.json)

## Device display and memory limits

The shape comes from each `simulator.json`. Resolution, API level, program file limit, and app memory limits come from each `compiler.json`. The table below is the original epix Pro reference set; the build now includes all IDs in `supported-devices.txt`.

| Device ID | Display name | Shape | Resolution | API level | Maximum PRG size |
| --- | --- | --- | --- | --- | --- |
| `epix2pro42mm` | epix Pro (Gen 2) 42mm | Round AMOLED | 390 × 390 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |
| `epix2pro47mm` | epix Pro (Gen 2) 47mm / quatix 7 Pro | Round AMOLED | 416 × 416 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |
| `epix2pro51mm` | epix Pro (Gen 2) 51mm / D2 Mach 1 Pro / tactix 7 AMOLED Edition | Round AMOLED | 454 × 454 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |

The three epix Pro compiler definitions specify the following app-type memory limits. Other watches can have smaller limits and must be evaluated separately:

| App type | Bytes | KiB |
| --- | ---: | ---: |
| Audio content provider | 524,288 | 512 |
| Background process | 65,536 | 64 |
| Data field | 262,144 | 256 |
| Glance | 65,536 | 64 |
| Watch app (device app) | 786,432 | 768 |
| Watch face | 131,072 | 128 |

## Signing key

The key was generated with the Garmin-documented OpenSSL flow:

```bash
openssl genrsa -out "${HOME}/.Garmin/developer_key.pem" 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in "${HOME}/.Garmin/developer_key.pem" \
  -out "${HOME}/.Garmin/developer_key.der" -nocrypt
```

Both key files have mode `0600`. Do not commit either key.

## Verified hello-world build

The temporary test project is `/tmp/ciqhello`. It is a `watch-app` with `minSdkVersion="5.2.0"` and all three product IDs in `manifest.xml`. Its view draws `Hello, Epix!` with `Graphics.FONT_MEDIUM`, exercising the installed Garmin system-font bundle.

This exact requested command succeeded without warnings or errors:

```bash
source scripts/env.sh
cd /tmp/ciqhello
monkeyc -d epix2pro47mm -f monkey.jungle -o bin/hello.prg \
  -y ~/.Garmin/developer_key.der -w
```

Observed result:

```text
BUILD SUCCESSFUL
/tmp/ciqhello/bin/hello.prg
SHA-256 0bdb46f5402767a1dcbea39025843c575c7d7366ac845846e829f001a9692ae8
```

The font-validation build used the same compiler options with a separate output name:

```bash
monkeyc -d epix2pro47mm -f monkey.jungle \
  -o bin/hello-font-medium.prg -y ~/.Garmin/developer_key.der -w
```

The same project also built successfully for the other family members:

```bash
monkeyc -d epix2pro42mm -f monkey.jungle \
  -o bin/hello-epix2pro42mm.prg -y ~/.Garmin/developer_key.der -w
monkeyc -d epix2pro51mm -f monkey.jungle \
  -o bin/hello-epix2pro51mm.prg -y ~/.Garmin/developer_key.der -w
```

## Headless simulator result

The SDK 9.2.0 simulator links against libraries removed from Ubuntu 24.04, including WebKitGTK 4.0 and libsoup 2.4. The installer puts the required Ubuntu 22.04 libraries under `~/.Garmin/ConnectIQ/Runtime`. It installs Ubuntu 24.04 Xvfb through apt when root access is available, or extracts a user-local copy and redirects its compiled-in `xkbcomp` lookup when root access is unavailable.

After sourcing `scripts/env.sh`, start the simulator with the helper function and launch the app from a second shell:

```bash
# First shell
source scripts/env.sh
ciq_headless_simulator

# Second shell
source scripts/env.sh
monkeydo /tmp/ciqhello/bin/hello.prg epix2pro47mm
```

`connectiq` remained running under Xvfb. `monkeydo` loaded the 47 mm font-validation PRG, selected part number `006-B4313-00`, and remained attached until manually stopped. The simulator reported Connect IQ API 5.2.0 and runtime version 6.0.2. It rendered `Hello, Epix!` with `Graphics.FONT_MEDIUM` and produced no runtime error.

The Xvfb display was captured successfully with the user-local `xwd` and ImageMagick tools. The proof image remains outside the repository at `/tmp/ciqhello-font-medium.png` (1280 × 1024 PNG). A repeatable capture while the simulator is on display `:99` is:

```bash
source scripts/env.sh
export DISPLAY=:99
xwd -silent -root -out /tmp/ciqhello-font-medium.xwd
export MAGICK_CONFIGURE_PATH="$CIQ_SIM_RUNTIME/etc/ImageMagick-6"
export MAGICK_CODER_MODULE_PATH="$CIQ_SIM_RUNTIME/usr/lib/x86_64-linux-gnu/ImageMagick-6.9.12/modules-Q16/coders"
convert-im6.q16 /tmp/ciqhello-font-medium.xwd /tmp/ciqhello-font-medium.png
```

Before the shared font payload was installed, the same `Graphics.FONT_MEDIUM` view loaded but crashed with `Invalid Font Specified`. Its successful render after installation proves that the font lookup is now working. Xvfb emits non-fatal warnings for several unresolved `XF86*` key symbols.

### Simulated time

The simulator GUI is operable headlessly with `xdotool`; X11 automation can open its menus and capture the popup. However, for the requested `watch-app`/device-app, **Simulation → Time Simulation** is disabled. Garmin developers confirm that this control is only available for watch faces, not device apps or widgets. The simulator exposes no documented command-line or stable public control protocol for setting time. A minimal watch-face probe also left the menu disabled in an SDK 9.2.0 Linux session, so headless time changes are not verified in this configuration.

For deterministic device-app tests, inject a clock provider in application code or validate clock-dependent behavior on hardware. Changing the host timezone changes the simulator timezone, but is not a substitute for setting or accelerating simulated time.

The official SDK Manager itself could enter its GTK startup path under Xvfb, but the user-local test then failed because WebKitGTK tries to execute `/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/WebKitNetworkProcess` from a system path. A normal root-level installation of its Ubuntu 22.04-era dependencies would address that loader path, but a Garmin GUI login would still be required for official device and font downloads.
