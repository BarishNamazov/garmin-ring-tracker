# Submit Ring Tracker 1.1.0 to the Connect IQ Store

This procedure reflects Garmin's current dashboard and documentation as checked on 2026-09-16. Use the public v1.1.0 Store package for the production listing. A beta that must coexist with production needs a separate package built with an alternate application UUID.

## Pre-flight

- Sign in to Garmin with the account that owns the developer profile. For beta installation and App Settings testing, this must also be the Garmin account paired with the watch.
- Confirm that the developer profile has a unique **Developer Name** and a monitored public support email address. Garmin requires the email in Step 2 and displays it publicly.
- For the public listing, download **`RingTracker.iq` from the v1.1.0 GitHub Release**, not the similarly named tracked file under `release/` and not a device-specific `.prg`:
  - Asset: <https://github.com/BarishNamazov/garmin-ring-tracker/releases/download/v1.1.0/RingTracker.iq>
  - Release page: <https://github.com/BarishNamazov/garmin-ring-tracker/releases/tag/v1.1.0>
  - Size: 392,294 bytes
  - SHA-256: `1795944035c08b4dc9d145a01df316168dddfa46df4789a7634073d2d942d429`
- Verify the downloaded asset against the release's `SHA256SUMS`. The checked-in `release/RingTracker.iq` is a convenience artifact from a different build environment and has a different checksum; do not substitute it when the GitHub Release asset is available.
- Confirm the production package uses application UUID `99f92e0c-a120-4641-b832-6da4d958585b`, version `1.1.0`, and the same permanent developer signing key intended for future updates.
- Confirm the manifest contains exactly `epix2pro42mm`, `epix2pro47mm`, and `epix2pro51mm`, and that all three builds have been tested.
- Prepare the Step 2 assets and copy from [`listing.md`](listing.md):
  - `icon-500.png`, under 300 KB;
  - screenshots `01` through `05`, each under 150 KB;
  - English title, description, What's New text, Medical category, Source Code URL, and privacy answer;
  - a monitored public developer email address.
- Answer **No** to ANT+ profiles, **No** to regional limits unless release policy changes, **No** to user-data collection, and **No** to monetization/payment questions. Ring Tracker has no companion app, additional hardware, or preview video.
- Choose whether to enable **Review Notification**. **App Migration** means allowing the Store to add newly compatible devices; leave it **No** unless those automatically added devices will be tested and supported.
- Review the medical scheduling language against [`../REGIMEN.md`](../REGIMEN.md) and keep the disclaimer verbatim.

## Upload a developer-account beta

Garmin beta apps are visible and downloadable only to the submitting account. A beta link is not an unlisted distribution link for outside testers.

