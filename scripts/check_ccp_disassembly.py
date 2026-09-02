#!/usr/bin/env python3
"""Prove CCP write adjacency in a built AVR32DD20 firmware image.

Gate for plan.md Phase 3: every CPU.CCP write (the `out 0x14, rX` store of the
signature) must be immediately preceded by an ldi of the signature into that
same register and followed by the protected sts. One inline-assembly statement
in ccp.zig guarantees this; this script checks the real binary.

llvm's AVR disassembler lacks avrxmega3 sts decoding and prints "<unknown>",
so sts is recognized from its opcode bytes: word1 == 0x93.
"""
import os
import re
import shutil
import subprocess
import sys

def resolve_objdump():
    env = os.environ.get('OBJDUMP') or os.environ.get('LLVM_OBJDUMP')
    if env and os.path.isfile(env) and os.access(env, os.X_OK):
        return env
    for candidate in (
        '/opt/homebrew/opt/llvm/bin/llvm-objdump',
        '/usr/local/opt/llvm/bin/llvm-objdump',
        shutil.which('llvm-objdump'),
        shutil.which('objdump'),
    ):
        if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    sys.exit('llvm-objdump not found; set OBJDUMP=...')

elf = sys.argv[1] if len(sys.argv) > 1 else 'zig-out/firmware/avr32dd20_blinky.elf'
r = subprocess.run([resolve_objdump(), '-d', elf],
                   capture_output=True, text=True)
lines = r.stdout.splitlines()


def parse(line):
    m = re.search(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*(.*)$', line)
    if not m:
        return None
    words = bytes.fromhex(m.group(2).replace(' ', ''))
    return words, m.group(3).strip(), line.strip()


def is_sts(words):
    # sts K, rR encodes as 1001 001r rrrr 0000 | K.
    # Little-endian bytes b: b[1]&0xFC==0x90 selects the 0b100100 prefix and
    # b[0]&0x0F==0 the trailing zero nibble; covers r0..r31.
    return (len(words) >= 2 and (words[1] & 0xFC) == 0x90
            and (words[0] & 0x0F) == 0x00 and len(words) >= 4)


found = ok = 0
parsed = [parse(l) for l in lines]
for i, cur in enumerate(parsed):
    if not cur or not cur[1].startswith('out') or '0x14,' not in cur[2]:
        continue
    found += 1
    sig = re.search(r'out\s+0x14,\s*(r\d+)', cur[2]).group(1)
    prev = parsed[i - 1] if i else None
    nxt = parsed[i + 1] if i + 1 < len(parsed) else None

    prev_ok = False
    if prev is not None:
        m = re.search(r'ldi\s+(r\d+)', prev[2])
        prev_ok = m is not None and m.group(1) == sig
    next_ok = nxt is not None and is_sts(nxt[0])

    if prev_ok and next_ok:
        ok += 1
        print('OK : %s | %s | %s' % (prev[2], cur[2], 'sts ...'))
    else:
        print('BAD: %s' % cur[2])
        print('     prev=%r next=%r' % (prev[2] if prev else None,
                                        nxt[2] if nxt else None))

print('%d/%d CCP sequences have ldi->out->sts adjacency in %s' %
      (ok, found, elf))
sys.exit(0 if found > 0 and ok == found else 1)
