# Ring Tracker — Connect IQ Store listing

This is the English (`en`) listing copy for version 1.3.0. Character counts include spaces and punctuation. Limits were checked against Garmin's current submission form on 2026-09-16.

## Store fields

### App name — 12/50 characters

```text
Ring Tracker
```

### One-line tagline — 63 characters

The current dashboard has no separate tagline field or published tagline limit. Use this as the first line of the description or in promotion outside the Store.

```text
Track your NuvaRing schedule and local reminders on your watch.
```

### Description — 1,881/4,000 characters

```text
Ring Tracker is a private, on-watch schedule tracker for NuvaRing.

See ring-in, ring-free, temporary-out, and overdue states at a glance. Record actual insertion, removal, and temporary-out times; view six upcoming cycles and up to 24 cycles of history; and correct actual dates when needed.

Set Reminder 1, optional Reminder 2, an optional day-before reminder, overdue repeats, and sound/vibration directly on the watch. Time display follows the watch's 12/24-hour setting. The default schedule is 21 days in and 7 days out. Clinician-directed plans from 21–35 days in and 0–7 days out can be represented, but Ring Tracker does not recommend an extended plan.

Reminders are generated locally on the watch and do not require a phone or network connection. Garmin runs background checks approximately once per hour, and the operating system may delay or stop them. Do Not Disturb, Sleep Mode, and watch notification settings also affect delivery. Do not rely on Ring Tracker as your only time-critical reminder.

All schedule and history data stays on the watch. Ring Tracker has no network permission and does not collect, transmit, sell, or share user data.

Designed and tested for epix Pro (Gen 2) watches in 42 mm, 47 mm, and 51 mm sizes. No other watch models are claimed as tested.

This app is for NuvaRing only. Not for generics or Annovera.

This app is a scheduling aid, not medical advice. It cannot determine whether contraception is effective. Follow the instructions supplied with your ring and contact a qualified clinician or pharmacist if a ring is late, has been out too long, or pregnancy is possible.

Open source: https://github.com/BarishNamazov/garmin-ring-tracker
Support: https://github.com/BarishNamazov/garmin-ring-tracker/issues

Ring Tracker is an independent project and is not affiliated with or endorsed by Garmin or the manufacturer of NuvaRing.
```

### What's New — 683/4,000 characters

```text
Version 1.3.0 makes Ring Tracker easier to read on round screens. Main keeps action dates and times visible, uses consistent late counts, and shows a reinsertion deadline during brief ring-outs. Upcoming and History have clearer columns, current-cycle markers, and year cues. Glance and reminders use shorter, consistent wording.

Time and date pickers show every column together. Correct dates distinguishes recorded events from pending removal. Settings use Days worn and Days out, direct reminder toggles, and the watch's time format. Phone App Settings include a native insertion-date control and quarter-hour AM/PM time lists. Existing dates and reminders migrate automatically.
```

### Category — required

Select **Medical** for this Device App. Ring Tracker manages the timing and reminders for a prescribed contraceptive ring, so Medical is more specific and less misleading than the broader Health & Fitness or Wellness categories. The description deliberately presents the app as an informational scheduling aid, not as a diagnostic, treatment, efficacy, or safety tool.

The current top-level Device App categories are: Beliefs, Business, Celestial, Communication, Education, Entertainment, Finance, Food & Drink, Games, Golf, Health & Fitness, Home Automation, Lifestyle, Marine, Medical, Navigation, Social, Sports, Strength Training, Tools, Travel, Weather, and Wellness. Health & Fitness requires one of these subcategories: Cycling, Geocaching, Hiking, Other, Running, Swimming, or Walking. Garmin's current form requires a subcategory only when the selected category supplies one; Medical currently has no subcategory.

### Supported devices statement — no separate text-field limit

```text
Designed and tested for epix Pro (Gen 2) watches in 42 mm, 47 mm, and 51 mm sizes. No other watch models are claimed as tested.
```

The `.iq` manifest is authoritative for Store compatibility and contains `epix2pro42mm`, `epix2pro47mm`, and `epix2pro51mm`.

### App version — 5/20 characters

```text
1.3.0
```

