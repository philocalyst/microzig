#!/bin/sh
# Regenerate port/microchip/avrdx/src/chip/AVR32DD20.zig from the vendored
# ATDF. Run after updating the device pack (and re-running
# verify_avr32dd20_sources.sh), then diff the result: any change must be
# explainable from the ATDF changelog.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATDF="$ROOT/port/microchip/avrdx/vendor/atdf/AVR32DD20.atdf"
OUT="$ROOT/port/microchip/avrdx/src/chip"

REGZ="${REGZ:-$ROOT/tools/regz/zig-out/bin/regz}"
if [ ! -x "$REGZ" ]; then
    echo "building regz (set REGZ=... to override)..." >&2
    (cd "$ROOT/tools/regz" && zig build -Doptimize=ReleaseSafe)
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

"$REGZ" --format atdf --output_path "$tmp" --device AVR32DD20 "$ATDF"

# regz writes <name>.zig plus a types/ directory; move them into place.
rm -rf "$OUT.new"
mkdir -p "$OUT.new"
cp "$tmp/AVR32DD20.zig/AVR32DD20.zig" "$OUT.new/"
cp -r "$tmp/AVR32DD20.zig/types" "$OUT.new/"

diff -ru "$OUT" "$OUT.new" || true
echo "--- review the diff above, then:"
echo "  rm -rf $OUT && mv $OUT.new $OUT"
