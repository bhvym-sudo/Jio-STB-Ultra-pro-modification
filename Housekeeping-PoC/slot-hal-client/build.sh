#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/build"
mkdir -p "$OUT/classes"
javac --release 8 -d "$OUT/classes" "$HERE/src/BootControlProbe.java"
mkdir -p "$OUT/dex"
d8 --min-api 30 --output "$OUT/dex" "$OUT/classes/BootControlProbe.class"
jar --create --file "$OUT/slot-hal-client.jar" -C "$OUT/dex" classes.dex
echo "$OUT/slot-hal-client.jar"
