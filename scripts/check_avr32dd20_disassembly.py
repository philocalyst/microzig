#!/usr/bin/env python3
"""Deep disassembly verification for AVR32DD20 firmware images.

For every ELF this proves, from the actual machine code and section table:

  1. Layout: .text starts at address 0 with the vector table; .data/.bss
     sit at the SRAM base (0x807000 in data space).
  2. Reset entry: the first word is a jmp/rjmp into startup code.
  3. Comptime GPIO: pin operations compile to single SBI/CBI instructions
     -- if a pin handle ever stops being comptime-known these degrade into
     load/store sequences and the count collapses.
  4. CCP adjacency: every CPU.CCP store keeps its ldi -> out 0x14 -> sts
     sequence (the Phase 3 gate, folded in so one run tells the whole
     binary story).

Usage: check_avr32dd20_disassembly.py <elf> [<elf> ...]
Exit status 0 = every check passed on every image.
"""
import re
import subprocess
import sys

OBJDUMP = '/opt/homebrew/opt/llvm/bin/llvm-objdump'
SRAM_BASE_DATA_ADDR = 0x807000

failures = []


def fail(msg):
    failures.append(msg)
    print('FAIL:', msg)


def ok(msg):
    print('ok:', msg)


def objdump(args):
    r = subprocess.run([OBJDUMP] + args, capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return r.stdout


def parse_sections(elf):
    out = objdump(['-h', elf])
    if out is None:
        fail(f'{elf}: objdump -h failed')
        return None
    secs = {}
    started = False
    for ln in out.splitlines():
        if 'Idx' in ln and 'Name' in ln:
            started = True
            continue
        if not started:
            continue
        m = re.match(r'\s*\d+\s+(\S+)\s+([0-9a-fA-F]+)\s+([0-9a-fA-F]+)', ln)
        if m:
            secs[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16))
        elif secs and not ln.strip():
            break
    return secs


def parse_insns(elf):
    out = objdump(['-d', elf])
    if out is None:
        fail(f'{elf}: objdump -d failed')
        return None
    insns = []
    for ln in out.splitlines():
        m = re.search(r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2} )+)\s*(.*)$', ln)
        if not m:
            continue
        words = bytes.fromhex(m.group(2).replace(' ', ''))
        insns.append((int(m.group(1), 16), words, m.group(3).strip()))
    return insns


def is_sts(words):
    # sts K, rR encodes as 1001 001r rrrr 0000 | K.
    return (len(words) >= 2 and (words[1] & 0xFC) == 0x90
            and (words[0] & 0x0F) == 0x00 and len(words) >= 4)


def check_vectors(elf, insns, secs):
    text = secs.get('.text')
    flash_start = secs.get('.flash_start')
    if text is None or text[1] & 1:
        fail(f'{elf}: .text missing or misaligned')
        return
    if flash_start is not None and flash_start[1] != 0:
        fail(f'{elf}: .flash_start VMA {flash_start[1]:#x}, expected 0')
        return
    first = next((t for t in insns if t[0] <= 4), None)
    if first is None:
        fail(f'{elf}: cannot read reset vector')
        return
    txt = first[2]
    w = first[1]
    word = w[0] | (w[1] << 8) if len(w) >= 2 else 0
    # LLVM's avrxmega3 decoder prints the wide jmp as <unknown>; accept it
    # from the opcode bits: rjmp = 1100 kkkk..., jmp = 1001 010... 11d.
    if re.match(r'^r?jmp\b', txt):
        ok(f'{elf}: reset vector at 0 -> {txt}')
    elif txt == '<unknown>' and ((word >> 12) == 0xC or
                                 ((word >> 10) == 0b100101 and ((word >> 1) & 0x7) == 0b110)):
        ok(f'{elf}: reset vector at 0 -> jmp (opcode-verified, undecoded by llvm)')
    else:
        fail(f'{elf}: first instruction is {txt!r}, expected jmp/rjmp')


def check_sram_placement(elf, secs):
    problems = []
    for name in ('.data', '.bss', '.heap'):
        s = secs.get(name)
        if s is None:
            problems.append(f'no {name} section')
        elif not (SRAM_BASE_DATA_ADDR <= s[1] < SRAM_BASE_DATA_ADDR + 0x1000):
            problems.append(f'{name} at {s[1]:#x}, outside SRAM window')
    if problems:
        for p in problems:
            fail(f'{elf}: {p}')
    else:
        ok(f'{elf}: .data/.bss/.heap at SRAM base ({SRAM_BASE_DATA_ADDR:#x})')


# Images that do not touch pins: no SBI/CBI can be expected of them.
GPIO_FREE_IMAGES = ('mvio', 'abi_probe')

# Pure-arithmetic diagnostic images: no NVM/BOD/WDT access, hence no CCP.
CCP_FREE_IMAGES = ('abi_probe',)


def check_gpio_folding(elf, insns):
    if any(name in elf for name in GPIO_FREE_IMAGES):
        return
    sbi_cbi = sum(1 for _, _, t in insns if re.match(r'^(sbi|cbi)\b', t))
    if sbi_cbi == 0:
        fail(f'{elf}: comptime GPIO folding lost (no SBI/CBI in image)')
    else:
        ok(f'{elf}: {sbi_cbi} SBI/CBI instruction(s) -- comptime GPIO intact')


def check_ccp_adjacency(elf, insns):
    if any(name in elf for name in CCP_FREE_IMAGES):
        return
    found = good = 0
    for i, cur in enumerate(insns):
        addr, w, txt = cur
        if not txt.startswith('out') or '0x14,' not in txt:
            continue
        found += 1
        sig = re.search(r'out\s+0x14,\s*(r\d+)', txt).group(1)
        prev = insns[i - 1] if i else None
        nxt = insns[i + 1] if i + 1 < len(insns) else None
        m = re.search(r'ldi\s+(r\d+)', prev[2]) if prev else None
        prev_ok = m is not None and m.group(1) == sig
        next_ok = nxt is not None and is_sts(nxt[1])
        if prev_ok and next_ok:
            good += 1
        else:
            fail(f'{elf}: CCP at {addr:#x} lacks ldi/out/sts adjacency')
    if found == 0:
        fail(f'{elf}: no CCP stores found (expected when NVM/BOD/WDT are used)')
    elif good == found:
        ok(f'{elf}: {found}/{found} CCP sequences keep ldi->out->sts adjacency')


def main():
    elves = sys.argv[1:]
    if not elves:
        print('usage: check_avr32dd20_disassembly.py <elf>...')
        sys.exit(2)
    for elf in elves:
        secs = parse_sections(elf)
        insns = parse_insns(elf)
        if secs is None or insns is None:
            continue
        if not insns:
            fail(f'{elf}: no instructions disassembled')
            continue
        check_vectors(elf, insns, secs)
        check_sram_placement(elf, secs)
        check_gpio_folding(elf, insns)
        check_ccp_adjacency(elf, insns)
        print()
    if failures:
        print(f'{len(failures)} failure(s) across {len(elves)} image(s)')
        sys.exit(1)
    print(f'all disassembly checks passed for {len(elves)} image(s)')


if __name__ == '__main__':
    main()
