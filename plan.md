

  The implementation target is:

  - AVR32DD20, device signature 1E 95 3A.
  - 32 KiB flash, 512-byte flash pages.
  - 4 KiB SRAM at data address 0x7000.
  - 256-byte EEPROM and 32-byte user row.
  - 20-pin package with PA0–PA7, PC1–PC3, PD4–PD7, PF6–PF7.
  - 17 input-capable pins, but only 16 output-capable pins because PF6/RESET is input-only.
  - Maximum CLK_MAIN/CPU frequency is 24 MHz, not 32 MHz.
  - PC1–PC3 ADC inputs are available only when MVIO is disabled by the corresponding fuse.
  - TWI supports simultaneous host and client operation on separate pins.

  Those package-specific points are stated in Microchip’s exact AVR DD peripheral overview
  (https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-F94E51A5-03D0-474D-820B-5DF1CA77A1BD.html)
  and I/O multiplexing table
  (https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-B9F43120-9DEE-4F24-B16A-0750854F7903.html).
  The authoritative PDF is DS40002413B
  (https://ww1.microchip.com/downloads/aemDocuments/documents/MCU08/ProductDocuments/DataSheets/AVR32-16DD20-14-Complete-DataSheet-DS40002413.pdf).

  The current code incorrectly takes the ATDF’s speedmax="32000000" as the CPU rating in port/microchip/avrdx/src/hals/avr32dd20/
  device.zig:19. The electrical limits and family overview say 24 MHz, so the PDF wins. The 32–48 MHz PLL output is for TCD, not
  CLK_MAIN.

  The current official pack is Microchip.AVR-Dx_DFP 2.8.343 from Microchip’s pack repository (https://packs.download.microchip.com/). The
  downloaded artifact was checked as:

  SHA-256 d81af59072e5ac188431e828461eee5c08e6d5f3ace32461328b4da0ec348746
  size    16,766,508 bytes

  ## Blocking audit results

   Area                       Required correction
  ━━━━━━━━━━━━━━━━━━━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Toolchain                  Rebased upstream now requires Zig 0.17.0-dev.1471+ff10b90bc or newer; the local default is 0.16.0. Pin the
                              CI/compiler version before accepting build results.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Device pack                port/microchip/avrdx/build.zig.zon:3 has a placeholder package hash and stale fingerprint. Zig rejects
                              Microchip’s application/vnd.atmel.atpack MIME type, while the proposed MicroZig mirror URL currently
                              returns 404.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Registers                  The 837-line port/microchip/avrdx/src/hals/avr32dd20/registers.zig:1 should be deleted. regz successfully
                              generated typed registers from the real AVR32DD20 ATDF.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   GPIO                       port/microchip/avrdx/src/hals/avr32dd20/gpio.zig:142 claims compile-time pins generate SBI/CBI, but the
                              present runtime Pin abstraction generated read/modify/write machinery in the diagnostic build. PF6 is
                              incorrectly output-capable. disable_unbonded_inputs() is a no-op because its unbonded mask is masked back
                              to zero.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Routing                    port/microchip/avrdx/src/hals/avr32dd20/portmux.zig:158 writes reserved TCB route bits. TCB output enable
                              belongs in TCBn.CTRLB.CCMPEN; the ATDF provides only the default route.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   ADC                        Positive and negative mux inputs need different types. PC/MVIO restrictions are missing. The temperature
                              comment says 1.024 V although the procedure requires 2.048 V. Delay calculations floor “at least” timings.
                              Accumulation above 16 samples is mishandled because hardware truncates result LSBs; see the exact ADC
                              accumulation procedure (https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-
                              US-8/GUID-D7770493-3174-4393-AC15-558028DF8C0E.html).
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   NVM                        Bounds, 512-byte page alignment, boot-section execution, EEPROM batching, fuse/user-row output, and
                              command lifetime are not sufficiently enforced.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Protected writes           CCP’s two independent volatile stores do not prove the four-instruction timing window. It needs one
                              inline-assembly sequence and a disassembly test.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Peripheral completeness    TWI client/dual mode, several USART modes, SPI buffered/client workflows, TCD events/capture/fault
                              controls, CCL interrupts, RTC debug/events, and valid EVSYS TCD sources are missing.
  ─────────────────────────  ────────────────────────────────────────────────────────────────────────────────────────────────────────────
   Evidence                   all_decls only traverses declarations. It does not instantiate behavior, prove compiler-rt availability,
                              verify vectors, or prove instruction sequences.

  Canonical upstream now supplies avrxmega3 CPU selection and generic AVR interrupt generation, so those should be reused instead of
  adding AVR32DD20-local versions.

  ## Proposed architecture

  ### 1. Generated exhaustive raw layer

  Use the DFP as the source for:

  const peripherals = microzig.chip.peripherals;
  const types = microzig.chip.types.peripherals;

  This gives typed pointers, enums, unions, masks, and register access for every instance:

  CPU CPUINT GPR RSTCTRL SLPCTRL CLKCTRL BOD VREF MVIO WDT
  CRCSCAN NVMCTRL FUSE LOCK USERROW SIGROW SYSCFG
  PORTA PORTC PORTD PORTF VPORTA VPORTC VPORTD VPORTF PORTMUX
  EVSYS CCL RTC ADC0 AC0 DAC0 ZCD3
  USART0 USART1 SPI0 TWI0
  TCA0 TCB0 TCB1 TCD0

  Acceptance rule: every non-reserved ATDF register must be reachable through the generated layer, even where no high-level convenience
  API is appropriate.

  ### 2. Chip capability layer

  Add small compile-time descriptions for facts the register schema cannot express:

  - Bonded pins and input/output capabilities.
  - PF6 input-only status.
  - VDD versus VDDIO2 domains.
  - ADC positive/negative channel legality.
  - MVIO/fuse-dependent ADC availability.
  - Peripheral route alternatives.
  - TCB instance/output metadata.
  - Interrupt numbers and vector-table geometry.
  - Flash/EEPROM/user-row geometry.

  ### 3. Generic high-level drivers

  Use Zig’s comptime/type system to reduce repetition:

  - Pin(port, index, capabilities) with compile-time direction restrictions.
  - One generic USART implementation instantiated for USART0/1.
  - One TCB implementation instantiated for TCB0/1.
  - Mode-discriminated configuration unions for USART, SPI, TWI, TCA and TCD.
  - Generic W1C flag and synchronization helpers where register semantics match.
  - Generated enums re-exported instead of duplicating encodings manually.

  “Exhaustive” will mean complete documented operational modes plus typed raw access—not one handwritten wrapper per bit.

  ## Implementation sequence

  ### Phase 1 — Reproducible inputs and precise citations

  - Pin the repository’s declared Zig development compiler in CI.
  - Put DFP 2.8.343 behind an approved URL with a Zig-recognized MIME type.
  - Pin both Zig package hash and independent SHA-256.
  - Regenerate package fingerprints after the final package contents settle.
  - Add docs/avr32dd20-sources.zon containing:
      - Datasheet number and revision.
      - DFP version/hash.
      - Stable citation ID.
      - Exact online-manual GUID URL.
      - PDF section/title used for authoritative verification.
      - ATDF XPath for machine-derived facts.

  - Add a checker that recursively extracts Microchip’s GUID table of contents, validates titles and URLs, and rejects bare #page=N
    citations.

  - Run live URL validation periodically; normal CI should use the pinned manifest/cache so Microchip availability cannot break builds.

  Gate: every non-obvious procedure has an exact subsection/register link and corresponding PDF/ATDF verification.

  ### Phase 2 — Generated register and chip definitions

  - Replace hand-written registers.zig with regz output.
  - Compare generated instances, register offsets, reset values, enums, vectors and signals against the ATDF.
  - Keep narrowly documented generator patches only where the DFP is demonstrably malformed.
  - Implement the package capability metadata.
  - Correct the 24 MHz maximum and all memory geometry.

  Gate: a structural test proves complete ATDF coverage and zero unexplained hand-transcribed addresses or masks.

  ### Phase 3 — Core, startup and binary layout

  - Reuse upstream avrxmega3 support and avr_common vector generation.
  - Verify all AVR32DD20 vectors, including the reserved index, against the DFP.
  - Validate .data, .bss, stack assumptions, flash VMA, SRAM VMA and reset entry.
  - Add linker output for .fuse, EEPROM and USERROW images.
  - Instantiate 32-bit multiply/divide paths to test bundle_compiler_rt = false.
  - Implement CCP protected writes as one compiler-visible assembly sequence.

  Gate: ELF/HEX link in ReleaseSmall; readelf/objdump confirm vectors, sections, addresses, startup, RETI, and CCP adjacency.

  ### Phase 4 — System, GPIO and routing

  Implement and verify:

  - GPIO/VPORT/PORT, pin controls and interrupts.
  - Compile-time atomic SBI/CBI paths.
  - PF6 input-only enforcement.
  - Board-level unused bonded-pin policy.
  - PORTMUX, EVSYS and CCL including interrupt support.
  - CLKCTRL, BOD, WDT, MVIO, reset, sleep and CPUINT.
  - GPR, SYSCFG, fuses, lock bits and signature-row access.

  Gate: invalid pins/routes fail at compile time, while disassembly proves atomic constant-pin operations.

  ### Phase 5 — Analog subsystem

  Complete:

  - VREF per-consumer configuration.
  - ADC single-ended/differential operation.
  - Separate positive/negative channel types.
  - Accumulation and truncation-aware averaging.
  - Window comparator, interrupts and events.
  - Temperature-sensor calibration and ceiling-rounded timing.
  - MVIO/fuse-dependent channels.
  - DAC, AC and ZCD complete control/interrupt/event paths.

  Gate: host tests cover every calculation and boundary; compile tests cover every legal channel/reference combination and reject illegal
  ones.

  ### Phase 6 — Timers, RTC and event integration

  Complete:

  - TCA single and split modes, buffered updates, events and commands.
  - All eight TCB modes and 32-bit cascade.
  - Full TCD waveform, dead time, delays, event inputs, capture, trigger, fault, override and interrupt controls.
  - RTC counter/PIT, synchronization, interrupts, events and debug behavior.
  - Every documented EVSYS generator/user valid for AVR32DD20.

  Gate: mode-transition tests and linked examples exercise every timer family, PIT wake and event-driven routing.

  ### Phase 7 — Communications

  Complete:

  - USART0/1 asynchronous, synchronous, SPI-host, IrDA, RS-485, auto-baud/start-frame and LIN-related capabilities.
  - A target-suitable MicroZig/std I/O adapter without importing host Windows machinery on AVR.
  - SPI host/client and normal/buffered modes with incompatible operations unrepresentable.
  - TWI host, client and simultaneous dual mode, including masks, arbitration, collision, timeout and bus recovery.

  Gate: loopback/state-machine tests plus compile-time coverage of every documented mode. The exact TWI dual-mode requirement is recorded
  in the peripheral overview
  (https://onlinedocs.microchip.com/oxy/GUID-417F9387-DF9B-42E5-AA91-108A8C58208B-en-US-8/GUID-F94E51A5-03D0-474D-820B-5DF1CA77A1BD.html).

  ### Phase 8 — NVM and integrity peripherals

  - Add bounded EEPROM slices and non-wrapping address arithmetic.
  - Enforce flash page alignment and maximum operation size.
  - Encode boot-section execution requirements.
  - Support flash, EEPROM and user-row operations with explicit command lifetimes.
  - Expose safe fuse/lock representations and image generation.
  - Complete CRCSCAN configuration, status and interrupt workflows.

  Gate: boundary/property tests plus section inspection; destructive hardware tests operate only on reserved test pages.

  ### Phase 9 — Examples and Anduril acceptance

  Keep examples small but behaviorally meaningful:

  - Blinky/GPIO.
  - PWM plus ADC.
  - USART transmit/receive.
  - RTC PIT sleep/wake interrupt.
  - MVIO status/fault.
  - TWI dual-mode and SPI loopback additions.
  - NVM test with protected scratch region.

  Then port the current AVR32DD20 Anduril backend sequence as an integration fixture. AVR32DD20 is already used by current Anduril
  targets including D3AA, KR1AA, Lume X1 and thefreeman’s development kit; see Anduril’s model list
  (https://github.com/ToyKeeper/anduril/blob/trunk/MODELS) and AVR32DD20 backend
  (https://github.com/ToyKeeper/anduril/blob/trunk/arch/avr32dd20.c).

  Hardware order:

  1. Read the UPDI signature and refuse to flash unless it is 1E 95 3A.
  2. Bring up thefreeman AVR32DD20 devkit.
  3. Verify clocks on an output pin.
  4. Exercise GPIO, ADC/temp, RTC/PIT, TCA, DAC and interrupts.
  5. Run one production flashlight target, preferably D3AA or Lume X1.
  6. Measure sleep current and wake behavior.

  ### Phase 10 — Review and CI

  Split the work into independently reviewable commits:

  1. Rebase/package/docs tooling.
  2. Generated chip/register definitions.
  3. AVR core/linker/CCP verification.
  4. GPIO/system/routing.
  5. Analog.
  6. Timers/events.
  7. Communications.
  8. NVM/integrity.
  9. Examples/Anduril/hardware report.
