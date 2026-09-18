# Install and set up Ring Tracker on an epix Pro (Gen 2)

This guide is for the 42, 47, and 51 mm Garmin epix Pro (Gen 2). It explains how
to install a device-specific `.prg` file without the Connect IQ Store, complete
the first-run setup, add the glance, and troubleshoot reminders.

> **Health disclaimer:** Ring Tracker records dates and shows reminders. It does
> not determine whether contraception is effective and is not a substitute for
> the product label or advice from a qualified clinician. Read the in-app
> safety text before use. Ring Tracker v1.3.0 is for NuvaRing only. See [the
> regimen and source notes](REGIMEN.md).

Information and menu names were checked on 17 September 2026. Garmin sometimes
renames a menu in firmware updates; the route should remain similar.

## Choose the right installation method

For a private installation on one watch, use USB sideloading and configure the
app entirely on the watch. This is the simplest and most private route.

| Method | Who can install it? | Phone/desktop App Settings | Updates |
| --- | --- | --- | --- |
| USB sideload | Anyone given the exact `.prg` for their watch | **No**; use the app's on-watch Settings menu | Copy a new `.prg` manually |
| Connect IQ beta | Only the Garmin account that submitted the beta | Yes | Through Connect IQ |
| Public Connect IQ Store | Any compatible user after Garmin review | Yes | Through Connect IQ |

The App Settings limitation is not a phone-pairing problem. Garmin states that
App Settings depend on an app's Connect IQ Store association, and sideloading
never creates that association. Consequently, neither the Connect IQ Store
phone app, Garmin Connect, nor Garmin Express can edit settings for a pure
sideload. Garmin recommends testing settings while an app is in Store beta or
pending review. See Garmin's [New Developer FAQ, “I have side-loaded an app ...
but app settings won't work”](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq).

Ring Tracker includes a full Settings screen on the watch, so sideload users do
not need mobile App Settings.

## Before installing: choose the exact build

A `.prg` is compiled for one Connect IQ product. Renaming it does not make it
compatible with another model or size. Use this table:

| Watch | Connect IQ device ID | Display | Internal part number |
| --- | --- | ---: | --- |
| epix Pro (Gen 2), 42 mm | `epix2pro42mm` | 390 × 390 | `006-B4312-00` |
| epix Pro (Gen 2), 47 mm | `epix2pro47mm` | 416 × 416 | `006-B4313-00` |
| epix Pro (Gen 2), 51 mm | `epix2pro51mm` | 454 × 454 | `006-B4314-00` |

