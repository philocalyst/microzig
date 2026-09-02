const microzig = @import("microzig");
const mmio = microzig.mmio;

pub const types = @import("types.zig");

pub const Properties = struct {
    has_vtor: ?bool = null,
    has_mpu: ?bool = null,
    has_fpu: ?bool = null,
    interrupt_priority_bits: ?u8 = null,
    dma_channel_count: ?u32 = null,
};

pub const Interrupt = struct {
    name: [:0]const u8,
    index: i16,
    description: ?[:0]const u8,
};

pub const properties: Properties = .{
    .has_vtor = null,
    .has_mpu = null,
    .has_fpu = null,
    .interrupt_priority_bits = null,
    .dma_channel_count = null,
};

pub const raw_properties = struct {
    pub const family = "AVR";
};

pub const interrupts: []const Interrupt = &.{
    .{ .name = "CRCSCAN_NMI", .index = 1, .description = null },
    .{ .name = "BOD_VLM", .index = 2, .description = null },
    .{ .name = "CLKCTRL_CFD", .index = 3, .description = null },
    .{ .name = "MVIO_MVIO", .index = 4, .description = null },
    .{ .name = "RTC_CNT", .index = 5, .description = null },
    .{ .name = "RTC_PIT", .index = 6, .description = null },
    .{ .name = "CCL_CCL", .index = 7, .description = null },
    .{ .name = "PORTA_PORT", .index = 8, .description = null },
    .{ .name = "TCA0_LUNF", .index = 9, .description = null },
    .{ .name = "TCA0_HUNF", .index = 10, .description = null },
    .{ .name = "TCA0_CMP0", .index = 11, .description = null },
    .{ .name = "TCA0_CMP1", .index = 12, .description = null },
    .{ .name = "TCA0_CMP2", .index = 13, .description = null },
    .{ .name = "TCB0_INT", .index = 14, .description = null },
    .{ .name = "TCB1_INT", .index = 15, .description = null },
    .{ .name = "TCD0_OVF", .index = 16, .description = null },
    .{ .name = "TCD0_TRIG", .index = 17, .description = null },
    .{ .name = "TWI0_TWIS", .index = 18, .description = null },
    .{ .name = "TWI0_TWIM", .index = 19, .description = null },
    .{ .name = "SPI0_INT", .index = 20, .description = null },
    .{ .name = "USART0_RXC", .index = 21, .description = null },
    .{ .name = "USART0_DRE", .index = 22, .description = null },
    .{ .name = "USART0_TXC", .index = 23, .description = null },
    .{ .name = "PORTD_PORT", .index = 24, .description = null },
    .{ .name = "AC0_AC", .index = 25, .description = null },
    .{ .name = "ADC0_RESRDY", .index = 26, .description = null },
    .{ .name = "ADC0_WCMP", .index = 27, .description = null },
    .{ .name = "ZCD3_ZCD", .index = 28, .description = null },
    .{ .name = "PORTC_PORT", .index = 29, .description = null },
    .{ .name = "USART1_RXC", .index = 31, .description = null },
    .{ .name = "USART1_DRE", .index = 32, .description = null },
    .{ .name = "USART1_TXC", .index = 33, .description = null },
    .{ .name = "PORTF_PORT", .index = 34, .description = null },
    .{ .name = "NVMCTRL_EE", .index = 35, .description = null },
};

pub const VectorTable = extern struct {
    const Handler = microzig.interrupt.Handler;
    const unhandled = microzig.interrupt.unhandled;

    RESET: Handler,
    CRCSCAN_NMI: Handler = unhandled,
    BOD_VLM: Handler = unhandled,
    CLKCTRL_CFD: Handler = unhandled,
    MVIO_MVIO: Handler = unhandled,
    RTC_CNT: Handler = unhandled,
    RTC_PIT: Handler = unhandled,
    CCL_CCL: Handler = unhandled,
    PORTA_PORT: Handler = unhandled,
    TCA0_LUNF: Handler = unhandled,
    TCA0_HUNF: Handler = unhandled,
    TCA0_CMP0: Handler = unhandled,
    TCA0_CMP1: Handler = unhandled,
    TCA0_CMP2: Handler = unhandled,
    TCB0_INT: Handler = unhandled,
    TCB1_INT: Handler = unhandled,
    TCD0_OVF: Handler = unhandled,
    TCD0_TRIG: Handler = unhandled,
    TWI0_TWIS: Handler = unhandled,
    TWI0_TWIM: Handler = unhandled,
    SPI0_INT: Handler = unhandled,
    USART0_RXC: Handler = unhandled,
    USART0_DRE: Handler = unhandled,
    USART0_TXC: Handler = unhandled,
    PORTD_PORT: Handler = unhandled,
    AC0_AC: Handler = unhandled,
    ADC0_RESRDY: Handler = unhandled,
    ADC0_WCMP: Handler = unhandled,
    ZCD3_ZCD: Handler = unhandled,
    PORTC_PORT: Handler = unhandled,
    reserved30: [1]u16 = undefined,
    USART1_RXC: Handler = unhandled,
    USART1_DRE: Handler = unhandled,
    USART1_TXC: Handler = unhandled,
    PORTF_PORT: Handler = unhandled,
    NVMCTRL_EE: Handler = unhandled,
};

