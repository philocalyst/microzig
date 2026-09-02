#!/bin/sh
# Citation checker for the AVR32DD20 port.
#
# Rules enforced:
#   1. Every `...DS40002413.pdf#page=N` anchor in the HAL sources must be part
#      of a full citation that names a section number and quoted title.
#   2. Every onlinedocs.microchip.com GUID URL cited from code must be listed
#      in port/microchip/avrdx/docs/avr32dd20-sources.zon so there is one
#      canonical place per fact.
#   3. With ONLINE=1: every GUID URL is fetched and must return HTTP 200
#      (run periodically; regular CI uses the pinned manifest instead).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/port/microchip/avrdx/src/hals"
MANIFEST="$ROOT/port/microchip/avrdx/docs/avr32dd20-sources.zon"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

status=0

# Rule 1: #page= anchors need a section+title next to them.
# A valid citation looks like:
#   //! DS40002413 section 12.3.2 "Main Clock Selection", page 90.
#   //! https://...DS40002413.pdf#page=90
page_anchors=$(grep -rn "https://ww1.microchip.com/.*DS40002413.pdf#page=[0-9]" "$SRC" | cut -d: -f1 | sort -u)
for f in $page_anchors; do
    if ! grep -q 'section [0-9][0-9.]* "[^"][^"]*"' "$f"; then
        echo "FAIL: $f cites pdf#page= without a section/\"title\" citation"
        status=1
    fi
done
[ "$status" = 0 ] && echo "ok: all #page= anchors carry section titles"

# Rule 2: GUID URLs used in code must exist in the manifest.
for url in $(grep -rho 'https://onlinedocs\.microchip\.com[^ )"]*' "$SRC" | sort -u); do
    grep -qF "$url" "$MANIFEST" || {
        echo "FAIL: GUID URL not in manifest: $url"
        status=1
    }
done
[ "$status" = 0 ] && echo "ok: all GUID URLs recorded in manifest"

# Rule 3 (opt-in): live URL validation.
if [ "${ONLINE:-0}" = "1" ]; then
    for url in $(grep -o 'guid_url = "[^"]*"' "$MANIFEST" | sed 's/guid_url = "//; s/"//'); do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$url")
        [ "$code" = "200" ] || fail "GUID URL returned $code: $url"
        echo "ok 200: $url"
    done
fi

[ "$status" = 0 ] || exit 1
echo "citation checks passed"