### Support URL — no current dedicated field or confirmed limit

```text
https://github.com/BarishNamazov/garmin-ring-tracker/issues
```

The current form requires a public developer email address and offers an optional Source Code URL, but its rendered form does not expose a dedicated Support URL. Keep the support URL in the description. If the account-specific form shows Garmin's `FAQ Link` field, use this same issues URL there.

### Source Code URL — optional; no published character limit

```text
https://github.com/BarishNamazov/garmin-ring-tracker
```

### Developer email — required; no published character limit

Enter a monitored project-support address. Garmin states that this address is displayed publicly; the repository does not specify an address to paste here.

### Privacy and data questions

- **Does your app collect user data?** No.
- **Privacy Policy URL:** Not applicable. The form hides this field when the answer is No and requires it only when the answer is Yes.
- **Data stored on the watch:** insertion/removal times, temporary-out intervals, reminder settings and delivery state, schedule settings, and cycle history.
- **Data transmitted by the app:** none. The manifest declares Background and Notifications permissions, but no Communications, Positioning, Sensor, UserProfile, or PushNotification permission.
- **Network service or account required:** no.
- **Sale or sharing of user data:** none.

### Keywords — no current dashboard field or confirmed limit

The current form has no separate keyword field. These are the relevant search terms already represented naturally in the description:

```text
NuvaRing, vaginal ring, contraception, reminder, schedule, cycle tracker
```

## Store images

### Cover image / app icon

Upload [`icon-500.png`](icon-500.png). Garmin's brand rules require 500×500 pixels, sRGB, at least 10 pixels of padding, a simple centered design, a solid non-black/non-transparent background, no descriptive text, and no Garmin branding. The current dashboard accepts JPG, GIF, or PNG under 300 KB. This asset is an 8-bit RGB PNG with an embedded sRGB profile and a solid `#101B2D` background.

### Screen images

The current dashboard accepts 1–5 screen images, each a JPG, GIF, or PNG under 150 KB. It publishes no screenshot pixel-dimension or bezel requirement and the form performs no client-side dimension check. Use the first five native 416×416 PNGs in this order:

1. `01-main-ring-in.png`
2. `02-ring-free.png`
3. `03-upcoming.png`
4. `04-glance.png`
5. `05-ring-out.png`

The remaining requested story screens are upload-ready alternatives, not additional uploads under the current five-image maximum:

6. `06-overdue-alternate.png`
7. `07-history-alternate.png`
8. `08-settings-alternate.png`

The images preserve the native round-display capture at 416×416. A separate decorative device frame is not required, so no framed variant is included.

### Hero image — optional

The current form has an optional, localizable Hero Image field. It accepts JPG, GIF, or PNG, requires exactly 1440×720 pixels, and allows up to 2,048 KB. This is distinct from the 500×500 cover image. No hero image was produced because Garmin marks it optional and the requested deliverables did not include a 1440×720 creative.

## Requirements that remain unconfirmed

Garmin's public submission guide says to upload the `.iq`, then add the description and screenshots after validation, but it does not enumerate the current form. The field labels and client-side limits above were checked in Garmin's current official dashboard UI bundle and English locale data. An authenticated end-to-end submission was not available, so server-side rules beyond the visible validators could not be tested.

Garmin's public brand page does not specify screenshot dimensions, aspect ratio, bezel treatment, or a separate banner beyond the optional 1440×720 hero image. No separate tagline, keyword, or Support URL field appears in the current rendered form. Recheck the authenticated form immediately before submission because Garmin says its guidelines may change.

## Official references

- [Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Publishing to the Connect IQ Store](https://developer.garmin.com/connect-iq/core-topics/publishing-to-the-store/)
- [Beta Apps](https://developer.garmin.com/connect-iq/core-topics/beta-apps/)
- [Connect IQ brand guidelines](https://developer.garmin.com/brand-guidelines/connect-iq/)
- [Connect IQ App Review Guidelines](https://developer.garmin.com/connect-iq/app-review-guidelines/)
- [Current dashboard field text](https://apps-developer.garmin.com/locales/en-US/upload.json)
- [Current Store category strings](https://apps-developer.garmin.com/locales/en-US/appCategories.json)
