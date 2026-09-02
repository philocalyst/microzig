#!/usr/bin/env python3
"""Cross-check every 'section N[.N...] ... page P' claim in HAL comments
against where that section header actually appears in the extracted
datasheet text. Page numbers must match exactly."""
import json
import re
import glob

pm = json.load(open('/var/folders/vf/qpw72bpn65g0y01bnbwf90n80000gn/T/opencode/page_map.json'))
lines = open('/var/folders/vf/qpw72bpn65g0y01bnbwf90n80000gn/T/opencode/ds_full.txt').readlines()

# index of section headers -> page (footer-based)
sec_pages = {}
pat_hdr = re.compile(r'^(1[0-9]|[2-3][0-9])\.([0-9]+(\.[0-9]+)*)(?: ([A-Z].*))?$')
for i, ln in enumerate(lines[5000:], 5000):
    s = ln.strip()
    m = pat_hdr.match(s)
    if m:
        num = m.group(1) + '.' + m.group(2)
        best = 0
        for k, v in pm.items():
            if int(k) <= i and v > best:
                best = v
        sec_pages.setdefault(num, set()).add(best + 1)

claim = re.compile(r'section ((?:1[0-9]|2[0-9]|3[0-9])(?:\.[0-9]+)+)[^p]*?[Pp]age (\d+)')
bad = checked = 0
for f in sorted(glob.glob('port/microchip/avrdx/src/hals/avr32dd20/*.zig')):
    for n, ln in enumerate(open(f).readlines(), 1):
        for m in claim.finditer(ln):
            checked += 1
            sec, claimed = m.group(1), int(m.group(2))
            pages = sec_pages.get(sec)
            if pages is None:
                # register-description sections (e.g. 12.5.11) live outside the
                # body scan range for some chapters; try whole file
                hits = [i for i, l in enumerate(lines) if l.strip().startswith(sec + ' ')]
                pages = set()
                for h in hits:
                    best = 0
                    for k, v in pm.items():
                        if int(k) <= h and v > best:
                            best = v
                    pages.add(best + 1)
            if claimed not in pages:
                bad += 1
                print(f'MISMATCH {f.split("/")[-1]}:{n}: section {sec} claimed p.{claimed},'
                      f' found on {sorted(pages)}')
print(f'\n{checked} citation(s) checked, {bad} mismatched')
