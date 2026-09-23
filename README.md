# Ring Tracker

[![CI](https://github.com/BarishNamazov/garmin-ring-tracker/actions/workflows/ci.yml/badge.svg)](https://github.com/BarishNamazov/garmin-ring-tracker/actions/workflows/ci.yml)

Track your NuvaRing schedule on your Garmin watch. See when to insert or remove your ring, record what happened, and get reminders.

**Currently supported watches:** epix Pro (Gen 2) in 42, 47, and 51 mm.

[Install from the Connect IQ Store](https://apps.garmin.com/apps/5347b9a1-5dd1-4e0a-93bd-b5dcf2a1ef4f) · [Latest GitHub release: 1.3.2](https://github.com/BarishNamazov/garmin-ring-tracker/releases/latest)

> Ring Tracker is a scheduling aid, not medical advice. It cannot determine whether contraception is effective. Follow your ring’s instructions and contact a clinician or pharmacist if it is late, has been out too long, or pregnancy is possible.

## What it does

- Shows your current status and next insertion or removal time.
- Records insertions, removals, and temporary breaks, with dates you can correct.
- Shows upcoming cycles and cycle history.
- Offers configurable reminders and a glance for quick checks.
- Keeps your schedule on the watch; reminders work without a phone connection.

| Current schedule | Upcoming cycles |
| --- | --- |
| ![Ring-in countdown](docs/screenshots/epix2pro47mm-main-ring-in.png) | ![Upcoming insertion and removal dates](docs/screenshots/epix2pro47mm-upcoming-rows-1-3.png) |

## Get started

1. Install **Ring Tracker** from the [Connect IQ Store](https://apps.garmin.com/apps/5347b9a1-5dd1-4e0a-93bd-b5dcf2a1ef4f) and sync your watch.
2. Press **START** on the watch face and open **Ring Tracker** from **Activities & Apps**.
3. Read the safety text, review the default **21 days in / 7 days out** schedule, and enter your actual insertion date and time. Use **Insert now** only if you just inserted the ring.

The main screen shows your status and next action. Open the menu to record **Insert ring**, **Remove ring**, or **Take out briefly**. Use **Correct dates** to fix a recorded date and **Settings** to adjust reminders. For a clinician-directed schedule, read the [schedule guidance](docs/REGIMEN.md) first.

To add the glance, hold **MENU** on the watch face, then choose **Appearance > Glances > Add > Ring Tracker**.

### Install a GitHub release

For a version not yet on the Store, download the `.prg` matching your watch’s case size from [GitHub Releases](https://github.com/BarishNamazov/garmin-ring-tracker/releases/latest). Follow the [USB installation guide](docs/INSTALL.md) to copy it to `GARMIN/APPS`. The `.iq` file is for Store submission.

With a USB install, change settings on the watch; phone App Settings need the Store version.

## Reminders

The watch checks for reminders about once an hour, so alerts can arrive an hour late or longer if Garmin delays background activity. Sleep Mode, Do Not Disturb, and watch sound settings also affect alerts. Use an independent alarm for time-critical actions.

## Development

Follow the [toolchain setup](docs/TOOLCHAIN.md), then run:

```bash
./scripts/build.sh release
./scripts/build.sh test
```

Release files are written to `bin/release/`. See the [implementation guide](docs/IMPLEMENTATION.md) for internals and debug builds, and the [publishing guide](docs/PUBLISHING.md) for GitHub and Store releases.

[Release notes](CHANGELOG.md) · [Installation and troubleshooting](docs/INSTALL.md) · [More screenshots](docs/screenshots/) · [MIT License](LICENSE)
