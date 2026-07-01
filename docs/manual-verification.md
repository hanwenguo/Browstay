# Browstay Manual Verification

Run these checks after:

```bash
script/build_app.sh
open build/Browstay.app
```

## Bundle Checks

```bash
plutil -lint build/Browstay.app/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 build/Browstay.app
codesign -dvvv --entitlements :- build/Browstay.app
```

Confirm:

- The plist is valid.
- The signature is valid.
- `com.apple.security.automation.apple-events` is present.
- Browstay appears in the menu bar without a Dock icon.

## Default Handler and Selection

1. Select an installed browser in **Browser**.
2. Choose **Set Browstay as Default**.
3. Approve notification access if prompted.
4. Choose **Refresh Browsers & Status**.
5. Confirm the status says `HTTP: Browstay, HTTPS: Browstay`.
6. Change the selected browser and confirm Browstay remains the default.
7. Choose **Test Open** and confirm the selected browser receives the URL.

## Browser Matrix

Repeat every scenario for Safari, Orion, and Helium. A browser is releasable
only after every applicable scenario passes.

### Visible Current-Space Window

1. Keep a normal target-browser window visible on the current Desktop.
2. Open `https://www.apple.com/` from another app.

Expected: the browser uses its normal external-link behavior. Browstay does not
force an extra window.

### Window Only on Another Desktop

1. Put all target-browser windows on Desktop 2.
2. Switch to Desktop 1.
3. Run `open https://www.apple.com/` from Terminal or open a link from another
   app.

Expected: Desktop 1 remains visible and a regular target-browser window opens
there.

### Browser Not Running

1. Quit the target browser.
2. Open an HTTPS link from another app.

Expected: the browser launches with a regular window on the current Desktop.

### Automation Denied

Run this before granting automation, or reset Browstay automation permission in
System Settings.

1. Ensure no target-browser window is visible on the current Desktop.
2. Open an HTTPS link from another app.
3. Deny the prompt allowing Browstay to control the target browser.

Expected: the URL opens through the same browser's normal behavior, Browstay
posts a warning, and the menu retains the fallback result.

### Multiple Displays

When multiple displays are connected:

1. Keep a target-browser window visible on either display.
2. Open an external link.

Expected: Browstay treats the target as visible and uses normal opening.

## Failure and Restore

1. Select a browser, then make its app temporarily unavailable only if this can
   be done without disrupting the system installation.
2. Open a link.

Expected: Browstay does not use another browser, posts an unavailable-browser
notification without the URL, and retains the error in the menu.

Restore the app before continuing.

Finally:

1. Select the browser that should become the macOS default.
2. Choose **Restore _Browser_ as Default**.
3. Choose **Refresh Browsers & Status**.
4. Confirm both schemes show that browser's bundle identifier.
5. Quit Browstay.
