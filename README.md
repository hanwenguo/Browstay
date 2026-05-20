I have been annoyed by one particular behavior of Safari. When some other app attempts to open a link while Safari happens to do not have any windows on the current desktop but have windows on other desktops, Safari opens the link in a new tab in one of the existing windows on the other desktop, sometimes jumping from, say, desktop 7 to desktop 1.

There is an Safari preference option to always open links in a new window, but that causes Safari to open a new window for _every_ link, meaning that you click a link while browsing, and Safari opens a new window for that link, which is also annoying.

So this is a rather specific use case, and I couldn't find any existing app that solves this problem. [This is when you write an Emacsificated software.](https://sockpuppet.org/blog/2026/05/12/emacsification/) So, I described the problem to Codex, and it gave me the following. Note that I didn't read or touched any of the code, but it Just Works™️. I have been using it for a few days, and it works perfectly. I hope this can be useful for other people who have the same problem.

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

Copy the app bundle to `/Applications` and launch it.

Stayfari is menu-bar only and does not show a Dock icon.

## Set as Default Browser

Open the Stayfari menu bar item and choose **Set as Default**. This sets Stayfari as the handler for both `http` and `https` using Launch Services.

To return to normal Safari behavior, choose **Restore Safari** from the menu bar item.

## Permissions

The first time Stayfari needs to create a Safari window, macOS may ask whether Stayfari can control Safari. Approve that prompt. Stayfari uses this only for Safari and only to create a regular Safari window for an external web link.

## Fallback Behavior

If Safari automation is denied or fails, Stayfari opens the link normally in Safari. The link should still open, but macOS may switch to a Safari Space in that fallback path.

## License

If I have the right to license this code, it is licensed under GNU GPL v3 or later.
