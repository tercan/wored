# Changelog

All notable changes to Wored will be documented in this file.

## [0.7.0] - 2026-09-26 20:20

### Added

- Added a theme-aware, radiusless menu bar panel with the Wored W icon and outside-click dismissal.
- Added single-instance protection before loading playback and persisted data.
- Added clickable outline/filled favorite controls in every playlist view.
- Added persistent settings and track-info panel positions, resizable track-info height, and Cmd+W/Ctrl+W panel shortcuts.

### Changed

- Reorganized playlist controls into a compact footer with a top playlist selector and on-demand bottom search.
- Changed the player close button to hide windows while music continues in the background.
- Made player controls clearer in light/dark themes with stable sizes and full hit areas.

### Fixed

- Restored dragging for the player, settings, and track-info windows.
- Fixed search input focus, text selection, spaces, and Turkish character entry.
- Prevented tag-editor focus from jumping back to the title field.
- Kept playlist text vertically aligned while restoring scrolling for overflowing active-track names.
- Restored full-width playlist row separators and consistent audio/play/drag indicators.
- Added explicit vertical resize cursors and handles to playlist and track-info windows.
- Clarified playlist clearing tooltips and shortened the track-info edit button label.
- Extended guarded Spacebar handling to auxiliary panels without interfering with text fields.

## [0.6.0] - 2026-04-28 02:55

### Added

- Added playlist-wide Finder drag-and-drop handling for audio files and folders, including the empty playlist state.
- Added persisted playlist folder sources with a compact "Rescan" action for refreshing long-lived libraries.
- Added import feedback for added songs, skipped duplicate tracks, and unsupported dropped files.
- Added compact playlist search with a no-results state and clear action.
- Added a playlist status strip for track count, visible result count, total duration, selected item, and missing files.
- Added compact Favorites and History playlist views with matching empty states, context-menu removal, and clear-history confirmation.
- Added keyboard shortcuts for playlist search, selected-track playback, playlist creation, queue clearing, and playlist window toggling.
- Added Spacebar play/pause handling for player and playlist windows.
- Added a radiusless rich track info panel with artwork, tag metadata, file details, and technical audio properties.
- Added MP3/ID3 text tag editing for title, artist, album, genre, year, track number, and disc number.
- Added MP3/ID3 artwork editing with choose, remove, and reset controls in the track info panel.

### Changed

- Strengthened duplicate prevention by comparing normalized paths and file resource identifiers during imports.
- Kept new playlist import, drop target, notice, and action surfaces aligned with the existing radiusless UI style.
- Updated saved song metadata to persist path, file size, modification date, and resource identifier hints.
- Extended saved song metadata with album, genre, year, format, bitrate, sample rate, and channel count hints.
- Extended saved song metadata with track and disc number hints.
- Preserved existing non-edited ID3 frames while rewriting text and artwork frames.
- Switched edited ID3 text frames to BOM-marked UTF-16 for broader non-latin character compatibility across MP3 players.
- Opened track information and tag editing in a separate panel.
- Disabled drag reordering while playlist search is active to keep filtered order and queue order predictable.

### Fixed

- Hardened playback transitions with generation tokens so stale scheduled audio callbacks cannot advance playback after a new song, seek, stop, or crossfade.
- Refreshed playlist metadata when audio file tags change, including ID3/MP4 tag parsing, app-activation checks, and manual rescan for playlists without folder sources.
- Reset stopped player node volume to prevent stale audio from leaking into later transitions.
- Kept the currently playing track alive when switching playlist tabs.
- Improved text entry in the tag editor.
- Prevented the launch-at-startup preference from calling `SMAppService` while stored preferences are loading.

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
