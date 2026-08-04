# Microchip AVR Dx Hardware Support Package

## Supported Chips

- AVR32DD20

The AVR Dx family shares one device pack and one register architecture, so
sibling parts (AVR16DD20, AVR64DD20, the DD14/28/32 pin counts, and the DA/DB
series) are a chip entry in `build.zig` plus a HAL root away. Each needs its
own memory map from its ATDF and its own pin availability mask — the peripheral
modules themselves are shared architecture.

## AVR32DD20 at a glance

| | |
|---|---|
| Core | AVR Dx, `avrxmega3` |
| Flash | 32 KiB, 512-byte pages, mapped into data space at `0x8000` |
| SRAM | 4 KiB at `0x7000` |
| EEPROM | 256 B at `0x1400`, byte-erasable |
| User row | 32 B at `0x1080` |
| Max frequency | 24 MHz internal, 32 MHz external |
| Signature | `1E 95 3A` |
| I/O | 17 pins: PA0–PA7, PC1–PC3, PD4–PD7, PF6–PF7 |

PORTC is powered from **VDDIO2**, not VDD — see the `mvio` module. Reaching for
a pin the 20-pin package does not bond (`gpio.pin(.c, 0)`, say) is a compile
error, not a silent write to nothing.

## Peripheral coverage

| Module | Peripheral |
|---|---|
| `clock` | CLKCTRL: source select, prescaler, OSCHF/OSC32K, XOSC32K/XOSCHF, PLL, clock-failure detection |
| `gpio` | PORT/VPORT: pins, whole-port access, multi-pin configuration, pin interrupts |
| `portmux` | Every peripheral pin position reachable on this package |
| `mvio` | VDDIO2 status and interrupt |
| `tca0` | TCA0 in both single (16-bit, 3 channels) and split (dual 8-bit, 6 channels) modes |
| `tcb` | TCB0/TCB1: all eight count modes, 32-bit cascade |
| `tcd` | TCD0: asynchronous PWM, dead time, output override |
| `rtc` | RTC counter and PIT |
| `adc` | 12-bit ADC: differential, accumulation, window comparator, calibrated temperature sensor |
| `dac` | 10-bit DAC |
| `ac` | Analog comparator with DACREF |
| `vref` | Per-consumer voltage references |
| `zcd` | ZCD3 zero-cross detector |
| `bod` | Brown-out detector and voltage level monitor |
| `usart` | USART0/USART1, fractional baud generator, `std.Io.Writer` |
| `spi` | SPI0 host and client |
| `twi` | TWI0 host, with `write`/`read`/`write_read` transactions |
| `ccl` | Four LUTs, sequential logic, common truth tables |
| `evsys` | Six event channels with per-channel pin generators |
| `nvmctrl` | EEPROM, flash self-programming, user row, flash mapping |
| `crcscan` | Background flash CRC |
| `watchdog`, `sleep`, `reset`, `cpuint`, `device` | System control and identity |

## Datasheet citations

Non-obvious register procedures in this package cite the AVR16/32DD14/20 data
sheet, Microchip **DS40002413**, as `section X.Y "Title", page N` with a
direct link:

<https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf>

Appending `#page=N` opens most viewers at that page. Register addresses, bit
masks, enum encodings and pin mappings are transcribed from the `AVR32DD20.atdf`
in the device pack rather than from the PDF, since the ATDF is machine-readable
and therefore checkable.

## Device pack

`build.zig.zon` fetches `Microchip.AVR-Dx_DFP` from Microchip's pack server
directly, because <https://atpack.microzig.tech> does not currently mirror it.
If a maintainer uploads the pack, switch the URL to
`https://atpack.microzig.tech/Microchip.AVR-Dx_DFP.2.8.343.atpack` and keep the
hash.

> **The `.hash` in `build.zig.zon` is a placeholder.** It could not be computed
> where this package was written. Run
> `zig fetch --save=atpack https://packs.download.microchip.com/Microchip.AVR-Dx_DFP.2.8.343.atpack`
> in this directory, or take the expected hash out of the first build error.

## Known gaps

- Nothing here has been run on hardware.

## Configuration Change Protection

The set of CCP-protected registers is now pinned to the data sheet rather than
guessed at. Every peripheral chapter in DS40002413B carries a "Configuration
Change Protection" subsection whose table names that peripheral's protected
registers and the key each needs; the union of those tables is reproduced at
the top of `src/hals/avr32dd20/ccp.zig`, with section, table and page numbers.
Each entry was confirmed twice, since a protected register's `Property:` line
in its own register description reads "Configuration Change Protection" while
an unprotected one reads `-`.

Only NVMCTRL.CTRLA takes the SPM key; everything else protected takes IOREG.
Three registers this HAL had been guarding turned out not to be protected --
CLKCTRL.OSCHFTUNE, SLPCTRL.CTRLA and BOD.VLMCTRLA -- and each now uses a plain
store, which drops a redundant `sts` and a four-instruction interrupt blackout
from the sleep and VLM paths. One register was under-guarded: NVMCTRL.CTRLB
takes IOREG, so `nvmctrl.set_flash_section` had been writing FLMAP through a
store the hardware would have discarded.

## Verification status

Every declaration in the HAL, and every example, passes full semantic analysis
for `avr-freestanding-eabi` / `avrxmega3`. Linking was not attempted: the Zig
0.16 + LLVM 21 toolchain used here fails AVR codegen even for a four-line
program (`error: Alias and aliasee types don't match`), so that gap is the
toolchain's, not this package's. Register addresses, bit positions and enum
encodings were transcribed from the ATDF and re-checked against it; timing and
electrical behaviour have not been observed on silicon.

## FYI: LLVM issues

LLVM has trouble lowering AVR in debug mode. Build in release small:

```
zig build -Doptimize=ReleaseSmall
```
