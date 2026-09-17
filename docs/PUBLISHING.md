# Publish Ring Tracker from GitHub

This procedure is for the repository owner. It creates public GitHub releases automatically from version tags; Connect IQ Store submission remains a manual, signed upload through Garmin's dashboard.

## Create the public repository

Create an empty public repository named `garmin-ring-tracker` under the `BarishNamazov` account. Do not add a README, license, or `.gitignore` in GitHub because this working tree already contains them. A personal account or organization can host it; standard GitHub-hosted runners are free for public repositories under [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions).

From the repository root, add the remote and publish the current `main` branch:

```bash
git remote add origin git@github.com:BarishNamazov/garmin-ring-tracker.git
git push -u origin main
```

Open [the Actions page](https://github.com/BarishNamazov/garmin-ring-tracker/actions/workflows/ci.yml) and verify that both CI jobs pass. Pull requests from forks do not receive repository secrets; CI deliberately generates a disposable developer key in that case.

## Create and protect the permanent developer key

Generate this key once. Every Connect IQ Store update must use the same key pair. If the private key is lost, Garmin cannot recover it and an update signed with a replacement key is rejected; publishing under a new listing is then the only route.

```bash
umask 077
mkdir -p "${HOME}/.Garmin"
openssl genrsa -out "${HOME}/.Garmin/developer_key.pem" 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in "${HOME}/.Garmin/developer_key.pem" \
  -out "${HOME}/.Garmin/developer_key.der" -nocrypt
openssl pkey -inform DER -in "${HOME}/.Garmin/developer_key.der" -noout
```

Garmin documents the same commands in its [Monkey C command-line setup](https://developer.garmin.com/connect-iq/reference-guides/monkey-c-command-line-setup/). Store the PEM and DER files in an encrypted backup separate from the development computer. Do not add either file or its base64 form to git.

Create a single-line base64 value and add it as the Actions repository secret `CIQ_DEVELOPER_KEY_B64`:

```bash
# GNU/Linux
base64 -w0 "${HOME}/.Garmin/developer_key.der" >developer_key.der.b64

# macOS
base64 <"${HOME}/.Garmin/developer_key.der" | tr -d '\n' >developer_key.der.b64

# With GitHub CLI authenticated for this repository
gh secret set CIQ_DEVELOPER_KEY_B64 <developer_key.der.b64
```

Delete the unencrypted `developer_key.der.b64` file after setting the secret. Keep the original DER file and its encrypted backup.

## Cut a GitHub release

1. Update the version in all three sources checked by `scripts/ci/check-version.sh`:

   - `manifest.xml`, in the application `version` attribute;
   - `resources/strings/strings.xml`, in `ProductVersion`;
   - the first version heading in `CHANGELOG.md`.

2. Put the release date and user-visible changes in that top CHANGELOG section, then verify consistency:

   ```bash
   ./scripts/ci/check-version.sh
   ```

3. Rebuild the tracked convenience bundle with the permanent key. This keeps `release/` current for source checkouts and satisfies the CI freshness job:

   ```bash
   CIQ_DEVELOPER_KEY="${HOME}/.Garmin/developer_key.der" ./scripts/build.sh release
   cp bin/release/RingTracker-*.prg bin/release/RingTracker.iq release/
   (cd release && sha256sum RingTracker-*.prg RingTracker.iq >SHA256SUMS)
   ./scripts/ci/check-release.sh bin/release
   ```

4. Commit the version, CHANGELOG, and refreshed `release/` files. Wait for CI to pass on that commit.

5. Tag that exact commit and push the tag. For version 1.2.0:

   ```bash
   git tag v1.2.0
   git push origin main
   git push --tags
   ```

The release workflow checks that `v1.2.0`, the manifest, the About text, and the top CHANGELOG entry all say `1.2.0`. It rebuilds and tests with the permanent key, then creates [a GitHub Release](https://github.com/BarishNamazov/garmin-ring-tracker/releases) containing three device-specific PRGs, `RingTracker.iq`, and `SHA256SUMS`. The matching CHANGELOG section becomes the release body. The workflow fails before publishing if the repository secret is missing or invalid.

The checked-in `release/RingTracker.iq` embeds paths from the computer that produced it in its debug maps. The `RingTracker.iq` attached to the GitHub Release is rebuilt on the GitHub runner and is the canonical Store-upload package. The tracked copy remains a convenience artifact and should not be submitted when the corresponding GitHub Release asset is available.

## Install a GitHub release

Users download the `.prg` matching their 42, 47, or 51 mm epix Pro and verify it against `SHA256SUMS`. Link them to [INSTALL.md](INSTALL.md) for device identification, MTP transfer instructions, first-run setup, and troubleshooting. `RingTracker.iq` is not installed over USB.

## Publish manually to the Connect IQ Store

GitHub Actions cannot complete Store publication because Garmin requires an interactive developer account and dashboard submission. Sign up for the Connect IQ developer program and open the [developer dashboard](https://apps.garmin.com/developer/dashboard). Garmin's [submission guide](https://developer.garmin.com/connect-iq/submit-an-app/) requires an exported `.iq` containing every supported product; use the canonical `RingTracker.iq` from the GitHub Release.

### Private beta for the owner's watch

Use the beta route when the owner needs phone-side App Settings before public review:

1. Sign in with the same Garmin account used by the phone and watch.
2. Create a beta submission. If a separate beta and production listing must coexist, give the beta an alternate application UUID before building it, as described in [INSTALL.md](INSTALL.md#if-phone-managed-settings-are-required).
3. Upload the GitHub Release's `RingTracker.iq`, let the dashboard validate it, and open the beta installation link on the paired phone.
4. Install and sync through the Connect IQ Store app, then verify Ring Tracker's App Settings page.

Garmin beta links are account-bound; they are suitable for the submitting owner's devices, not general unlisted distribution. USB sideloading remains the route for users who do not need phone-managed settings.

### Public Store review

For a public listing, complete the dashboard metadata and submit it for review. Garmin's [submission guide](https://developer.garmin.com/connect-iq/submit-an-app/) says the package is validated first, after which the owner supplies the description and screenshots; the app stays hidden while approval is pending. Before submission:

- Confirm that the manifest lists exactly the three supported products and that each build was tested.
- Provide an accurate description, support contact, category, compatible-device statement, and the health disclaimer. Do not imply Garmin endorsement.
- Upload clear screenshots for the supported round displays. The native-resolution images under `docs/screenshots/` are the starting set.
- Supply a 500 × 500 sRGB Store icon with 10 px of padding, a solid non-black/non-transparent background, no descriptive text, and no Garmin branding. These are Garmin's current [Connect IQ brand and Store-asset rules](https://developer.garmin.com/brand-guidelines/connect-iq/).
- Answer the dashboard's data and privacy questions accurately. Ring Tracker keeps schedule data locally and declares no network permission. If the app later collects user data, Garmin's [developer agreement](https://developer.garmin.com/connect-iq/sdk/) requires a compliant privacy policy and appropriate retention and consent behavior.
- Review the current [Connect IQ app review guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/) immediately before submitting because Garmin can revise them.

After upload, preview and install the pending version on the owner's watch. Garmin reviews the submission; it becomes searchable and installable by other users only after approval.


### Submission record

Version 1.1.0 was submitted to the Connect IQ Store on 2026-09-16 under the developer name BarishNamazov. Store app ID: `5347b9a1-5dd1-4e0a-93bd-b5dcf2a1ef4f` (listing: <https://apps.garmin.com/apps/5347b9a1-5dd1-4e0a-93bd-b5dcf2a1ef4f>). The upload validator reported `Status: Verified` alongside an informational `Signature check failed.` line and accepted the package; the listing stays hidden until Garmin approves it. Later versions must be signed with the same developer key.

## Toolchain cache and pin updates

Both workflows cache `~/.Garmin` with a key containing the operating system, SDK version, device-archive commit, and `hashFiles('scripts/ci/install-toolchain.sh')`. On a cache hit, the installer still verifies the expected layout and installs any system packages needed by the fresh runner, but it does not re-download valid cached SDK, device, font, or fallback-JDK payloads.

To update a pin:

1. For the SDK, select the Linux filename from Garmin's public [`sdks.json`](https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json), download it, calculate `sha256sum`, and update `sdk_version`, `sdk_archive`, and `sdk_sha256` in `scripts/ci/install-toolchain.sh`.
2. For device definitions, inspect a fixed `blackshadev/garmin-connectiq-tools` commit, download its `devices.tar.gz`, calculate `sha256sum`, and update `device_commit` and `device_sha256`.
3. If the device definitions reference different fonts, update the pinned tester image and `font_layer` digest. The installer derives the exact CFT/TTF allow-list from the three `simulator.json` files.
4. Update the readable SDK and commit components in both workflow cache keys.
5. Run the installer in a new temporary home, then run release and simulator tests before pushing:

   ```bash
   clean_home="$(mktemp -d)"
   HOME="${clean_home}" ./scripts/ci/install-toolchain.sh
   openssl genrsa -out "${clean_home}/test-key.pem" 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER \
     -in "${clean_home}/test-key.pem" -out "${clean_home}/test-key.der" -nocrypt
   HOME="${clean_home}" CIQ_DEVELOPER_KEY="${clean_home}/test-key.der" ./scripts/build.sh release
   HOME="${clean_home}" CIQ_DEVELOPER_KEY="${clean_home}/test-key.der" ./scripts/build.sh test
   ```

Do not point cache keys at an unverified moving archive.
