#!/usr/bin/env bash
#
# sync-sddm-dpi.sh - Synchronize SDDM display scaling & font DPI with KDE Plasma Wayland settings
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_CONF="/etc/sddm.conf.d/hidpi.conf"
DRY_RUN=0
CHECK_ONLY=0
FORCE=0
MANUAL_SCALE=""
MANUAL_DPI=""

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Synchronizes SDDM display scale and font DPI to match KDE Plasma Wayland configuration.

Options:
  -s, --scale <factor>   Override display scale factor (e.g. 1.25, 1.5, 2.0)
  -d, --dpi <dpi>        Override font DPI (e.g. 120, 144, 192)
  -o, --output <path>    Target SDDM config file (default: $TARGET_CONF)
  -n, --dry-run          Preview the generated configuration without writing
  -c, --check            Check if SDDM config is in sync (exits 0 if up to date, 1 if not)
  -f, --force            Force write even if configuration already matches
  -h, --help             Show this help message
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -s|--scale)
            MANUAL_SCALE="$2"
            shift 2
            ;;
        -d|--dpi)
            MANUAL_DPI="$2"
            shift 2
            ;;
        -o|--output)
            TARGET_CONF="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        -c|--check)
            CHECK_ONLY=1
            shift
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            print_usage >&2
            exit 1
            ;;
    esac
done

# Detect user and home directory (handles sudo/doas elevation)
TARGET_USER="${SUDO_USER:-${DOAS_USER:-${USER:-$(id -un)}}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"
if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
    TARGET_HOME="$HOME"
fi

