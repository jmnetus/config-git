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

3. **Konsole Terminal Profiles & Settings**
   - **Location**:
     - `.local/share/konsole/`: Terminal profiles (e.g. `Default.profile`), custom color schemes, etc.
     - `.config/konsolerc`: Default profile selection and Konsole UI settings.
     - `.config/konsolesshconfig`: Konsole SSH plugin settings.
   - **Functionality**: Synchronizes terminal profiles, fonts, keybindings, and appearance.

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
- Symlink Konsole profiles directory (`~/.local/share/konsole`) and configuration files (`~/.config/konsolerc`, `~/.config/konsolesshconfig`).
- Automatically register and enable `hide-application` and `Meta+H` via `kwriteconfig6`.
- Reload KWin and shortcuts live without requiring a restart or log out.

## Additional Utilities

These are standalone scripts not run by the main `install.sh` script.

### SDDM HiDPI / Scale Sync (`sync-sddm-dpi.sh`)

KDE Plasma Wayland does not automatically propagate display scaling or DPI to SDDM. This script automatically reads your current Wayland scale (via `kwinoutputconfig.json` / `kscreen-doctor`), calculates the matching font DPI, and writes or updates `/etc/sddm.conf.d/hidpi.conf`.

#### Usage

```bash
# Preview detected scale and generated config without writing
./sync-sddm-dpi.sh --dry-run

# Check if SDDM config is currently in sync
./sync-sddm-dpi.sh --check

# Apply to /etc/sddm.conf.d/hidpi.conf (requests sudo/doas elevation only if needed)
./sync-sddm-dpi.sh
```

#### Options

- `-n`, `--dry-run`: Preview detected settings and generated configuration without writing.
- `-c`, `--check`: Check if `/etc/sddm.conf.d/hidpi.conf` matches current scale (exit code 0 if in sync, 1 if mismatched).
- `-s`, `--scale <val>`: Override scale factor manually (e.g. `1.5`, `2.0`).
- `-d`, `--dpi <val>`: Override DPI manually (e.g. `144`).
- `-o`, `--output <path>`: Write to custom path instead of `/etc/sddm.conf.d/hidpi.conf`.
- `-f`, `--force`: Overwrite configuration even if already matching.
