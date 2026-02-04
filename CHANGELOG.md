# Changelog

All notable changes to Wored will be documented in this file.

## [Unreleased] - 2026-02-04

### Added
- Separate playlist window with show/hide toggle, resizable layout, and optional pin-to-player behavior.
- Mini player mode and menu bar controls.
- Media keys / Now Playing integration.
- AVAudioEngine playback pipeline with gapless playback, crossfade, and EQ.
- Playlist search, context menu actions, and drag & drop reordering.
- TR/EN localization support.
- Marquee scrolling for long text in the playing track.

### Changed
- Compact, minimal UI layout with max 4px radius and borderless windows.
- Warm Minimal design evolved to the #003999 blue palette and tonal system.
- Playlist persistence upgraded with versioned schema and resume state.

### Fixed
- Duration loading for all playlist items (not just the active track).
- Security-scoped bookmark refresh + fallback handling.
- Drag highlight visibility and row hover states.
- Info popover corners and shadow removal.
- Window foreground synchronization when both windows are open.

