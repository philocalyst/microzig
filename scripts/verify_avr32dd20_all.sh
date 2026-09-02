#!/usr/bin/env bash
# AVR32DD20 full verification battery.
#
# One command: formatting, host tests, firmware builds for all six targets
# in ReleaseSmall, machine-code-level checks (vector table, SRAM placement,
# comptime GPIO folding, CCP adjacency), NVM ATDF geometry/command gates,
# provenance and citation gates, page-number verification of every datasheet
# citation in HAL comments, documentation coverage of every public
# declaration, and a naming audit.
#
# Run from the repository root:
#   ./scripts/verify_avr32dd20_all.sh
# Optional env: ZIG=/path/to/zig  OBJDUMP=/path/to/llvm-objdump
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
resolve_zig() {
    if [ -n "${ZIG:-}" ] && [ -x "$ZIG" ]; then
        printf "%s" "$ZIG"
        return 0
    fi
    if command -v zig >/dev/null 2>&1; then
        command -v zig
        return 0
    fi
    echo "FAIL: set ZIG to the pinned 0.17 toolchain (see docs/avr32dd20-sources.zon)" >&2
    exit 1
}
ZIG="$(resolve_zig)"
EXAMPLES="$ROOT/examples/microchip/avrdx"
PORT="$ROOT/port/microchip/avrdx"
FIRMWARE="$EXAMPLES/zig-out/firmware"

pass=0
fail=0

banner() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

record() {
    if [ "$1" -eq 0 ]; then
        pass=$((pass + 1))
        echo "PASS: $2"
    else
        fail=$((fail + 1))
        echo "FAIL: $2"
    fi
}

banner "1/12 zig fmt"
if "$ZIG" fmt --check \
    "$ROOT/port/microchip/avrdx/src/" \
    "$ROOT/core/src/" \
    "$ROOT/examples/microchip/avrdx/src/" >/dev/null 2>&1; then
    record 0 "formatting is canonical"
else
    record 1 "formatting is canonical"
fi

banner "2/12 host test suite"
if ( cd "$PORT" && "$ZIG" build test --summary all ) >/dev/null 2>&1; then
    record 0 "host unit tests (ADC math, CCP windows, avr_rt)"
else
    record 1 "host unit tests failed"
fi

banner "3/12 firmware builds (ReleaseSmall)"
build_failed=0
for ex in blinky pwm_adc usart pit_sleep mvio abi_probe; do
    if ! ( cd "$EXAMPLES" && "$ZIG" build -Doptimize=ReleaseSmall "-Dexample=$ex" ) \
        >/dev/null 2>&1; then
        echo "  build failed: $ex"
        build_failed=1
    fi
done
elf_count=$(ls "$FIRMWARE"/*.elf 2>/dev/null | wc -l | tr -d ' ')
hex_count=$(ls "$FIRMWARE"/*.hex 2>/dev/null | wc -l | tr -d ' ')
if [ "$build_failed" -eq 0 ] && [ "$elf_count" -eq 6 ] && [ "$hex_count" -eq 6 ]; then
    record 0 "6 ELF + 6 HEX artifacts built"
else
    record 1 "expected 6 ELF + 6 HEX artifacts"
fi

banner "4/12 disassembly verification"
if python3 "$ROOT/scripts/check_avr32dd20_disassembly.py" "$FIRMWARE"/*.elf >/dev/null 2>&1; then
    record 0 "vectors, SRAM placement, SBI/CBI folding, CCP adjacency"
else
    record 1 "machine-code checks failed (run the checker verbosely)"
fi

# Behavioral gate: execute the ABI probe on the in-repo aviron emulator
# configured as an AVR32DD20 (avrxmega3). This proves at runtime that the
# compiler's division/multiply lowering matches the register conventions of
# core/src/cpus/avr_rt.zig -- something static checks cannot see.
banner "5/12 runtime ABI emulation (aviron, AVR32DD20)"
AVIRON="$ROOT/sim/aviron/zig-out/bin/aviron"
if [ ! -x "$AVIRON" ]; then
    ( cd "$ROOT/sim/aviron" && "$ZIG" build ) >/dev/null 2>&1
fi
sim_rc=1
if [ -x "$AVIRON" ]; then
    "$AVIRON" --mcu=avr32dd20 "$FIRMWARE/avr32dd20_abi_probe.elf" \
        >/dev/null 2>&1 && sim_rc=0
fi
record "$sim_rc" "avr_rt div/mul results correct under emulation"

banner "6/12 CCP dedicated gate"
if python3 "$ROOT/scripts/check_ccp_disassembly.py" "$FIRMWARE/avr32dd20_blinky.elf" >/dev/null 2>&1; then
    record 0 "CCP ldi->out->sts adjacency (blinky)"
else
    record 1 "CCP adjacency broken"
fi

banner "7/12 citation format audit"
if bash "$ROOT/scripts/check_avr32dd20_citations.sh" >/dev/null 2>&1; then
    record 0 "datasheet citations well-formed"
else
    record 1 "malformed citations found"
fi

banner "8/12 citation page-number audit"
# Resolves every 'section N.N ... page P' claim against where that section
# header actually appears in DS40002413B.
page_summary=$(python3 "$ROOT/scripts/check_avr32dd20_page_numbers.py" | tail -1)
if echo "$page_summary" | grep -q ", 0 mismatched"; then
    record 0 "every cited section/page matches the PDF text ($page_summary)"
else
    record 1 "citation mismatches: $page_summary"
fi

banner "9/12 provenance manifest"
if bash "$ROOT/scripts/verify_avr32dd20_sources.sh" >/dev/null 2>&1; then
    record 0 "pack/ATDF hashes and toolchain pin"
else
    record 1 "provenance mismatch"
fi

banner "10/12 NVM ATDF geometry and command set"
if python3 "$ROOT/scripts/check_avr32dd20_nvm_atdf.py" >/dev/null 2>&1; then
    record 0 "flash 512B / EEPROM byte / Dx commands (no PAGEERASEWRITE)"
else
    record 1 "NVM ATDF geometry/command gate failed"
fi

banner "11/12 documentation coverage"
# Every 'pub fn'/'pub const' must have a doc comment on the line directly
# above it. `grep -v` exits 1 when nothing remains -- which here means zero
# undocumented declarations, i.e. success -- hence `|| true`.
doc_missing=$(awk '
    FNR == 1 { prev = "" }
    /^pub (fn|const) / && prev !~ /^\/\/\// { print FILENAME ":" FNR }
    { prev = $0 }
' "$PORT"/src/hals/avr32dd20/*.zig | grep -v tests.zig || true)
doc_lines=$(printf '%s' "$doc_missing" | grep -c . || true)
if [ "$doc_lines" = "0" ]; then
    record 0 "every public declaration carries a doc comment"
else
    echo "$doc_missing"
    record 1 "$doc_lines public declaration(s) missing doc comments"
fi

banner "12/12 naming audit (no stuttered APIs)"
# Public type aliases must translate generated register spellings into domain
# vocabulary: `adc.Resolution` is fine, an ALL_CAPS `adc.ADC_RESSEL` is not.
raw_exports=$(grep -hE '^pub const [A-Z][A-Z0-9_]* = (gen|microzig\.chip\.types)' \
    "$PORT"/src/hals/avr32dd20/*.zig 2>/dev/null | wc -l || true)
raw_exports=$(echo "$raw_exports" | tr -d ' ')
if [ "$raw_exports" = "0" ]; then
    record 0 "module surfaces use domain names"
else
    record 1 "$raw_exports raw register-file exports found"
fi

printf '\n\033[1m===== %d passed, %d failed =====\033[0m\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
