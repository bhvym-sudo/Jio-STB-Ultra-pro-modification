#!/usr/bin/env bash
# Reversibly disable likely Jio ad/promo components for Android user 0.
# This does not remove APKs from the read-only system image or require root.
# Usage: bash adb-debloat-jio.sh [--dry-run|--apply|--restore]

set -uo pipefail

ACTION="${1:---dry-run}"
case "$ACTION" in
    --dry-run|--apply|--restore) ;;
    *) echo "Usage: $0 [--dry-run|--apply|--restore]" >&2; exit 2 ;;
esac

ADB_BIN="${ADB_BIN:-adb}"
ADB_SERIAL="${ADB_SERIAL:-}"

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
    echo "adb not found; install Android platform-tools or set ADB_BIN." >&2
    exit 1
fi

if [ -z "$ADB_SERIAL" ]; then
    mapfile -t DEVICES < <("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" {print $1}')
    if [ "${#DEVICES[@]}" -ne 1 ]; then
        echo "Expected exactly one authorized ADB device; found ${#DEVICES[@]}." >&2
        echo "Set ADB_SERIAL=<serial> and retry." >&2
        exit 1
    fi
    ADB_SERIAL="${DEVICES[0]}"
fi

adb_stb() { "$ADB_BIN" -s "$ADB_SERIAL" "$@"; }

# Evidence-based, conservative targets: launcher and named ad/screensaver modules.
# JioService, SDK, TR-069, command receiver, app optimizer, networking, and TV
# input packages are intentionally excluded because disabling them may break core
# setup, remote control, playback, or device management.
TARGETS=(
    com.jio.adc.embedded
    com.jio.adc.aka
    com.jio.screensaver
    com.iwedia.ui.rjio.launcher.reliance
)
MONET="com.klevico.monet"
MONET_HOME="com.klevico.monet/.HomeActivity"

if ! adb_stb get-state >/dev/null 2>&1; then
    echo "ADB device $ADB_SERIAL is not online/authorized." >&2
    exit 1
fi

PACKAGE_LIST="$(adb_stb shell pm list packages --user 0 | tr -d '\r')"
is_installed() { grep -Fxq "package:$1" <<< "$PACKAGE_LIST"; }
is_disabled() { adb_stb shell pm list packages -d --user 0 | tr -d '\r' | grep -Fxq "package:$1"; }

if ! is_installed "$MONET"; then
    echo "Monet ($MONET) is not installed for user 0; refusing to touch the stock launcher." >&2
    exit 1
fi

ACTIVE_TARGETS=()
for pkg in "${TARGETS[@]}"; do
    if is_installed "$pkg"; then ACTIVE_TARGETS+=("$pkg"); fi
done

echo "ADB device: $ADB_SERIAL"
echo "Action: $ACTION"
if [ "${#ACTIVE_TARGETS[@]}" -eq 0 ]; then
    echo "No target packages are installed for user 0."
    exit 0
fi

if [ "$ACTION" = "--dry-run" ]; then
    for pkg in "${ACTIVE_TARGETS[@]}"; do
        if is_disabled "$pkg"; then state="already disabled"; else state="would disable"; fi
        echo "  $state: $pkg"
    done
    echo "No changes made. Run with --apply to disable these packages for user 0."
    exit 0
fi

if [ "$ACTION" = "--apply" ]; then
    echo "Setting Monet as Home before disabling the stock launcher..."
    if ! adb_stb shell cmd package set-home-activity "$MONET_HOME"; then
        echo "Could not set Monet as Home; aborting without disabling packages." >&2
        exit 1
    fi
    if ! adb_stb shell am start -n "$MONET_HOME"; then
        echo "Could not launch Monet; aborting without disabling packages." >&2
        exit 1
    fi
    for pkg in "${ACTIVE_TARGETS[@]}"; do
        if is_disabled "$pkg"; then
            echo "Already disabled: $pkg"
            continue
        fi
        echo "Disabling for user 0: $pkg"
        if adb_stb shell pm disable-user --user 0 "$pkg"; then
            if is_disabled "$pkg"; then
                echo "  verified disabled"
            else
                echo "  command returned but package is not listed disabled" >&2
            fi
        else
            echo "  FAILED (left unchanged if package manager rejected it)" >&2
        fi
    done
    adb_stb shell input keyevent 3 || true
    exit 0
fi

for pkg in "${TARGETS[@]}"; do
    if ! is_installed "$pkg"; then
        echo "Not installed for user 0; skip restore: $pkg"
        continue
    fi
    echo "Enabling for user 0: $pkg"
    adb_stb shell pm enable --user 0 "$pkg" || echo "  FAILED to enable $pkg" >&2
done
echo "Restore pass complete."
