#!/bin/sh
# Re-derive the provenance recorded in
# port/microchip/avrdx/docs/avr32dd20-sources.zon.
#
#   ./scripts/verify_avr32dd20_sources.sh            # verify vendored ATDF only (offline)
#   WITH_PACK=1 ./scripts/verify_avr32dd20_sources.sh  # also download the pack (~16 MB)
#                                                      # from Microchip and check it too
set -eu

PACK_URL="https://packs.download.microchip.com/Microchip.AVR-Dx_DFP.2.8.343.atpack"
PACK_SHA256="d81af59072e5ac188431e828461eee5c08e6d5f3ace32461328b4da0ec348746"
PACK_SIZE="16766508"
ATDF_SHA256="5b7fc47eed2d281b3c2b6553b2629a8d19195fa62dd9a0288caa92752a8f9d32"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ATDF="$ROOT/port/microchip/avrdx/vendor/atdf/AVR32DD20.atdf"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

[ -f "$ATDF" ] || fail "vendored ATDF missing at $ATDF"

actual=$(shasum -a 256 "$ATDF" | cut -d' ' -f1)
[ "$actual" = "$ATDF_SHA256" ] || fail "vendored ATDF hash $actual != $ATDF_SHA256"
echo "ok: vendored ATDF sha256"

if [ "${WITH_PACK:-0}" = "1" ]; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    echo "downloading pack from Microchip..."
    curl -fsSL --max-time 600 -o "$tmp/pack.atpack" "$PACK_URL" || fail "download failed"

    actual_size=$(wc -c < "$tmp/pack.atpack" | tr -d ' ')
    [ "$actual_size" = "$PACK_SIZE" ] || fail "pack size $actual_size != $PACK_SIZE"
    echo "ok: pack size"

    actual=$(shasum -a 256 "$tmp/pack.atpack" | cut -d' ' -f1)
    [ "$actual" = "$PACK_SHA256" ] || fail "pack sha256 $actual != $PACK_SHA256"
    echo "ok: pack sha256"

    tar xzf "$tmp/pack.atpack" -C "$tmp" atdf/AVR32DD20.atdf
    actual=$(shasum -a 256 "$tmp/atdf/AVR32DD20.atdf" | cut -d' ' -f1)
    [ "$actual" = "$ATDF_SHA256" ] || fail "extracted ATDF $actual != vendored $ATDF_SHA256"
    echo "ok: extracted ATDF matches vendored copy"
fi

echo "all source checks passed"
