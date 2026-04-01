# Changelog

All notable changes to Wored will be documented in this file.

## [0.5.0] - 2026-04-02 00:50

### Added

- Feature to add songs or folders directly from Finder via drag and drop into the PlaylistView.

### Changed

- Reversed the track information format in the playlist to show "Artist Name • Song Title" instead of "Title • Artist Name" order.

## [0.4.1] - 2026-04-01 23:20

### Fixed

- Fixed sandbox permission bug where adding a folder directly caused "access denied" errors for contained files.

### Added

- Added `docs/`, `documents/`, and LLM tool folders to `.gitignore`.

## [0.4.0] - 2026-04-01 23:00

### Added

- Multiple playlist support with create, rename, and delete operations.
- Playlist picker in header for switching between playlists.
- Playlist management menu (folder icon) with context-aware actions.
- "Add to Playlist" submenu in song context menu for cross-playlist operations.
- `PlaylistNameSheet` component for create/rename dialogs.
- `Playlist`, `PlaylistCollection`, `LegacySavedPlaylist` data models.
- `wored.entitlements` file with `com.apple.security.files.bookmarks.app-scope`.
- 8 new localization keys for playlist management (TR + EN).

### Changed

- Playlist persistence rewritten to `PlaylistCollection` format (version 2).
- Legacy single-playlist format auto-migrates to multi-playlist on first load.
- Default playlist is created automatically on first launch and cannot be deleted.
- `AudioPlayerViewModel` now manages `playlists` array and `activePlaylistId`.
- Bookmark resolution in `loadPlaylist` now retains `startAccessingSecurityScopedResource()` access.

### Fixed

- Songs no longer require re-selection via Finder after app restart (sandbox bookmark persistence).
- Security-scoped resource access now properly retained in `activeSecurityURLs` during playlist load.

## [0.3.0] - 2026-04-01 20:30

### Changed

- Refactored monolithic codebase into modular architecture (4 files to 17 files).
- Extracted `Song`, `SavedSong`, `SavedPlaylist`, `PlayerError`, `CachedMetadata` into `Models/Song.swift`.
- Extracted `RepeatMode`, `EQPreset`, `AppTheme`, `AppLanguage` into `Models/Enums.swift`.
- Extracted Color/NSColor palette into `Extensions/Color+App.swift`.
- Extracted `WindowManager` into `App/WindowManager.swift`.
- Extracted `PlayerWindowAccessor`, `PlaylistWindowAccessor` into `App/WindowAccessors.swift`.
- Extracted `PlayerView` into `Views/PlayerView.swift`.
- Extracted `PlaylistView`, `SongDropDelegate` into `Views/PlaylistView.swift`.
- Extracted `SettingsPanelView`, `SectionHeader`, `SettingsRow`, `InfoPanelController`, `InfoPanelButton` into `Views/SettingsPanelView.swift`.
- Extracted `MenuBarView` into `Views/MenuBarView.swift`.
- Extracted `SquareSlider`, `TrackingSlider`, `SquareSliderCell` into `Views/Components/SquareSlider.swift`.
- Extracted `MarqueeText` into `Views/Components/MarqueeText.swift`.
- Extracted `TooltippedView` into `Views/Components/TooltippedView.swift`.
- Extracted `ScrollableView`, `PopoverWindowAccessor` into `Views/Components/ScrollableView.swift`.
- Moved `Localization.swift` into `Localization/` directory.
- Slimmed `woredApp.swift` to App entry point only (45 lines).
- Removed model/enum definitions from `AudioPlayerViewModel.swift` (1604 to 1479 lines).
- Updated Xcode project structure to reflect new file organization.

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
