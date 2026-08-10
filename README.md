# Balanced Spaces

A lightweight macOS menu bar app that helps you keep track of what each Space (virtual desktop) is for. It lives quietly in your menu bar, detects which Space you're on, and lets you attach a name, icon, and notes to it — so switching desktops with Ctrl+←/→ always tells you what you're looking at.

## Features

- **Per-Space identity** — give each Space a name and a custom icon so you can tell them apart at a glance.
- **Read-only by default, edit on demand** — the menu shows a clean, plain-text view of the current Space; hover to reveal a pencil, make your changes, then Done to save or Cancel to discard.
- **Notes per Space** — jot down quick notes for each desktop.
- **Text highlighting** — mark up notes with a highlight style to make key parts stand out.
- **Clickable links** — URLs typed into your notes are automatically detected and become clickable.
- **Labeled links** — `[label](url-or-folder)` renders as a clickable `label`, where the target is a URL (opens in your browser) or a folder path like `~/dev/project` (opens Terminal.app in that folder). Hovering shows a pointing-hand cursor and a tooltip with the target. Links only become clickable in the read-only view — while editing they're plain text.
- **Backup & restore** — export your Spaces (names, icons, notes) to a file and import them again, making it easy to back up or move your setup to another Mac.
- **Runs quietly in the background** — no dock icon, no clutter, just a menu bar item.

## Getting Started

1. Build and launch the app:
   ```
   ./scripts/package.sh
   ```
2. Look for the Balanced Spaces icon in your menu bar.
3. Click it to see the current Space, give it a name/icon, and add notes.
4. Switch desktops (Ctrl+←/→) and the menu updates to reflect the new Space.

**Stack:** Swift, SwiftUI, and AppKit, built as a native macOS menu bar app.