pub const peripherals = struct {
    // Generator patch: VPORTA sits at data address 0, which Zig pointers cannot
    // represent without `allowzero`. Applied by scripts/regenerate_avr32dd20_chip.sh.
    pub const VPORTA: *allowzero volatile types.peripherals.VPORT = @ptrFromInt(0x0);
    pub const VPORTC: *volatile types.peripherals.VPORT = @ptrFromInt(0x8);
    pub const VPORTD: *volatile types.peripherals.VPORT = @ptrFromInt(0xc);
    pub const VPORTF: *volatile types.peripherals.VPORT = @ptrFromInt(0x14);
    pub const GPR: *volatile types.peripherals.GPR = @ptrFromInt(0x1c);
    pub const CPU: *volatile types.peripherals.CPU = @ptrFromInt(0x30);
    pub const RSTCTRL: *volatile types.peripherals.RSTCTRL = @ptrFromInt(0x40);
    pub const SLPCTRL: *volatile types.peripherals.SLPCTRL = @ptrFromInt(0x50);
    pub const CLKCTRL: *volatile types.peripherals.CLKCTRL = @ptrFromInt(0x60);
    pub const BOD: *volatile types.peripherals.BOD = @ptrFromInt(0xa0);
    pub const VREF: *volatile types.peripherals.VREF = @ptrFromInt(0xb0);
    pub const MVIO: *volatile types.peripherals.MVIO = @ptrFromInt(0xc0);
    pub const WDT: *volatile types.peripherals.WDT = @ptrFromInt(0x100);
    pub const CPUINT: *volatile types.peripherals.CPUINT = @ptrFromInt(0x110);
    pub const CRCSCAN: *volatile types.peripherals.CRCSCAN = @ptrFromInt(0x120);
    pub const RTC: *volatile types.peripherals.RTC = @ptrFromInt(0x140);
    pub const CCL: *volatile types.peripherals.CCL = @ptrFromInt(0x1c0);
    pub const EVSYS: *volatile types.peripherals.EVSYS = @ptrFromInt(0x200);
    pub const PORTA: *volatile types.peripherals.PORT = @ptrFromInt(0x400);
    pub const PORTC: *volatile types.peripherals.PORT = @ptrFromInt(0x440);
    pub const PORTD: *volatile types.peripherals.PORT = @ptrFromInt(0x460);
    pub const PORTF: *volatile types.peripherals.PORT = @ptrFromInt(0x4a0);
    pub const PORTMUX: *volatile types.peripherals.PORTMUX = @ptrFromInt(0x5e0);
    pub const ADC0: *volatile types.peripherals.ADC = @ptrFromInt(0x600);
    pub const AC0: *volatile types.peripherals.AC = @ptrFromInt(0x680);
    pub const DAC0: *volatile types.peripherals.DAC = @ptrFromInt(0x6a0);
    pub const ZCD3: *volatile types.peripherals.ZCD = @ptrFromInt(0x6d8);
    pub const USART0: *volatile types.peripherals.USART = @ptrFromInt(0x800);
    pub const USART1: *volatile types.peripherals.USART = @ptrFromInt(0x820);
    pub const TWI0: *volatile types.peripherals.TWI = @ptrFromInt(0x900);
    pub const SPI0: *volatile types.peripherals.SPI = @ptrFromInt(0x940);
    pub const TCA0: *volatile types.peripherals.TCA = @ptrFromInt(0xa00);
    pub const TCB0: *volatile types.peripherals.TCB = @ptrFromInt(0xb00);
    pub const TCB1: *volatile types.peripherals.TCB = @ptrFromInt(0xb10);
    pub const TCD0: *volatile types.peripherals.TCD = @ptrFromInt(0xb80);
    pub const SYSCFG: *volatile types.peripherals.SYSCFG = @ptrFromInt(0xf00);
    pub const NVMCTRL: *volatile types.peripherals.NVMCTRL = @ptrFromInt(0x1000);
    pub const LOCK: *volatile types.peripherals.LOCK = @ptrFromInt(0x1040);
    pub const FUSE: *volatile types.peripherals.FUSE = @ptrFromInt(0x1050);
    pub const USERROW: *volatile types.peripherals.USERROW = @ptrFromInt(0x1080);
    pub const SIGROW: *volatile types.peripherals.SIGROW = @ptrFromInt(0x1100);
};
