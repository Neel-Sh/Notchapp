# NotchShelf

NotchShelf is a local-first macOS notch productivity app built inside the `NotchApp` Xcode project. It keeps recent clipboard items, temporary files, quick notes, and keep-awake controls close to the notch without using Notification Center or a persistent menu bar item.

## Features

- **Notch-only panel**: compact black SwiftUI/AppKit panel anchored around the notch, with no Dock icon and no visible menu bar item.
- **Clipboard history**: tracks recent copied text and links, deduplicates entries, supports search, copy-back, delete, clear recents, and local JSON persistence.
- **Link and text handling**: link items open in Safari from the left icon; text items open in a selectable detail view so partial text can be selected.
- **Favorites**: save clipboard items into custom folders with optional titles, search saved items, move favorites between folders, and delete custom folders.
- **Temporary file shelf**: drag files into the notch/panel to copy them into local app storage, then reveal, copy path, drag out, AirDrop, pin, multi-select, or remove them.
- **Two-day shelf retention**: unpinned shelf files are treated as temporary and automatically expire after two days; pinned files are kept.
- **Quick notes**: add short notes from the notch panel, including Enter-to-add behavior, copy, and delete.
- **Focus view**: keep-awake control for two hours or until turned off.
- **Local-only storage**: no app network calls. Clipboard, favorites, notes, shelf metadata, and copied shelf files stay on the Mac.

## Keyboard Shortcuts

- `Command 1`: Clipboard
- `Command 2`: Shelf
- `Command 3`: Notes
- `Command 4`: Focus
- `Command K`: toggle Keep Awake until turned off
- `Command Shift Delete`: clear recent clipboard history
- `Enter`: add the current quick note

## Local Storage

NotchShelf stores data under:

```text
~/Library/Application Support/NotchShelf/
```

Important files:

- `clipboard.json`: recent clipboard metadata
- `clipboard-folders.json`: custom favorite folders and saved clipboard items
- `notes.json`: quick notes
- `shelf.json`: shelf file metadata
- `Shelf/`: copied shelf files

Removing a shelf item deletes only the app-managed copy in `Shelf/`, never the original source file.

## Permissions

- Pasteboard access is used for clipboard history and copy-back behavior.
- File shelf actions use local file access for files the user explicitly drops into the app.
- Keep Awake uses a local IOKit power assertion while enabled.

## Build

Open `NotchApp.xcodeproj` in Xcode and run the `NotchApp` scheme, or build from the command line:

```bash
xcodebuild -project NotchApp.xcodeproj -scheme NotchApp -sdk macosx -configuration Debug build
```

Run tests:

```bash
xcodebuild -project NotchApp.xcodeproj -scheme NotchApp -sdk macosx -configuration Debug test
```

## Architecture

- `AppDelegate` owns the accessory app lifecycle.
- `NotchPanelController` manages notch/panel activation and positioning.
- `NotchShelfPanelView` hosts the top-level SwiftUI tabbed interface.
- Feature views live in separate SwiftUI files for Clipboard, Shelf, Notes, and Focus.
- Local persistence uses small JSON stores rather than a database.
- The old Codex task provider remains isolated behind model/provider types for later reuse, but the active UI does not expose a Codex tab.

## Limitations

macOS does not provide a public API for placing third-party UI inside the hardware notch itself. NotchShelf uses an overlay-style panel anchored around the notch/menu-bar region, which is the practical approach for a personal-use notch app. External displays and Macs without a notch fall back to the same anchored panel behavior.

## Roadmap

- Privacy filters for sensitive clipboard sources.
- Better folder management for favorites, including rename.
- Optional snippet expansion or multi-paste workflows.
- Shelf size limits and cleanup controls.
- Settings panel for retention, shortcuts, and launch-at-login.

## Requirements and fork

The checked-in deployment target is **macOS 15.0**. Use Xcode with a compatible macOS SDK and select your own development team if signing is needed. This repository is a fork of [nwwehling/Notchapp](https://github.com/nwwehling/Notchapp); the NotchShelf description above reflects this fork's current code. Preserve upstream attribution when contributing. See [Contributing](CONTRIBUTING.md). No repository-wide license file is included.
