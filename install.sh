#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

echo "==> Installing customizations from $SCRIPT_DIR"

link_item() {
    local src="$1"
    local dst="$2"

    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        echo "  [OK] Already linked: $dst -> $src"
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
        echo "  [BACKUP] Existing $dst moved to $backup"
        mv "$dst" "$backup"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    echo "  [LINK] Created symlink: $dst -> $src"
}

# 1. Symlink KWin script
link_item "$SCRIPT_DIR/.local/share/kwin/scripts/hide-application" "$DATA_DIR/kwin/scripts/hide-application"

# 2. Symlink KWin window rules
link_item "$SCRIPT_DIR/.config/kwinrulesrc" "$CONFIG_DIR/kwinrulesrc"

# 3. Configure KWin plugin and shortcut
KWRITECONFIG=""
if command -v kwriteconfig6 >/dev/null 2>&1; then
    KWRITECONFIG="kwriteconfig6"
elif command -v kwriteconfig5 >/dev/null 2>&1; then
    KWRITECONFIG="kwriteconfig5"
fi

if [ -n "$KWRITECONFIG" ]; then
    echo "==> Configuring KWin plugin and shortcut via $KWRITECONFIG"
    "$KWRITECONFIG" --file kwinrc --group Plugins --key hide-applicationEnabled true
    "$KWRITECONFIG" --file kglobalshortcutsrc --group kwin --key HideCurrentApp "Meta+H,none,Hide Application (All Windows)"
else
    echo "  [WARN] Neither kwriteconfig6 nor kwriteconfig5 found; please ensure hide-application is enabled in kwinrc"
fi

# 4. Reload KWin and shortcuts if running
echo "==> Reloading KWin and shortcuts..."
qdbus org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig 2>/dev/null || \
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel --method org.kde.KGlobalAccel.reloadConfig >/dev/null 2>&1 || true

qdbus org.kde.KWin /KWin org.kde.KWin.reconfigure 2>/dev/null || \
gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true

qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "hide-application" 2>/dev/null || \
gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.unloadScript "hide-application" >/dev/null 2>&1 || true

qdbus org.kde.KWin /Scripting org.kde.kwin.Scripting.start 2>/dev/null || \
gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.start >/dev/null 2>&1 || true

echo "==> Installation complete!"
