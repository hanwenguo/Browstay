# Browstay

Browstay is a small macOS menu bar app that keeps external browser links on the
current Desktop.

It acts as the default handler for `http` and `https`, then forwards each link
to one selected browser. If that browser already has a normal window visible in
the current visible Spaces, Browstay preserves its normal tab and window
behavior. If its windows exist only on another Desktop, Browstay creates a
regular window for the link on the current Desktop.

Browstay supports a curated list of browsers:

- Safari
- Orion
- Helium
- Google Chrome
- Chromium
- Ungoogled Chromium

Chromium and Ungoogled Chromium are separate choices because each has its own
bundle identifier, even though both install as `Chromium.app`.

Additional browsers require a tested Browstay adapter or browser definition.
Browstay does not infer support from arbitrary installed applications.

## Homebrew

```bash
brew install --cask --no-quarantine hanwenguo/tap/browstay
```

Browstay is ad-hoc signed rather than notarized by Apple. Using
`--no-quarantine` is an explicit decision to trust the release; Homebrew still
verifies the archive against the checksum recorded in the tap. A normal cask
installation may instead require approval in **System Settings → Privacy &
Security**. Because ad-hoc signatures are not a persistent developer identity,
macOS may ask for Automation permission again after an upgrade.

## Build

```bash
script/build_app.sh
```

To make the universal release build locally:

```bash
CONFIGURATION=release ARCHS="arm64 x86_64" script/build_app.sh
```

The app bundle is written to:

```text
build/Browstay.app
```

Copy the bundle to `/Applications` and launch it. Browstay is menu-bar only and
does not show a Dock icon.

## Setup

1. Open the Browstay menu bar item.
2. Choose an installed browser from **Browser**.
3. Choose **Set Browstay as Default**.
4. Approve notification access so background routing failures can be reported.

Changing the selected browser does not change the macOS default handler.
Browstay remains the proxy and sends future links to the new selection.

To stop using Browstay, choose **Restore _Browser_ as Default**. Browstay sets
both `http` and `https` to the selected browser.

## Current-Space Behavior

The **Open Links on Current Space** toggle controls only window placement:

- On: create a browser window on the current Desktop when none is visible.
- Off: forward links normally to the selected browser.

Browstay treats a target-browser window on any currently visible connected
display as visible.

## New Window Shortcut

Press **⌃⌥⌘N** anywhere to open a new window of the selected browser on the
current Desktop of the display under the mouse pointer. The same action is
available from the menu as **New _Browser_ Window Here**. The shortcut works
whether or not **Open Links on Current Space** is on.

## Permissions and Failures

The first forced-window open for each selected browser may cause macOS to ask
whether Browstay can control that browser.

If automation is denied or fails, Browstay opens the link normally in the same
browser and posts a warning. macOS may switch to another Desktop in that
fallback path.

If the selected browser is unavailable, Browstay does not silently use another
browser. It leaves the link unopened, posts a notification, and retains the
failure in the menu.

Notifications identify the browser and failure category but do not include the
URL.

## Migrating from Stayfari

Browstay has a new application and bundle identity. Existing Stayfari settings,
default-handler registration, and automation permission are not reused.

Quit Stayfari, launch Browstay, select a browser, and choose **Set Browstay as
Default**. Browstay can replace the old Stayfari handler directly; restoring
Safari first is optional.

## Verification

See [docs/manual-verification.md](docs/manual-verification.md) for the browser
release matrix.

## License

GNU GPL v3 or later. See [LICENSE](LICENSE).