# Detect display scale and DPI via Python helper
DETECTED_JSON=$(python3 - "$TARGET_HOME" "$MANUAL_SCALE" "$MANUAL_DPI" <<'EOF'
import json
import math
import os
import subprocess
import sys

target_home = sys.argv[1]
manual_scale_arg = sys.argv[2]
manual_dpi_arg = sys.argv[3]

def detect():
    # 1. Manual scale override
    if manual_scale_arg:
        try:
            scale = float(manual_scale_arg)
            dpi = int(manual_dpi_arg) if manual_dpi_arg else int(round(scale * 96))
            return scale, dpi, "manual argument"
        except ValueError:
            pass

    # 2. Manual DPI override
    if manual_dpi_arg:
        try:
            dpi = int(manual_dpi_arg)
            scale = float(manual_scale_arg) if manual_scale_arg else (dpi / 96.0)
            return scale, dpi, "manual argument"
        except ValueError:
            pass

    # 3. kscreen-doctor (live Wayland session)
    if ("WAYLAND_DISPLAY" in os.environ or "DISPLAY" in os.environ) and shutil_which("kscreen-doctor"):
        try:
            res = subprocess.run(["kscreen-doctor", "-o"], capture_output=True, text=True, timeout=3)
            if res.returncode == 0:
                lines = res.stdout.splitlines()
                scale_for_output = None
                enabled = False
                for line in lines:
                    line_s = line.strip()
                    if line_s.startswith("Output:"):
                        if enabled and scale_for_output is not None:
                            dpi = int(round(scale_for_output * 96))
                            return scale_for_output, dpi, "kscreen-doctor (active session)"
                        enabled = False
                        scale_for_output = None
                    elif line_s == "enabled":
                        enabled = True
                    elif line_s.startswith("Scale:"):
                        try:
                            scale_for_output = float(line_s.split()[1])
                        except Exception:
                            pass
                if enabled and scale_for_output is not None:
                    dpi = int(round(scale_for_output * 96))
                    return scale_for_output, dpi, "kscreen-doctor (active session)"
        except Exception:
            pass

    # 4. ~/.config/kwinoutputconfig.json (KDE Plasma Wayland output config)
    cfg_path = os.path.join(target_home, ".config", "kwinoutputconfig.json")
    if os.path.exists(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                data = json.load(f)

            outputs_map = {}
            for sec in data:
                if sec.get("name") == "outputs":
                    for idx, out in enumerate(sec.get("data", [])):
                        outputs_map[idx] = out.get("scale", 1.0)
                        if "connectorName" in out:
                            outputs_map[out["connectorName"]] = out.get("scale", 1.0)

            for sec in data:
                if sec.get("name") == "setups":
                    for setup in sec.get("data", []):
                        if not setup.get("lidClosed", False):
                            outs = sorted(setup.get("outputs", []), key=lambda x: x.get("priority", 999))
                            for o in outs:
                                if o.get("enabled", False):
                                    idx = o.get("outputIndex", 0)
                                    if idx in outputs_map:
                                        scale = float(outputs_map[idx])
                                        dpi = int(round(scale * 96))
                                        return scale, dpi, f"{cfg_path} (setups primary)"

            for sec in data:
                if sec.get("name") == "outputs":
                    outs = sec.get("data", [])
                    if outs:
                        scale = float(outs[0].get("scale", 1.0))
                        dpi = int(round(scale * 96))
                        return scale, dpi, f"{cfg_path} (first output)"
        except Exception:
            pass

    # 5. ~/.config/kcmfonts (forceFontDPI)
    fonts_path = os.path.join(target_home, ".config", "kcmfonts")
    if os.path.exists(fonts_path):
        try:
            with open(fonts_path, "r", encoding="utf-8") as f:
                for line in f:
                    if line.strip().startswith("forceFontDPI="):
                        val = int(line.strip().split("=")[1])
                        if val > 0:
                            return (val / 96.0), val, f"{fonts_path} (forceFontDPI)"
        except Exception:
            pass

    return 1.0, 96, "default fallback (1.0 scale)"

def shutil_which(cmd):
    import shutil
    return shutil.which(cmd) is not None

scale, dpi, source = detect()
print(json.dumps({"scale": scale, "dpi": dpi, "source": source}))
EOF
)

SCALE=$(python3 -c "import json; d = json.loads('''$DETECTED_JSON'''); print(f\"{d['scale']:g}\")")
DPI=$(python3 -c "import json; d = json.loads('''$DETECTED_JSON'''); print(d['dpi'])")
SOURCE=$(python3 -c "import json; d = json.loads('''$DETECTED_JSON'''); print(d['source'])")

GENERATED_CONFIG="[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=${SCALE},QT_FONT_DPI=${DPI}

[X11]
EnableHiDPI=true
ServerArguments=-nolisten tcp -dpi ${DPI}
"

# Check if target directory and file are writable without elevation
can_write_target() {
    local dir="$1"
    local file="$2"
    while [ ! -d "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        dir="$(dirname "$dir")"
    done
    if [ ! -w "$dir" ]; then
        return 1
    fi
    if [ -e "$file" ] && [ ! -w "$file" ]; then
        return 1
    fi
    return 0
}

# Helper for elevated execution if not writable by current user
run_elevated() {
    if can_write_target "$TARGET_DIR" "$TARGET_CONF"; then
        "$@"
    elif [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas "$@"
    else
        echo "Error: Root privileges required to write to $TARGET_CONF, but neither sudo nor doas is available." >&2
        echo "Please re-run this script as root." >&2
        exit 1
    fi
}

check_in_sync() {
    if [ ! -f "$TARGET_CONF" ]; then
        return 1
    fi
    local existing
    existing="$(grep -v '^[[:space:]]*#' "$TARGET_CONF" | grep -v '^[[:space:]]*$' || true)"
    local expected
    expected="$(echo "$GENERATED_CONFIG" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' || true)"
    [ "$existing" = "$expected" ]
}

if [ "$CHECK_ONLY" -eq 1 ]; then
    if check_in_sync; then
        echo "[IN SYNC] $TARGET_CONF matches detected scale $SCALE (${DPI} DPI) from $SOURCE"
        exit 0
    else
        echo "[MISMATCH] $TARGET_CONF differs from detected scale $SCALE (${DPI} DPI) from $SOURCE"
        exit 1
    fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
    echo "==> Detected scale: $SCALE (${DPI} DPI) from $SOURCE"
    echo "==> Target file:    $TARGET_CONF"
    echo "==> Configuration preview:"
    echo "----------------------------------------"
    printf "%s" "$GENERATED_CONFIG"
    echo "----------------------------------------"
    if check_in_sync; then
        echo "Target file is already in sync. No changes needed."
    else
        echo "Target file differs or does not exist. Run without --dry-run to apply."
    fi
    exit 0
fi

if check_in_sync && [ "$FORCE" -eq 0 ]; then
    echo "[OK] SDDM configuration in $TARGET_CONF is already up to date (Scale: $SCALE, DPI: $DPI from $SOURCE)."
    exit 0
fi

echo "==> Detected scale: $SCALE (${DPI} DPI) from $SOURCE"
echo "==> Writing configuration to $TARGET_CONF..."

TMP_FILE="$(mktemp)"
printf "%s" "$GENERATED_CONFIG" > "$TMP_FILE"

TARGET_DIR="$(dirname "$TARGET_CONF")"
if [ ! -d "$TARGET_DIR" ]; then
    run_elevated mkdir -p "$TARGET_DIR"
fi

if [ -f "$TARGET_CONF" ]; then
    BACKUP="${TARGET_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    echo "  [BACKUP] Backing up existing $TARGET_CONF -> $BACKUP"
    run_elevated cp "$TARGET_CONF" "$BACKUP"
fi

run_elevated cp "$TMP_FILE" "$TARGET_CONF"
run_elevated chmod 644 "$TARGET_CONF"
rm -f "$TMP_FILE"

echo "==> Successfully updated $TARGET_CONF"
