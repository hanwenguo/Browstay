# Browstay Multi-Browser Design

## Summary

Rename Stayfari in place to Browstay with bundle identifier
`io.hanwen.Browstay`. Browstay remains the macOS default-browser proxy, but
routes links to one user-selected supported browser.

The first release supports only installations validated end to end:

- Safari (`com.apple.Safari`)
- Orion (`com.kagi.kagimacOS`)
- Helium (`net.imput.helium`)

Support is curated in code. Browstay does not infer compatibility from an
application's scripting dictionary and does not accept user-provided scripts.

## Browser Model

Each browser definition has:

- A stable browser identifier used for persistence.
- A display name.
- A bundle identifier used for discovery, normal opening, and window matching.
- Owner-name fallbacks for Core Graphics snapshots without a bundle identifier.
- A tested new-window strategy.

`BrowserCatalog` discovers installed definitions through `NSWorkspace`.
`BrowserSelectionStore` persists the selected identifier in `UserDefaults`.
On first launch, Browstay selects the current HTTPS handler when supported,
maps old Stayfari to Safari, and otherwise selects Safari.

The picker normally lists installed supported browsers. If the persisted
selection is no longer installed, that browser remains visible as unavailable
until the user chooses another target.

## Routing

The selected browser is captured when an incoming URL batch arrives.

1. Reject non-HTTP(S) URLs.
2. Resolve the selected application at routing time.
3. If unavailable, open nothing and report failure.
4. If current-Space behavior is disabled, open normally in the target.
5. If a normal target-browser window is visible in the currently visible
   Spaces across connected displays, open normally in the target.
6. Otherwise create a regular target-browser window for the first URL, then
   normally open the remaining URLs.
7. If forced-window automation fails, normally open the complete valid batch in
   the same browser and report a warning.
8. Never fall back to a different browser.

Window matching keeps the existing layer, alpha, size, and onscreen filters.
It matches the selected bundle identifier first and uses owner names only when
the snapshot lacks a bundle identifier.

## Browser Opening

Normal opening is shared and uses `NSWorkspace.open` with the resolved
application URL.

Forced new-window behavior uses a curated strategy:

- Safari creates a new document with the URL.
- Orion uses its independently tested document strategy.
- Helium creates a normal Chromium window and sets its active tab URL.

AppleScript execution and string escaping are shared. Automation permission is
requested by macOS only when a real link or Test Open first needs a forced
window for the selected browser.

## Defaults, Failures, and Menu

Setting Browstay as default assigns `http` and `https` to
`io.hanwen.Browstay`. Restoring assigns both schemes to the selected browser.
Changing the selected browser does not alter the macOS default handler.

The menu contains:

- Open Links on Current Space
- Browser picker
- Set Browstay as Default
- Restore the selected browser as default
- Refresh Browsers & Status
- Test Open
- Target availability, handler status, and latest routing result
- Quit

Browstay requests notification authorization when the user sets it as default.
An unavailable target or complete opening failure produces a failure
notification. A successful same-browser fallback produces a warning
notification. Notifications identify the browser and failure category without
including URLs. The latest warning or failure is retained in the menu even when
notification permission is denied.

## Product Migration

The package, executable, core module, app bundle, scripts, metadata, tests, and
documentation are renamed to Browstay. The app bundle is written to
`build/Browstay.app`.

The new identity does not inherit Stayfari preferences or permissions. Existing
users quit Stayfari, launch Browstay, select a browser, and set Browstay as the
default. Setting Browstay as default replaces the old handler whether or not
Safari was restored first.

## Acceptance

Automated tests cover browser discovery and selection, target-specific window
matching, all three script strategies, target-aware routing and fallback,
default restoration, notification classification, runtime serialization, and
renamed bundle metadata.

Safari, Orion, and Helium must each pass the manual matrix for current-Space
normal opening, other-Space forced-window opening, cold launch, automation
denial fallback, Test Open, default activation/restoration, and notification
behavior before release.

Firefox, additional Chromium brands, domain routing, per-link choosers,
browser-profile selection, custom scripts, and automatic scripting-dictionary
inference are out of scope.
