# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-08-10

### Added

- Popover width can be dragged to resize; the width is remembered across launches.

### Fixed

- The popover now shrinks back down after exiting edit mode.
- Space list heights are measured reliably so wrapped descriptions no longer leave a scrollbar sliver.
- Aligned paddings across the popover (current Space row, Space list, footer) and cleared the resize handle from the footer's menu.

## [0.1.2] - 2026-08-10

### Added

- Labeled and terminal links in notes: `[label](url-or-folder)` renders as a clickable `label` that opens a URL in the browser or a folder in Terminal.app.
- Version shown in the popover footer and a Settings menu item.

### Changed

- Notes links now show hover feedback (pointing hand + tooltip) and stay plain text while editing.

## [0.1.1] - 2026-08-10

### Added

- Per-Space identity: give each Space a name and a custom icon.
- Read-only by default, edit on demand: hover to reveal a pencil, then Done to save or Cancel to discard.
- Notes per Space with plain-text highlighting.
- Automatic URL detection in notes (clickable links).
- Backup & restore: export Spaces (names, icons, notes) to a file and import them again.
- Manage unavailable Spaces: see them listed, add per-Space descriptions, clean up or save/clear them.
- Settings screen with an About line.

### Changed

- Reworked the icon picker and notes editor.
- Space actions moved into the current-Space hover menu.
- Replaced thumbnail capture with file-based per-Space backups.
- Collapsed the footer into a single menu; Screen Recording access no longer re-requested on launch.
- Unified the menu into a read-only Space list with opt-in per-row editing.

### Fixed

- Icon picker scrim overlay was blocking clicks and clipping the grid.
