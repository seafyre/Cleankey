<img src="Cleankey/Assets.xcassets/AppIcon.appiconset/iconMacOS (128px 1x) 1.png" width="96" alt="Cleankey icon">

# Cleankey

A tiny macOS menu bar app that locks your keyboard so you can clean it without triggering accidental keystrokes.

Flip the toggle on, wipe down the keys at your leisure, flip it off. That's it.

---

## Screenshots

<!-- Add screenshots here -->

---

## How it works

Cleankey installs a system-wide event tap at the HID level, intercepting key events before they reach any app. While blocking is active, all keyboard input — including modifier keys and media keys like play/pause and volume — is silently dropped. Toggle it off and everything returns to normal instantly.

Because it operates at the HID level, Cleankey needs two permissions:

- **Accessibility** — to create the event tap
- **Input Monitoring** — to intercept keyboard events system-wide

Both can be granted in System Settings. Cleankey includes shortcuts to jump straight there.

## Requirements

- macOS 14 (Sonoma) or later

## Installation

Build the project in Xcode and drop `Cleankey.app` into your `/Applications` folder. Cleankey lives entirely in the menu bar — no Dock icon, no app switcher entry.
