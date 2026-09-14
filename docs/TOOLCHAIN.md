# Build an Epix Pro (Gen 2) device app from the command line

This machine can compile signed Garmin Connect IQ device apps for `epix2pro42mm`, `epix2pro47mm`, and `epix2pro51mm` with Connect IQ SDK 9.2.0. The setup is headless and stores the SDK and device definitions outside this repository.

## Installed toolchain

| Component | Version or value | Path |
| --- | --- | --- |
| Connect IQ SDK | 9.2.0 | `/home/agent/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2` |
| Active SDK pointer | SDK path above | `/home/agent/.Garmin/ConnectIQ/current-sdk.cfg` |
| Java | Eclipse Temurin OpenJDK 17.0.20.1+1 | `/home/agent/.local/jdks/temurin-17` |
| Device definitions | Snapshot from 2026-08-08 | `/home/agent/.Garmin/ConnectIQ/Devices` |
| RSA signing key | 4096-bit PKCS#8 DER | `/home/agent/.Garmin/developer_key.der` |

The SDK was selected from Garmin's [`sdks.json`](https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json). Its Linux archive is `connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2.zip`, SHA-256 `4907d8455b651c5a00a865e364cc4f1921c055b9279c7c8634c7a7a6773b5593`.

System `sudo` is blocked by a `no_new_privileges` policy in this environment, despite the account configuration described for this machine. Apt therefore could not install OpenJDK. The installed replacement is the current OpenJDK 17 build from the [Adoptium binary API](https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse); this satisfies `monkeyc`'s Java requirement. The downloaded JDK archive had SHA-256 `3808d1d15e3ec6bd5b84057fb5d84c33d8a1536a258146bcea2e603fc726e08e`.

## Shell environment

Source the checked-in environment file before invoking the SDK tools:

```bash
source /home/agent/Dev/garmin-bc/scripts/env.sh
java -version
monkeyc --version
```

The observed compiler version is `Connect IQ Compiler version: 9.2.0`. The environment file exports `JAVA_HOME`, `CIQ_SDK_HOME`, `CIQ_DEVICE_HOME`, `CIQ_DEVELOPER_KEY`, and `CIQ_SIM_RUNTIME`; it adds Java, Connect IQ, and the optional user-local simulator support tools to `PATH`.

Garmin's documented minimal SDK-only PATH setup is:

```bash
export PATH="${PATH}:$(cat /home/agent/.Garmin/ConnectIQ/current-sdk.cfg)/bin"
```

## Device definitions

Garmin's current device service at `https://api.gcs.garmin.com/ciq-product-onboarding/devices?sdkManagerVersion=1.0.5` returned HTTP 401 without a Garmin session. Plausible static device-index and per-device URLs under `https://developer.garmin.com/downloads/connect-iq/` returned HTTP 404. The official SDK Manager is a GUI executable: passing `--help` did not expose a device-download CLI. It can start under Xvfb once its legacy libraries are present, but login and device download still require the GUI and a Garmin account.

