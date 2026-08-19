### Cleankey: Keyboard Cleaning Made Easy
Cleankey is a tiny, free macOS menu bar app that temporarily locks your keyboard so you can wipe down the keys without triggering accidental keystrokes. Flip the toggle to clean off your greasy fingers from your keyboard and be happy.

![Cleankey demo, toggling keyboard lock on and off from the macOS menu bar to clean a keyboard safely](CleankeyDemo.gif)

### But why?
Wiping down a Mac keyboard normally fires off a storm of keystrokes. Apps open, text disappears, the volume jumps, you write your ex. Cleankey blocks **all** keyboard input system-wide with a single toggle, so you can clean your greasy keys safely and at peace.

### How it works
Cleankey installs a system-wide event tap at the HID level and catches key events before they reach any app. While blocking is active, Cleankey drops every keystroke, including modifier keys and media keys like play/pause and volume. Toggle it off and everything returns to normal. Your trackpad keeps working all the time, so you can easily enable your keyboard again.

### Two permissions on system-level are required for the application to work:
- **Device Control and Data Acces** (called **Accessibility** on macOS 26 and earlier) lets Cleankey suppress all key events
- **Input Monitoring** lets Cleankey receive the key events

### Requirements
- macOS 13.0 (Ventura) or later
- Works on Apple Silicon and Intel Macs

### Languages
Cleankey automatically follows your selected OS language. The interface currently supports English, German, French, Spanish, Simplified Chinese, Italian, Russian and Japanese.

### Installation
Two options:
1. Download the .zip archive from the "Releases" section here and drop `Cleankey.app` into `/Applications` (or wherever you want).
2. Download the whole repository, build the project in Xcode and drop `Cleankey.app` into your `/Applications` folder.

### FAQ

#### How do I unlock my keyboard again?
Click the Cleankey icon in the menu bar and flip the toggle off. Your mouse and trackpad keep working the whole time it is locked, so you always have a way back.

#### Does Cleankey record what I type?
No. Cleankey throws key events away while the lock is on. It never reads them, saves them or sends them anywhere, and it does nothing at all while the lock is off.

#### The toggle cannot be toggled. What is wrong?
You did not grant both permissions yet, so Cleankey cannot activate it's keyboard lock. The menu tells you which one is missing. Grant it, then quit Cleankey and open it again, because macOS applies new permissions only on a fresh launch.

Made by [Nick Ringelmann](https://nickringelmann.com)