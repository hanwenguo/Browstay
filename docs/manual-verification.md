# Manual Verification

Run these checks after `script/build_app.sh` and `open build/Stayfari.app`.

## Bundle Checks

```bash
plutil -lint build/Stayfari.app/Contents/Info.plist
codesign -dvvv --entitlements :- build/Stayfari.app
```

Expected:

- `plutil` reports `OK`.
- `codesign` output includes `com.apple.security.automation.apple-events`.

## Default Browser Setup

1. Open Stayfari from the menu bar.
2. Choose **Set as Default**.
3. Choose **Refresh Status**.
4. Confirm the status line says `HTTP: Stayfari, HTTPS: Stayfari`.

## Link Routing Scenarios

For each scenario, open the test URL through the configured default handler from another app, not from Safari itself. For example, run:

```bash
open https://www.apple.com/
```

If testing Automation denied, run that scenario before any scenario that may need Safari automation, or reset Stayfari's Automation permission in System Settings before running it.

1. Safari not running:
   - Quit Safari.
   - Open `https://www.apple.com/` from another app.
   - Expected: Safari opens and loads the link.

2. Safari visible on the current Desktop:
   - Keep a Safari window visible.
   - Open `https://www.apple.com/` from another app.
   - Expected: Safari uses its normal tab/window preference in the visible window.

3. Safari running only on another Desktop:
   - Put Safari on Desktop 2.
   - Switch to Desktop 1 with no Safari windows visible.
   - Open `https://www.apple.com/` from another app.
   - Expected: Desktop 1 stays visible and Safari creates or shows a regular window there for the link.

4. Safari hidden or minimized:
   - Hide or minimize all Safari windows.
   - Open `https://www.apple.com/` from another app.
   - Expected: Stayfari creates a regular Safari window for the link or falls back to normal opening.

5. Automation denied:
   - Ensure no Safari window is visible on the current Desktop.
   - Open `https://www.apple.com/` from Terminal or another non-Safari app, for example: `open https://www.apple.com/`.
   - Deny the macOS prompt when Stayfari asks to control Safari.
   - Expected: The link opens normally in Safari and the menu status mentions fallback.

6. Multiple displays:
   - Keep any normal Safari window visible on any connected display in the current visible Spaces.
   - Open `https://www.apple.com/` from another app.
   - Expected: Stayfari uses normal Safari opening and does not create a separate forced window.
