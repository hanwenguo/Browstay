# Stayfari

Stayfari is a small macOS menu bar app that acts as a default-browser proxy for Safari. When another app opens an external `http` or `https` link, Stayfari sends the link to Safari. If Safari already has a visible window in the current visible Spaces, Safari keeps its normal tab/window behavior. If Safari is running only on another Desktop, Stayfari asks Safari to create a regular window for the link on the current Desktop.

## Build

```bash
script/build_app.sh
```

The app bundle is written to:

```text
build/Stayfari.app
```

## Run

```bash
open build/Stayfari.app
```

Stayfari is menu-bar only and does not show a Dock icon.

## Set as Default Browser

Open the Stayfari menu bar item and choose **Set as Default**. This sets Stayfari as the handler for both `http` and `https` using Launch Services.

To return to normal Safari behavior, choose **Restore Safari** from the menu bar item.

## Permissions

The first time Stayfari needs to create a Safari window, macOS may ask whether Stayfari can control Safari. Approve that prompt. Stayfari uses this only for Safari and only to create a regular Safari window for an external web link.

## Fallback Behavior

If Safari automation is denied or fails, Stayfari opens the link normally in Safari. The link should still open, but macOS may switch to a Safari Space in that fallback path.
