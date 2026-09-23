# Set up local development

The automated setup is for Linux on x86_64. CI runs it on Ubuntu 24.04. It
installs the pinned Connect IQ SDK, supported watch definitions, simulator
fonts, and simulator runtime under `~/.Garmin/ConnectIQ`. The exact downloads
and checksums are in [`install-toolchain.sh`](../scripts/ci/install-toolchain.sh).

## Install the toolchain

From the repository root, run:

```bash
./scripts/ci/install-toolchain.sh
```

The installer uses `apt` when it has root access. Without root access, it
installs Java and simulator support in your home directory; `curl`, `jq`,
`openssl`, `tar`, `unzip`, and `sha256sum` must already be available. The first
run downloads a large font bundle. Later runs reuse verified files.

The device definitions and fonts come from pinned public mirrors of Garmin
SDK Manager data because Garmin's device download service requires a Garmin
login. The installer checks their hashes before use. The selected watch IDs
are in [`supported-devices.txt`](../supported-devices.txt).

## Set up a signing key

Builds need a PKCS#8 DER key. If you already publish this app, use the same
permanent developer key for Store updates. For local development, create a
key only if you do not already have one:

```bash
mkdir -p "${HOME}/.Garmin"
if [ -e "${HOME}/.Garmin/developer_key.pem" ] || \
   [ -e "${HOME}/.Garmin/developer_key.der" ]; then
  echo "An existing developer key is present; keep using it."
else
  umask 077
  openssl genrsa -out "${HOME}/.Garmin/developer_key.pem" 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER \
    -in "${HOME}/.Garmin/developer_key.pem" \
    -out "${HOME}/.Garmin/developer_key.der" -nocrypt
fi
```

Keep the private key out of Git. The build scripts use
`~/.Garmin/developer_key.der` by default; set `CIQ_DEVELOPER_KEY` to use a
different path. A Store update must use the same signing key as the existing
listing.

## Build and test

From the repository root:

```bash
./scripts/build.sh release
./scripts/build.sh test epix2pro47mm
./scripts/build.sh test fr255s
```

The release build writes `RingTracker.iq` for Store upload and one signed
`.prg` per supported watch to `bin/release/`. The test command starts a
headless simulator when needed. Build output in `bin/` is generated and is
ignored by Git.

For direct Garmin SDK commands or a manual simulator session, load the project
environment first:

```bash
source scripts/env.sh
monkeyc --version
ciq_headless_simulator
```

Run the simulator in one shell and use `monkeydo` in another. For the release
and Store workflow, see [PUBLISHING.md](PUBLISHING.md). For the current
published package, see the [latest GitHub release](https://github.com/BarishNamazov/garmin-ring-tracker/releases/latest).
