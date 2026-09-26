# Wored

A compact, minimal music player for macOS, built with SwiftUI and AppKit.

![Wored screenshot](assets/wored-screen.png)

## Download and Installation

[Download the latest release](https://github.com/tercan/wored/releases/latest).

- **DMG:** Open the disk image and drag Wored to the Applications shortcut.
- **ZIP:** Extract the archive and move Wored.app to your Applications folder.
- Prebuilt applications require **Apple Silicon (arm64)** and **macOS 26.2 or later**.
- Packages are ad-hoc signed, not Developer ID signed or notarized. macOS may display a security warning on first launch.
- Use the included SHA256SUMS.txt file to verify download integrity.

## Features

- Compact interface with sharp corners and flat colors
- Docked playlist with adjustable height
- File and folder drag-and-drop, track reordering, and folder rescanning
- Multiple playlists, search, favorites, and playback history
- Detailed track information and MP3/ID3 text and artwork editing
- Menu bar controls and playback while the player window is hidden
- Light, dark, and system themes, EQ presets, and crossfade
- Saved panel positions and adjustable track-info panel height
- Single-instance operation

## Keyboard and Mouse Controls

- Space: play/pause; inserts a normal space in text fields
- Cmd+L: show/hide the playlist
- Cmd+O: add files or folders
- Cmd+F: search the playlist
- Cmd+Comma: open/close settings
- Cmd+W or Ctrl+W: close the focused settings or track-info panel
- Double-click a track to play it; click its heart to toggle favorite status
- Click the player's X button to hide its windows; press Cmd+Q to quit

## Build from Source

Use Xcode 26.4 or later. Open wored.xcodeproj and build the Wored scheme.

To run the regression tests and create a local Release package:

```sh
bash scripts/test.sh
bash scripts/package-release.sh 0.7.1
```

The application is written to dist/Wored.app; versioned packages are written to dist/releases/0.7.1.

## Version

0.7.1
