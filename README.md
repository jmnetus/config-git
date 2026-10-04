# KDE Plasma Customizations & Dotfiles

This repository contains custom KDE Plasma configuration and scripts for personal backup and deployment across systems.

It's probably not very useful to you but I'm leaving it public in case you find a use for it. Some of it is AI generated, deal with it.


## Included Customizations

1. **`hide-application` (KWin Script)**
   - **Location**: `.local/share/kwin/scripts/hide-application/`
   - **Shortcut**: `Meta+H` (macOS `Cmd+H` equivalent)
   - **Functionality**:
     - Hides (minimizes) all open windows belonging to the currently active application.
     - Preserves window focus order by minimizing background siblings before the active window.
     - Restores all sibling windows together when any window of the application is unminimized.
     - Works seamlessly whether restored via taskbar icon click (restoring previous focus) or Alt-Tab switcher (restoring the user-selected window).

2. **Thunderbird Window Rule**
   - **Location**: `.config/kwinrulesrc`
   - **Functionality**: Fixes generic Wayland icon and taskbar grouping mismatch for Thunderbird by mapping `wmclass=Thunderbird` to `desktopfile=thunderbird`.

## Installation

To deploy on this or a new computer:

```bash
cd ~/config-git
./install.sh
```

The script will:
- Back up any existing config files before touching them.
- Symlink the KWin script directory to `~/.local/share/kwin/scripts/hide-application`.
- Symlink `~/.config/kwinrulesrc`.
- Automatically register and enable `hide-application` and `Meta+H` via `kwriteconfig6`.
- Reload KWin and shortcuts live without requiring a restart or log out.
