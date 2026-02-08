# Changelog

All notable changes to Wored will be documented in this file.

## [0.2.0] - 2026-02-08

### Added

- Settings Panel with radiusless design (280x460).
- Audio Settings: Crossfade duration (0-5s) and EQ Presets.
- UI Settings: "Always on Top" toggle, Theme selection (System/Light/Dark).
- System Settings: Launch at Startup toggle, Language selection (System/TR/EN).
- Custom `SquareSlider` component for consistent "knob" style.
- Dynamic color support for theming.

### Changed

- Player window padding reduced to uniform 5px.
- Settings panel positioning logic (side-by-side with player).
- Playlist actions separated from header with a divider line.
- Refactored `AudioPlayerViewModel` to singleton pattern.
- Updated `Localization` logic to prioritize user preference.

### Fixed

- "Always on Top" window level behavior utilizing `WindowManager`.
- Layout inconsistencies in Player and Playlist views.

## [0.1.1] - 2026-02-05

### Added

- App icon set and product name normalized to Wored.
- Playlist docking to player with width lock and height persistence.
- Playlist visibility persistence across launches.
- Shuffle and repeat persistence across launches.
- Borderless Info panel with website link.
- Reliable tooltips on playlist header actions.

### Changed

- Playlist now opens below player and moves as a child window (no drag).
- Foreground sync strengthened when switching between windows.
- Minimal UI layout kept tight with square sliders and 10px knobs.

### Fixed

- Playlist reopening state now respects last visible state.
- Slider knob alignment to track start.

### Removed

- Mini player mode.
- Pin/unpin behavior.
- Playlist search bar.

## [0.1.0] - 2026-02-04

### Added

- Separate playlist window with show/hide toggle and resizable layout.
- Menu bar controls.
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