1. Before exporting, replace the application UUID in `manifest.xml` with a newly generated **beta-only UUID**. Keep the production UUID above reserved for the public package. Export a complete v1.1.0 `.iq` with all three device binaries and the permanent developer signing key.
2. Open [Connect IQ Developer Dashboard](https://apps-developer.garmin.com/en-US/developer/dashboard).
3. Select **Uploaded Apps**, then **Upload an App**.
4. In **Step 1: Attach File**:
   1. Select the beta-specific `.iq` under **File Path**.
   2. Enter `1.1.0` under **App Version**.
   3. Select **Beta App**.
   4. Select **Continue** and wait for package validation.
5. In **Step 2: Enter Details**, fill the fields from [`listing.md`](listing.md), upload the cover image and screenshots `01`–`05`, and select **Submit**.
6. Open the beta from the dashboard's **Beta Apps** section. Open its installation URL on the phone signed in to the same Garmin account, then hand the link to the Connect IQ Store mobile app.
7. Install and sync to an epix Pro (Gen 2). Verify that the app launches and that **Ring Tracker > App Settings** is available in the mobile app.
8. Update the beta as often as needed using the beta listing. Do not reuse its beta UUID for the public listing.

If the unmodified public GitHub Release asset is uploaded as a beta, its embedded production UUID becomes associated with that beta listing. Garmin's beta documentation requires a different app ID for the later public upload. Therefore, use the canonical GitHub Release asset for public submission and an alternate-UUID rebuild for a coexisting beta.

## Submit the public listing

1. Download and verify the canonical v1.1.0 `RingTracker.iq` GitHub Release asset listed in Pre-flight. Do not modify the archive after export; Garmin warns that modified packages can fail signature validation.
2. Open [Connect IQ Developer Dashboard](https://apps-developer.garmin.com/en-US/developer/dashboard).
3. Select **Uploaded Apps**, then **Upload an App**.
4. In **Step 1: Attach File**:
   1. Select the canonical `RingTracker.iq` under **File Path**.
   2. Enter `1.1.0` under **App Version**.
   3. Leave **Beta App** clear.
   4. Select **Continue** and wait for package validation.
5. In **Step 2: Enter Details**:
   1. Add English and paste the title, description, and What's New text from [`listing.md`](listing.md).
   2. Leave **Hero Image** empty unless a compliant localized 1440×720 image is later prepared.
   3. Select **Medical** under Category.
   4. Answer **No** to **Does your app collect user data?** The Privacy Policy URL field should remain hidden.
   5. Answer **No** to ANT+ profiles and regional limits.
   6. Upload `icon-500.png` as **Cover Image (Web/Mobile)**. Answer **No** to optional App Store on Device icons unless separate 128×128 assets are prepared.
   7. Upload screenshots `01-main-ring-in.png` through `05-ring-out.png` in numeric order. The current dashboard accepts at most five; files `06`–`08` are alternates.
   8. Enter the monitored public developer email and the GitHub repository as **Source Code URL**.
   9. Leave companion app, hardware Product URL, and Preview Video empty.
   10. Answer the Review Notification, App Migration, and monetization questions as decided in Pre-flight.
6. Select **Submit**.
7. Open the pending app preview from **Uploaded Apps**. Check the title, paragraph breaks, disclaimer, five-image order, Medical category, compatibility list, permissions, support/source links, and version.
8. Download and install the pending version on a supported watch. Verify first run, main ring-in/ring-free states, Upcoming, glance, local reminders, History, on-watch settings, and phone App Settings before waiting for approval.
9. The app remains hidden during review. Garmin's current dashboard says initial approval can take up to three days; use the rejection email and dashboard status to correct and resubmit if necessary.

## Current upload constraints

| Field | Current constraint |
| --- | --- |
| App Version | Required; maximum 20 characters |
| Title | Required per language; maximum 50 characters |
| Description | Required per language; maximum 4,000 characters; no emoji |
| What's New | Optional per language; maximum 4,000 characters; no emoji |
| Hero Image | Optional per language; JPG/GIF/PNG; exactly 1440×720; less than 2,048 KB |
| Category | Required; subcategory required only when the selected category has children |
| User-data collection | Required Yes/No; a valid Privacy Policy URL is required only for Yes |
| Cover Image | Required by the submission model; JPG/GIF/PNG; 500×500 label; less than 300 KB; Garmin brand rules additionally require sRGB and at least 10 px padding |
| Screen Images | At least 1 and at most 5; JPG/GIF/PNG; each less than 150 KB; no published pixel dimensions or bezel rule |
| Developer email | Required and publicly displayed |
| Source Code URL | Optional; must be a valid URL |
| Hero/banner | The optional 1440×720 Hero Image is the only current banner-like listing field found |
| Tagline, keywords, Support URL | No separate fields found in the current rendered form |

Garmin's public documentation does not enumerate every current dashboard field, screenshot dimension, or bezel rule. The table combines the current official dashboard labels and visible client-side validation with Garmin's public submission, beta, brand, and review guidance. Recheck the authenticated form immediately before the final click because Garmin can change these requirements.

## Official references

- [Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Publishing to the Connect IQ Store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/)
- [Beta Apps](https://developer.garmin.com/connect-iq/core-topics/beta-apps/)
- [Connect IQ brand guidelines](https://developer.garmin.com/brand-guidelines/connect-iq/)
- [Connect IQ App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Current dashboard field text](https://apps-developer.garmin.com/locales/en-US/upload.json)
- [Current Store category strings](https://apps-developer.garmin.com/locales/en-US/appCategories.json)