The community [`connect-iq-sdk-manager-cli`](https://github.com/lindell/connect-iq-sdk-manager-cli) provides headless SDK and device commands, but its device list and download commands use the same authenticated Garmin service. It therefore does not remove the account requirement.

The installed definitions instead came from the public [`blackshadev/garmin-connectiq-tools`](https://github.com/blackshadev/garmin-connectiq-tools) device archive pinned at commit [`cd073d7fc4083edf75eb3e1068d7ee4087c19423`](https://github.com/blackshadev/garmin-connectiq-tools/commit/cd073d7fc4083edf75eb3e1068d7ee4087c19423), dated 2026-08-08. That project's update script archives locally installed SDK Manager device directories. Archive SHA-256: `329ebb68bf55a07d86cda993a1381b20f7fc786eba059737abbf1d72778d2feb`.

Only these archive directories were extracted:

```text
/home/agent/.Garmin/ConnectIQ/Devices/epix2pro42mm  (67 files)
/home/agent/.Garmin/ConnectIQ/Devices/epix2pro47mm  (67 files)
/home/agent/.Garmin/ConnectIQ/Devices/epix2pro51mm  (77 files)
```

Each directory includes `compiler.json`, `simulator.json`, the compiled device API data, device image, personality stylesheet, icons, and other device resources required by `monkeyc`. The archive does not include the SDK Manager's separately downloaded system font files. This does not prevent compilation, but it affects simulator apps that call a device system font; see [Headless simulator result](#headless-simulator-result).

Exact `compiler.json` snapshots are checked in for reference:

- [`epix2pro42mm.compiler.json`](devices/epix2pro42mm.compiler.json)
- [`epix2pro47mm.compiler.json`](devices/epix2pro47mm.compiler.json)
- [`epix2pro51mm.compiler.json`](devices/epix2pro51mm.compiler.json)

## Device display and memory limits

The shape comes from each `simulator.json`. Resolution, API level, program file limit, and app memory limits come from each `compiler.json`.

| Device ID | Display name | Shape | Resolution | API level | Maximum PRG size |
| --- | --- | --- | --- | --- | --- |
| `epix2pro42mm` | epix Pro (Gen 2) 42mm | Round AMOLED | 390 × 390 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |
| `epix2pro47mm` | epix Pro (Gen 2) 47mm / quatix 7 Pro | Round AMOLED | 416 × 416 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |
| `epix2pro51mm` | epix Pro (Gen 2) 51mm / D2 Mach 1 Pro / tactix 7 AMOLED Edition | Round AMOLED | 454 × 454 | 5.2 / Connect IQ 5.2.0 | 67,108,864 bytes (64 MiB) |

All three compiler definitions specify the same app-type memory limits:

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
openssl genrsa -out /home/agent/.Garmin/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in /home/agent/.Garmin/developer_key.pem \
  -out /home/agent/.Garmin/developer_key.der -nocrypt
```

Both key files have mode `0600`. Do not commit either key.

## Verified hello-world build

The temporary test project is `/tmp/ciqhello`. It is a `watch-app` with `minSdkVersion="5.2.0"` and all three product IDs in `manifest.xml`. Its display spells `HELLO` using an app-owned SVG bitmap resource so that the headless simulator does not depend on the missing Garmin system-font bundle.

This exact requested command succeeded without warnings or errors:

```bash
source /home/agent/Dev/garmin-bc/scripts/env.sh
cd /tmp/ciqhello
monkeyc -d epix2pro47mm -f monkey.jungle -o bin/hello.prg \
  -y ~/.Garmin/developer_key.der -w
```

Observed result:

```text
BUILD SUCCESSFUL
/tmp/ciqhello/bin/hello.prg
SHA-256 8df660995cabcf2d0fe0550b8fd778920b4ff8277dfaa9752ee9ef18ce9c83b1
```

The same project also built successfully for the other family members:

```bash
monkeyc -d epix2pro42mm -f monkey.jungle \
  -o bin/hello-epix2pro42mm.prg -y ~/.Garmin/developer_key.der -w
monkeyc -d epix2pro51mm -f monkey.jungle \
  -o bin/hello-epix2pro51mm.prg -y ~/.Garmin/developer_key.der -w
```

## Headless simulator result

The SDK 9.2.0 simulator links against libraries removed from Ubuntu 24.04, including WebKitGTK 4.0 and libsoup 2.4. Because system apt installation was unavailable, the required Ubuntu packages were extracted under `/home/agent/.local/opt/ciq-runtime`. Xvfb 21.1.12 was extracted from Ubuntu 24.04 packages. The legacy WebKitGTK 4.0 runtime was extracted from Ubuntu 22.04 packages. A user-local Xvfb copy under `/home/agent/.local/opt/ciq-runtime-patched-bin` redirects its compiled-in `/usr/bin/xkbcomp` lookup to `/tmp/ciq/xkbcomp`.

After sourcing `scripts/env.sh`, start the simulator with the helper function and launch the app from a second shell:

```bash
# First shell
source /home/agent/Dev/garmin-bc/scripts/env.sh
ciq_headless_simulator

# Second shell
source /home/agent/Dev/garmin-bc/scripts/env.sh
monkeydo /tmp/ciqhello/bin/hello.prg epix2pro47mm
```

`connectiq` remained running under Xvfb. `monkeydo` loaded the 47 mm PRG, selected part number `006-B4313-00`, and remained attached until manually stopped. The simulator reported Connect IQ API 5.2.0 and runtime version 6.0.2.

An initial build that used `Graphics.FONT_MEDIUM` loaded but crashed with `Invalid Font Specified`, confirming that the public device archive lacks separately downloaded Garmin system fonts. The final app-owned SVG build ran without that error. Xvfb emits non-fatal warnings for several unresolved `XF86*` key symbols.

The official SDK Manager itself could enter its GTK startup path under Xvfb, but the user-local test then failed because WebKitGTK tries to execute `/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/WebKitNetworkProcess` from a system path. A normal root-level installation of its Ubuntu 22.04-era dependencies would address that loader path, but a Garmin GUI login would still be required for official device and font downloads.
