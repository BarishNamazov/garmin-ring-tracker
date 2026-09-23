# Upload Ring Tracker 1.3.2 to Garmin

Use the signed package from the [v1.3.2 GitHub Release](https://github.com/BarishNamazov/garmin-ring-tracker/releases/tag/v1.3.2) to update the existing Ring Tracker listing. Garmin submission and physical-watch verification remain manual.

## Files to prepare

| File | Purpose |
| --- | --- |
| `RingTracker.iq` | Upload this package to Garmin; it contains all supported device builds |
| `SHA256SUMS` | Verify the downloaded package before upload |
| [listing.md](listing.md) | Description and 1.3.2 What's New text |

Download the files attached to the release. The repository's `release/` directory is a local convenience build; use the GitHub release package for submission. The device-specific `.prg` files are for USB sideloading, not Store upload.

To verify the package on Linux:

```bash
sha256sum RingTracker.iq
```

Compare the result with the `RingTracker.iq` line in the downloaded `SHA256SUMS`. On macOS use `shasum -a 256 RingTracker.iq`; on Windows use `Get-FileHash RingTracker.iq -Algorithm SHA256` in PowerShell.

## Update the existing listing

1. Sign in to the [Connect IQ developer dashboard](https://apps-developer.garmin.com/en-US/developer/dashboard) with the account that owns Ring Tracker.
2. Open the existing listing, Store app ID `5347b9a1-5dd1-4e0a-93bd-b5dcf2a1ef4f`, and select its update/upload-version action. Keep the existing production listing and application identity.
3. Upload `RingTracker.iq` and enter version **1.3.2**. Wait for package validation.
4. Paste the What's New text from [listing.md](listing.md). Refresh the description from the same file if needed.
5. Keep the existing screenshots and icon. Their source files are in [screenshots/](screenshots/) and [icon-500.png](icon-500.png) if a refresh is needed.
6. Keep the existing support details and category. The app still uses local storage and declares Background and Notifications permissions, with no network permission; its data-collection answer remains **No**.
7. Preview the version, copy, image order, and compatibility list, then submit the update.
8. Install the pending version on a supported watch. Check existing schedule/history preservation, Main, Upcoming, History, glance, on-watch and phone settings, and notification delivery. Local and CI simulator checks do not replace this hardware check.

The production application UUID remains `99f92e0c-a120-4641-b832-6da4d958585b`. The package uses the existing permanent signing key and supports `epix2pro42mm`, `epix2pro47mm`, and `epix2pro51mm`. A separate beta listing would need its own application UUID; the production release is intended for the existing public listing.

Garmin controls package validation and review. Its [submission guide](https://developer.garmin.com/connect-iq/submit-an-app/) explains the `.iq` upload and pending-version preview/install process. Dashboard labels may vary; this release has not been submitted automatically.
