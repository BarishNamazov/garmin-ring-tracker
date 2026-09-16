# Human-in-the-loop remote browser

This starts a real, headed Chromium inside a user-local VNC desktop, publishes
that desktop through noVNC and an ephemeral Cloudflare Quick Tunnel, and leaves
Chromium's DevTools endpoint available locally for Playwright automation.

## Start

From the repository root:

```bash
scripts/remote-browser/start.sh
```

The script prints two lines and writes the same content to `CONNECT.txt` with
mode `0600`:

```text
https://random-words.trycloudflare.com/vnc.html?autoconnect=1&resize=scale&path=websockify
VNC password: 12345678
```

Open the URL, enter the password if noVNC asks for it, and sign in to Garmin
yourself. Chromium is an ordinary full browser; the launcher does not add
fingerprint-spoofing or automation-hiding flags. Ubuntu 24.04 on this host
blocks Chromium's unprivileged namespace sandbox, so the user-only launcher
must pass `--no-sandbox`. Treat the browser as dedicated to this login task.
The browser profile is `/tmp/remote-browser-profile`, so the signed-in session
survives a normal stop and restart.

## Security

While this is running, the noVNC page is public to anyone who has both the
unguessable Quick Tunnel URL and the VNC password. The tunnel is temporary and
gets a new URL on restart. Stop it as soon as the interactive login is done.
Do not publish `CONNECT.txt`, logs, or the VNC password.

Only noVNC is exposed through Cloudflare. VNC, websockify, and CDP listen on
loopback. The local CDP endpoint for subsequent automation is:

```text
http://127.0.0.1:9222
```

Example connection from Node using the existing Playwright installation:

```js
const { chromium } = require('/tmp/pw/node_modules/playwright');
const browser = await chromium.connectOverCDP('http://127.0.0.1:9222');
const pages = browser.contexts().flatMap((context) => context.pages());
```

## Stop

```bash
scripts/remote-browser/stop.sh
```

This stops cloudflared, websockify, Chromium, and the VNC/X server, then removes
`CONNECT.txt` and the VNC password. It deliberately keeps the Chromium profile.

To stop everything and explicitly delete the saved login profile:

```bash
scripts/remote-browser/stop.sh --wipe
```

Runtime logs, PID files, and the CDP verification transcript are under `.state/`.
The startup verification also saves `garmin-signin.png`, captured through CDP.

The normal ports are display `:99`, VNC `5999`, noVNC `6080`, and CDP `9222`.
Startup refuses to replace another service using any of them.
