#!/usr/bin/env python3
"""Gate: AVR32DD20 ATDF NVM geometry and command-first encodings.

Proves the vendored ATDF still matches what nvmctrl.zig / capabilities.zig
assume:

  - PROGMEM / MAPPED_PROGMEM pagesize 0x200 (512 B), mapped at 0x8000
  - EEPROM pagesize 0x1 (byte), 0x100 bytes at 0x1400
  - NVMCTRL_CMD includes FLWR/FLPER/EEERWR/EECHER and NOT tinyAVR PAGEERASEWRITE

DS40002413 Table 8-1 / 8-3 and section 11.3.2.3.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


def memory_segment(atdf: str, name: str) -> str:
    # Attributes may span multiple lines before the '/>' or nested close.
    pat = re.compile(
        rf'<memory-segment\b[^>]*?\bname="{re.escape(name)}"[^>]*?/>',
        re.S,
    )
    m = pat.search(atdf)
    if m:
        return m.group(0)
    pat2 = re.compile(
        rf'<memory-segment\b[^>]*?\bname="{re.escape(name)}".*?</memory-segment>',
        re.S,
    )
    m = pat2.search(atdf)
    if not m:
        raise SystemExit(f"missing memory-segment {name}")
    return m.group(0)


def attr(block: str, key: str) -> str:
    m = re.search(rf'\b{re.escape(key)}="([^"]+)"', block)
    if not m:
        raise SystemExit(f"missing attribute {key} in segment block")
    return m.group(1)


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    atdf_path = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        root / "port/microchip/avrdx/vendor/atdf/AVR32DD20.atdf"
    )
    atdf = atdf_path.read_text(encoding="utf-8")

    flash = memory_segment(atdf, "PROGMEM")
    mapped = memory_segment(atdf, "MAPPED_PROGMEM")
    ee = memory_segment(atdf, "EEPROM")

    checks = [
        (attr(flash, "pagesize"), "0x200", "PROGMEM pagesize"),
        (attr(flash, "size"), "0x8000", "PROGMEM size"),
        (attr(mapped, "pagesize"), "0x200", "MAPPED_PROGMEM pagesize"),
        (attr(mapped, "start"), "0x8000", "MAPPED_PROGMEM start"),
        (attr(mapped, "size"), "0x8000", "MAPPED_PROGMEM size"),
        (attr(ee, "pagesize"), "0x1", "EEPROM pagesize"),
        (attr(ee, "start"), "0x1400", "EEPROM start"),
        (attr(ee, "size"), "0x100", "EEPROM size"),
    ]
    for got, want, label in checks:
        if got.lower() != want.lower():
            print(f"FAIL: {label}={got}, expected {want}")
            return 1
        print(f"ok: {label}={got}")

    vg = re.search(
        r'<value-group[^>]*\bname="NVMCTRL_CMD"(.*?)</value-group>',
        atdf,
        re.S,
    )
    if not vg:
        print("FAIL: NVMCTRL_CMD value-group missing")
        return 1
    cmds = {
        name: value.lower()
        for name, value in re.findall(
            r'\bname="([A-Z0-9_]+)"[^>]*\bvalue="(0x[0-9A-Fa-f]+)"',
            vg.group(1),
        )
    }
    need = {
        "NONE": "0x00",
        "NOOP": "0x01",
        "FLWR": "0x02",
        "FLPER": "0x08",
        "EEWR": "0x12",
        "EEERWR": "0x13",
        "EECHER": "0x30",
    }
    for name, value in need.items():
        if cmds.get(name) != value:
            print(f"FAIL: NVMCTRL_CMD.{name}={cmds.get(name)}, expected {value}")
            return 1
        print(f"ok: NVMCTRL_CMD.{name}={value}")

    if "PAGEERASEWRITE" in cmds:
        print("FAIL: tinyAVR PAGEERASEWRITE present in AVR Dx NVMCTRL_CMD")
        return 1
    print("ok: PAGEERASEWRITE absent (command-first Dx model)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