Garmin publishes separate product definitions for the
[42 mm](https://developer.garmin.com/connect-iq/device-reference/epix2pro42mm/),
[47 mm](https://developer.garmin.com/connect-iq/device-reference/epix2pro47mm/),
and [51 mm](https://developer.garmin.com/connect-iq/device-reference/epix2pro51mm/)
models. The non-Pro epix (Gen 2), fēnix, and other watches are different targets.

To identify the size, check the product name on the original order or box, or
measure the case across its body, excluding the buttons. Garmin sold the Pro in
[42, 47, and 51 mm case sizes](https://www.garmin.com/en-US/newsroom/press-release/outdoor/conquer-every-day-and-every-adventure-with-epix-pro-series-from-garmin/).
The watch's **System > About** page reliably reports its unit ID and software
information, but may not spell out the case size; Garmin documents those About
fields in the [epix owner's manual](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-US/epix_%28Gen_2%29_Series_OM_EN-US.pdf).
As a technical fallback, open `GARMIN/GarminDevice.xml` over USB, locate its
`PartNumber`, and match it to the table above.

Only install a `.prg` obtained from a developer you trust. The file should have
been signed with a Connect IQ developer key. Garmin's compiler requires the
developer-key option when producing a device binary; see the
[`monkeyc` compiler options](https://developer.garmin.com/connect-iq/monkey-c/compiler-options/).
A correctly signed, device-matched sideload runs without Store review. The watch
verifies Connect IQ apps after transfer; there is no Android-style “unknown
source” approval in Garmin's documented sideload flow. Some firmware versions
briefly show **Verifying Connect IQ Apps** during that step, as reported in the
[Garmin developer forum](https://forums.garmin.com/developer/connect-iq/f/discussion/281915/sign-app-for-sideloading).

## Connect the watch correctly

The epix Pro (Gen 2) exposes its files using **MTP (Media Transfer Protocol)**,
not as a USB mass-storage disk. Garmin lists all epix Pro (Gen 2) variants among
its [MTP devices](https://support.garmin.com/en-US/?faq=CZqibgTHMb0dAYEaj2UiU7).
It may therefore appear as a portable device rather than with a drive letter.

On the watch:

1. Hold **MENU**.
2. Open **System > USB Mode**.
3. Select **MTP**. If the mode is **Garmin**, choose **Use MTP** when the watch
   asks after connection.
4. Connect with a USB **data** cable, directly to the computer where possible.

Only one desktop program can own an MTP connection at a time. Fully quit Garmin
Express, BaseCamp, OpenMTP, Android File Transfer, and file-manager windows not
used for the current transfer. Garmin calls out this single-application limit
in its [MTP support article](https://support.garmin.com/en-US/?faq=CZqibgTHMb0dAYEaj2UiU7).

The canonical destination in Garmin's developer instructions is
`/GARMIN/APPS/` in the watch's internal storage. Some MTP clients display the
existing directory as `GARMIN/Apps`; follow the existing directory rather than
creating a second folder that differs only by case. Copy the `.prg`, not the
Store-upload `.iq` package.

## Install from Windows

Windows includes an MTP client in File Explorer.

1. Download the `.prg` built for your exact size and note where it was saved.
2. Quit Garmin Express and BaseCamp so File Explorer can use the watch.
3. Connect the watch in MTP mode as described above.
4. Open **File Explorer > This PC**. Open the epix Pro portable device, then its
   **Internal Storage**.
5. Open the existing **GARMIN > APPS** directory.
6. Copy the `.prg` into **APPS**. Wait for the copy operation to finish.
7. Close the device window. Use **Eject** if Windows offers it, then unplug the
   cable.

Garmin's official sequence is to build for the selected target, copy the PRG to
`/GARMIN/APPS`, and disconnect; the app should then be available. See the
[official sideload instructions](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq).

## Install from macOS

Finder does not provide general file browsing for this watch. Garmin says its
MTP devices require Windows for supported file access because macOS has limited
MTP support; the [epix manual](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-US/epix_%28Gen_2%29_Series_OM_EN-US.pdf)
and [MTP support article](https://support.garmin.com/en-US/?faq=CZqibgTHMb0dAYEaj2UiU7)
state that limitation. In practice, owners use a third-party MTP client. This is
not an officially supported Garmin file-transfer path.

The practical current choice is [OpenMTP](https://openmtp.ganeshrvel.com/), an
open-source MTP client that specifically lists Garmin support. Its project
documents support for Intel and Apple Silicon Macs and installation with
Homebrew in the [OpenMTP repository](https://github.com/ganeshrvel/openmtp).

1. Install OpenMTP from its signed download, or run:

   ```bash
   brew install openmtp --cask
   ```

2. **Completely quit** Garmin Express and BaseCamp, including menu-bar/background
   instances. Also quit Android File Transfer if it is present.
3. Connect the watch in MTP mode and open OpenMTP.
4. Select the Garmin device and its internal storage.
5. Open the existing **GARMIN > APPS** directory and drag in the correct `.prg`.
6. Wait until OpenMTP reports that the transfer is complete, close the MTP
   connection, and unplug the watch.

Android File Transfer was a common older workaround, and Garmin forum users
confirmed it worked only when Garmin Express was not competing for the MTP
connection. Google stopped distributing Android File Transfer in 2024, so do
not download an old copy from an untrusted mirror. Current epix Pro owners report
OpenMTP as the replacement in this
[model-specific Garmin forum thread](https://forums.garmin.com/outdoor-recreation/outdoor-recreation/f/epix-2/378981/unable-to-upload-activity-or-manually-connect-my-watch-to-my-mac).

Garmin Express can sync and manage supported Connect IQ content, but it is not a
general-purpose MTP file browser. Quit it while using OpenMTP. It also does not
restore App Settings for a sideloaded app; that still requires a Store-linked
installation.

## Install from Linux

Garmin does not provide a supported Linux desktop workflow for this MTP device.
The following community-standard MTP methods normally work, but desktop and
package names vary by distribution.

### GNOME Files / GVFS

1. Install the distribution's MTP backend, usually `gvfs-mtp` or
   `gvfs-backends`, plus `libmtp` if it is packaged separately.
2. Quit any other MTP client. Connect the watch in MTP mode.
3. Open **Files** (Nautilus) and select the Garmin device in the sidebar.
4. Open internal storage, then the existing **GARMIN > APPS** directory.
5. Copy the device-specific `.prg` into **APPS** and wait for completion.
6. Eject/unmount the Garmin device from Files before unplugging it.

GNOME's virtual filesystem exposes MTP locations through its `mtp://` backend;
see the [GVfs scheme documentation](https://wiki.gnome.org/Projects/gvfs/schemes.html).

### `jmtpfs` fallback

Install `jmtpfs` and FUSE using your distribution's package manager, then run
the following from an empty working directory. Do not use `sudo` for the mount.

```bash
mkdir epix-mtp
jmtpfs epix-mtp
find epix-mtp -maxdepth 5 -type d -iname apps
cp /path/to/RingTracker.prg "epix-mtp/path/reported/by/find/APPS/"
fusermount -u epix-mtp
rmdir epix-mtp
```

Replace the quoted destination with the actual path printed by `find`; MTP
storage names differ between clients. If mounting fails with “device busy,”
unmount or close GNOME Files first. `jmtpfs` is a FUSE filesystem backed by
`libmtp`; its mount and unmount syntax is documented in the
[`jmtpfs` manual](https://manpages.ubuntu.com/manpages/jammy/man1/jmtpfs.1.html)
and [Debian MTP guide](https://wiki.debian.org/mtp).

## What happens after disconnecting

No manual restart is normally required. After the USB/MTP connection closes,
the watch verifies and ingests the PRG; wait until it returns to its normal watch
face before trying to open the app. Garmin's instructions say the app should be
available after disconnecting, without a separate reboot step.

On newer Garmin firmware, the copied `.prg` may disappear from the visible
`GARMIN/APPS` directory after a successful disconnect. Garmin forum moderators
explain that current devices move installed PRGs into hidden storage, so the
disappearance does **not** mean the copy failed. Do not repeatedly copy the same
file solely because it is no longer visible; see the
[Garmin developer discussion of hidden PRGs](https://forums.garmin.com/developer/connect-iq/f/discussion/391547/where-do-the-app-prg-files-go-now-on-the-devices).

## Open Ring Tracker and add its glance

### Open the full app

1. From the watch face, press **START** (upper-right button).
2. Scroll or swipe to **Ring Tracker** in **Activities & Apps**.
3. Press **START** again or tap the name.

These are the epix's documented controls: **START** opens the activity/app list,
**UP/DOWN** or touch moves through lists and glances, **BACK** returns, and
holding **LIGHT** opens Controls. See Garmin's
[Using the Watch guide](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-US/GUID-0102B2DF-D808-474D-9F45-57D15C42C640.html).

To move Ring Tracker higher in the app list, hold **MENU**, open **Activities &
Apps**, select **Ring Tracker > Reorder**, and move it with **UP/DOWN**. Garmin
documents that route in
[Changing the Order of an Activity in the Apps List](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-GB/GUID-2B7CD712-3EAA-4A09-B289-CA9BB278DEBD.html).

### Add the glance

1. Hold **MENU**.
2. Open **Appearance > Glances > Add**.
3. Select **Ring Tracker**.
4. Return to the watch face. Press **UP/DOWN** or swipe to find the new glance.
5. Press **START** or tap it to open the full app.

This is Garmin's documented [glance-loop customization
flow](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-US/GUID-61C825F5-5D80-413F-BA3F-CD8C51BB63F2.html).
The Ring Tracker glance shows a one-line status such as **Remove in 5 days**
and a miniature cycle-progress bar.

Ring Tracker is a watch app with a glance; it is **not** a Controls app. Holding
**LIGHT** opens Garmin's Controls menu, but no separate Ring Tracker control is
expected there. Garmin documents Controls separately in
[Customizing the Controls Menu](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-GB/GUID-3A355D29-6245-4C45-A727-4CE60B3F9313.html).

## First-run walkthrough

Have the actual insertion date and time available before starting. If uncertain,
do not guess for contraceptive decisions; check the product instructions or ask
a qualified clinician.

1. **Read the safety text.** Scroll through it, then choose **I understand**. The
   app will not start reminders before that acknowledgement.
2. **Confirm the schedule.** The default is 21 days in and 7 days out for
   NuvaRing. Change it only to match instructions from a clinician.
3. **Set the insertion time.** Choose **Insert now** only if it just happened.
   Otherwise choose **Choose date & time**. Select day, short month, and year,
   then select the hour and minute in separate columns. In 12-hour mode, select
   AM or PM as the final column. Review the summary and confirm it.
4. **Review the main screen.** The outer arc shows the configured cycle. The
   center identifies **RING IN** or **RING FREE** with the next-action countdown
   and date. Overdue states say **REMOVE NOW** or **INSERT NOW** and show
   elapsed lateness; extended wear says **REPLACE NOW**.
5. **Set reminders.** From the main screen, hold **MENU**, open **Settings**, and
   set **Reminder 1**, optional **Reminder 2**, **Day before**,
   **Repeat if missed**, vibration, and sound. Reminder 1
   defaults to 09:00; Reminder 2 defaults to 20:00 and Off; day-before defaults
   On and uses Reminder 1's time. On a pure sideload, this on-watch screen is
   the authoritative editor.
6. **Return to the main screen** with **BACK**, then add the glance using the
   steps above.

From Main, press **UP** for six projected **Upcoming** cycles, **DOWN** for
**History**, **START** or tap for the context menu, and hold **MENU** for the
same menu. Within Upcoming or History, UP/DOWN scrolls and BACK returns. In
normal use, choose **Remove ring**, **Insert ring**, **Take out briefly**, or
**Put ring back** as the event occurs. State-changing actions require confirmation. The
actual removal anchors the next insertion; the actual insertion anchors the
next removal. Use **Correct dates** to correct only recorded insertion/removal
timestamps rather than recording a false event.

## What reminders look like—and their limits

Ring Tracker checks in the background about once per hour. It asks Garmin OS to
show a native notification on the optional day-before slot at Reminder 1's
time, on the action date at Reminder 1 and optional Reminder 2, repeatedly while
overdue, and with stronger wording if the ring-free interval exceeds seven
days. Each slot is deduplicated independently.

On an epix Pro, expect a Garmin-style full-screen notification card with the app
icon, title, and reminder text. The default actions are **Open** and **Dismiss**.
Opening the notification opens Ring Tracker; it does **not** record insertion or
removal until the corresponding action is chosen and confirmed. Garmin defines
this native presentation and launch behavior in its
[Connect IQ Notifications guide](https://developer.garmin.com/connect-iq/core-topics/notifications/).
An epix Pro 51 mm developer also verified the native-looking card, sound, and
vibration on physical hardware in this
[Garmin forum test report](https://forums.garmin.com/developer/connect-iq/f/discussion/406092/new-notifications-api/1909678).
Garmin does not promise that a Connect IQ app notification will remain in the
watch's Notification Center after dismissal; physical-device reports in that
same thread found that it could not be reopened from the notifications glance.
Treat it as an on-screen reminder card rather than a persistent inbox item.

Reminders are not exact alarms. Garmin describes temporal background events as
approximate, and the operating system may defer or stop a background process for
resource reasons. Background work also has a 30-second execution limit. See
Garmin's [Backgrounding guide](https://developer.garmin.com/connect-iq/core-topics/backgrounding/)
and [`Toybox.Background`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html).
With an hourly check, a reminder can be roughly an hour late even before other
OS delays. Do not use Ring Tracker as the only reminder for a time-critical
contraceptive action; keep an independent calendar or alarm.

Notifications are generated locally on the watch, so a live phone connection is
not required. Their sound, vibration, and visibility remain subject to the
watch's Do Not Disturb, Sleep Mode, and system Sound and Vibe settings. The
app's own vibration/sound switches apply to attention feedback when Ring Tracker
is in the foreground; Garmin OS decides the alert behavior of a native
notification.

## Phone and Garmin Express settings: the precise limitation

For a **Store-installed** Connect IQ app, App Settings can be edited in clients
such as the Connect IQ Store phone app, Garmin Connect Mobile, and Garmin
Express. For the same app copied as a `.prg`, those clients have no Store record
to query, so the settings page is absent, unavailable, or greyed out. A Garmin
developer forum report confirms the Express setting control is unavailable for
[a sideload without a Store connection](https://forums.garmin.com/developer/connect-iq/f/discussion/362052/can-t-open-the-setting-in-ciq-or-express).

There is a developer-only simulator `.SET`-file technique for seeding test
values, but it does not create a phone UI and is not an end-user setup path. A
current forum answer reaches the same conclusion for
[sideloaded App Settings](https://forums.garmin.com/developer/connect-iq/f/discussion/429848/settings-connect-iq-app-for-sideloaded-app---is-this-possible).

### If phone-managed settings are required

There are two Store routes, and “beta” does not mean a private link for a group:

1. **Developer-account beta.** Sign in to the Connect IQ developer portal,
   create a beta submission with an alternate app UUID, and upload its `.iq`
   package. The dashboard provides a beta installation URL; open it on a phone
   signed in to the **same Garmin account** and hand it to the Connect IQ Store
   app. The beta can then exercise Store-backed App Settings. It is not a public
   review/listing path: Garmin's beta documentation says beta app URLs are not
   visible to accounts other than the developer's. This is useful for the
   developer's own watch, not distribution to arbitrary testers. See [Beta
   Apps](https://developer.garmin.com/connect-iq/core-topics/beta-apps/) and a
   [current developer-dashboard installation
   report](https://forums.garmin.com/developer/connect-iq/f/discussion/427770/how-to-download-my-beta-test-app-to-my-device).
2. **Public Store release.** Sign in with a Connect IQ developer account, export
   an `.iq`, choose **Submit an App**, upload the package, add the required
   listing metadata/screenshots, and submit it for Garmin review. Garmin states
   that review is generally completed within 72 hours except for special
   circumstances and national holidays; this is a target, not a guarantee.
   While a submission is pending, the developer can test it on the submitting
   account; after approval it is publicly discoverable and compatible users can
   install it with settings and updates. See [Publishing to the
   Store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/)
   and Garmin's [settings guidance for beta/pending
   builds](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq).

Garmin does not currently offer a general unlisted Store URL that grants a beta
to selected outside accounts. The developer-account restriction remains an open
[beta-testing feature request](https://forums.garmin.com/developer/connect-iq/i/bug-reports/beta-testing-outside-of-single-account),
and Garmin forum guidance likewise says a normal app cannot be made
[private and non-searchable for selected users](https://forums.garmin.com/developer/connect-iq/f/discussion/220791/publish-apps-and-make-them-private-non-searchable).
Do not share Garmin-account credentials as a workaround.

**Recommendation:** use USB plus on-watch Settings for a private or one-watch
installation. Use a developer beta only on the submitting developer's own
Garmin account. Publish a reviewed public Store app when another owner needs
phone-managed settings or automatic updates.

Even on a Store installation, enter the exact insertion date and time on the
watch when possible. Garmin App Settings offers a native **Date** input but no
native time-only or combined date-time input; Garmin lists the supported setting
types in its [workflow and interaction
guidelines](https://developer.garmin.com/connect-iq/user-experience-guidelines/designing-workflows-and-interactions/).
Ring Tracker therefore pairs the native **Insertion date** control with an
**Insertion time** list at 15-minute intervals. Date controls are stored as UTC
epoch values by Garmin; Ring Tracker reads their UTC year, month, and day so the
selected calendar date does not shift in another timezone. A change to either
field is reconciled as one local date/time and is presented for confirmation
rather than silently replacing the watch record.

The watch editor keeps exact minutes from `00` through `59`. When a watch value
does not fall on a phone-list quarter-hour, only the mirrored phone property is
rounded to the nearest 15 minutes. The canonical watch value remains exact. A
time selected on the phone is already a list value and is accepted exactly.

The complete phone settings list is:

| Setting | Value |
| --- | --- |
| Insertion date | Native date control |
| Insertion time | 12-hour AM/PM list at 15-minute intervals |
| Days worn / Days out | `21–35` / `0–7` |
| Reminder 1 | 12-hour AM/PM list at 15-minute intervals; always enabled |
| Reminder 2 | On or Off |
| Reminder 2 time | 12-hour AM/PM list at 15-minute intervals; retained while Off |
| Day-before reminder | On or Off; uses Reminder 1's time |
| Repeat if missed | Every hour, every 3 hours, every 6 hours, or Off |
| Vibration / sound | On or Off for foreground feedback |

Ring Tracker always follows the watch's 12/24-hour setting; there is no
separate Clock control on the watch or phone.

## Remove Ring Tracker

Record any dates you need first. Treat uninstalling as deletion of the app's
local settings and history.

1. Hold **MENU**.
2. Open **Activities & Apps** and select **Ring Tracker**.
3. Choose **Remove from Device** or **Delete from Device**; wording varies by
   firmware.

If that option is absent, open the **Connect IQ Store** app on the watch, choose
**Installed > Ring Tracker > Uninstall**. Garmin forum guidance for current
devices recommends on-device removal because installed PRGs are hidden after
ingestion. Garmin Express may also list the app under **IQ Apps** and allow its
removal, even though it cannot edit a sideload's settings. See the
[hidden-PRG and removal discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/391547/where-do-the-app-prg-files-go-now-on-the-devices).

## Troubleshooting

### The computer does not show the watch

- Confirm the cable carries data; some USB cables charge only.
- On the watch, set **System > USB Mode > MTP**, reconnect, and accept **Use
  MTP** if prompted.
- Quit every other program that might own the MTP connection. On macOS, quitting
  Garmin Express means closing its background/menu-bar process too.
- Try a direct USB port and another data cable. Avoid a hub until the transfer
  works.
- On Linux, use either GVFS or `jmtpfs`, not both at once.

### Ring Tracker does not appear after copying

1. Confirm that the copied file ended in `.prg`, not `.iq` or `.zip`, and went
   into the existing internal-storage `GARMIN/APPS` directory.
2. Wait for verification to finish, then press **START** and inspect the full
   Activities & Apps list. A glance is not added automatically.
3. Confirm that the PRG was built for the exact 42, 47, or 51 mm device ID.
4. Update the watch firmware and ask the developer for a rebuild using a current
   SDK. Developers report that newer firmware can reject PRGs made with obsolete
   SDK/device definitions; see this
   [Garmin sideloading discussion](https://forums.garmin.com/developer/connect-iq/f/discussion/419051/sideloading-on-a-watch/2060657).
5. Restart the watch once, then inspect the list again. Restarting is a recovery
   step, not part of normal installation.

The PRG disappearing from USB-visible storage is normal on current firmware.
If an **IQ!** error appears, reconnect and give the developer
`/GARMIN/APPS/LOGS/CIQ_LOG.YML` (or `CIQ_LOG.TXT` on older firmware). Garmin
documents those crash logs in its [New Developer
FAQ](https://forums.garmin.com/developer/connect-iq/w/wiki/4/new-developer-faq).

### The watch reports that the app is not compatible

- Verify that the watch is **epix Pro (Gen 2)**, not epix (Gen 2), and match its
  case size to the device-ID table above.
- Request the correct build. A 47 mm PRG cannot be repaired for a 42 or 51 mm
  watch by changing its filename.
- Update watch firmware and retry a PRG built with current device definitions.
- Ask the developer to verify signing. Garmin's documented hardware-build flow
  explicitly selects a target product and signs its output; see the
  [Visual Studio Code extension guide](https://developer.garmin.com/connect-iq/reference-guides/visual-studio-code-extension/).

### App Settings are missing on the phone or grey in Express

This is expected for a USB sideload. Configure Ring Tracker on the watch. Pairing,
syncing, reinstalling the phone app, or reconnecting USB will not create the
missing Store association. Use the Store beta/public options above only if
phone-managed settings are essential.

### A reminder did not arrive

1. Open Ring Tracker and confirm the actual insertion/removal record,
   next-action time, Reminder 1, Reminder 2 state/time, day-before state, and
   overdue repeat interval.
2. Hold **LIGHT** and turn off **Do Not Disturb**. Garmin documents that DND
   disables alerts and notifications in the [epix DND
   guide](https://www8.garmin.com/manuals-apac/webhelp/epix/EN-SG/GUID-F54B5128-BDC3-40C3-948F-E51FACAE18BA-4493.html).
3. Hold **MENU > System > Sleep Mode** and check whether Sleep Mode enables DND.
   Garmin documents that option in [Customizing Sleep
   Mode](https://www8.garmin.com/manuals/webhelp/GUID-E5C62F3F-DCE3-4197-8CA5-E419B2A55D12/EN-US/GUID-10B3BD3D-5B72-4C4F-9B2D-93432AF67E43.html).
4. Under **System > Sound and Vibe**, check the watch's alert settings. There is
   no documented per-app epix switch for local Connect IQ notifications; do not
   confuse Garmin's phone-forwarded **Smart Notifications** settings with Ring
   Tracker's locally generated reminders.
5. Allow more than one hourly check interval. The scheduler is approximate, so
   do not treat a few minutes of delay as failure.
6. Restart the watch, open Ring Tracker once, and recheck the schedule. If the
   issue continues, note the watch firmware, app version, expected reminder time,
   DND/Sleep state, and any CIQ log for the developer.

Always keep an independent reminder. Background delivery is intentionally
best-effort and is not suitable as the sole safeguard for a medical schedule.

### Battery use seems higher

- Use a less frequent overdue-repeat setting, such as 6, 12, or 24 hours, to
  reduce repeated notification presentations. The app still performs its small
  periodic schedule check.
- Press **BACK** when finished so the full app is not left open.
- Check whether Always-On Display, GPS activities, music, Pulse Ox, or the
  flashlight changed at the same time. Garmin notes that display and enabled
  features materially affect epix battery life in its
  [battery-life guidance](https://support.garmin.com/en-US/?faq=oYpVKSoFmj86gPYq0S07TA&productID=884088&tab=topics).
- Restart the watch. If the drain persists, record the percentage drop over a
  comparable day, remove Ring Tracker temporarily, and compare again before
  reporting it.

## Developer: build it yourself

Developers can build a signed PRG for each exact target with the repository's
documented Connect IQ SDK setup. Follow [TOOLCHAIN.md](TOOLCHAIN.md), select one
of `epix2pro42mm`, `epix2pro47mm`, or `epix2pro51mm`, and give the owner only the
matching `.prg`. Keep the developer private key private, and do not commit it.
