const microzig = @import("microzig");
const mmio = microzig.mmio;

const types = @import("../../types.zig");

pub const EVSYS = extern struct {
    /// Channel 0 generator select
    pub const EVSYS_CHANNEL0 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV8192 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV4096 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV2048 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV1024 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port A Pin 0
        PORTA_PIN0 = 0x40,
        /// Port A Pin 1
        PORTA_PIN1 = 0x41,
        /// Port A Pin 2
        PORTA_PIN2 = 0x42,
        /// Port A Pin 3
        PORTA_PIN3 = 0x43,
        /// Port A Pin 4
        PORTA_PIN4 = 0x44,
        /// Port A Pin 5
        PORTA_PIN5 = 0x45,
        /// Port A Pin 6
        PORTA_PIN6 = 0x46,
        /// Port A Pin 7
        PORTA_PIN7 = 0x47,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Channel 1 generator select
    pub const EVSYS_CHANNEL1 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV512 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV256 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV128 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV64 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port A Pin 0
        PORTA_PIN0 = 0x40,
        /// Port A Pin 1
        PORTA_PIN1 = 0x41,
        /// Port A Pin 2
        PORTA_PIN2 = 0x42,
        /// Port A Pin 3
        PORTA_PIN3 = 0x43,
        /// Port A Pin 4
        PORTA_PIN4 = 0x44,
        /// Port A Pin 5
        PORTA_PIN5 = 0x45,
        /// Port A Pin 6
        PORTA_PIN6 = 0x46,
        /// Port A Pin 7
        PORTA_PIN7 = 0x47,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Channel 2 generator select
    pub const EVSYS_CHANNEL2 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV8192 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV4096 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV2048 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV1024 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port C Pin 1
        PORTC_PIN1 = 0x41,
        /// Port C Pin 2
        PORTC_PIN2 = 0x42,
        /// Port C Pin 3
        PORTC_PIN3 = 0x43,
        /// Port D Pin 4
        PORTD_PIN4 = 0x4c,
        /// Port D Pin 5
        PORTD_PIN5 = 0x4d,
        /// Port D Pin 6
        PORTD_PIN6 = 0x4e,
        /// Port D Pin 7
        PORTD_PIN7 = 0x4f,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Channel 3 generator select
    pub const EVSYS_CHANNEL3 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV512 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV256 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV128 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV64 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port C Pin 1
        PORTC_PIN1 = 0x41,
        /// Port C Pin 2
        PORTC_PIN2 = 0x42,
        /// Port C Pin 3
        PORTC_PIN3 = 0x43,
        /// Port D Pin 4
        PORTD_PIN4 = 0x4c,
        /// Port D Pin 5
        PORTD_PIN5 = 0x4d,
        /// Port D Pin 6
        PORTD_PIN6 = 0x4e,
        /// Port D Pin 7
        PORTD_PIN7 = 0x4f,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Channel 4 generator select
    pub const EVSYS_CHANNEL4 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV8192 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV4096 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV2048 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV1024 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port F Pin 6
        PORTF_PIN6 = 0x4e,
        /// Port F Pin 7
        PORTF_PIN7 = 0x4f,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Channel 5 generator select
    pub const EVSYS_CHANNEL5 = enum(u8) {
        /// Off
        OFF = 0x0,
        /// UPDI SYNCH character
        UPDI_SYNCH = 0x1,
        /// MVIO VDDIO2 OK
        MVIO = 0x5,
        /// Real Time Counter overflow
        RTC_OVF = 0x6,
        /// Real Time Counter compare
        RTC_CMP = 0x7,
        /// Periodic Interrupt Timer output 0
        RTC_PIT_DIV512 = 0x8,
        /// Periodic Interrupt Timer output 1
        RTC_PIT_DIV256 = 0x9,
        /// Periodic Interrupt Timer output 2
        RTC_PIT_DIV128 = 0xa,
        /// Periodic Interrupt Timer output 3
        RTC_PIT_DIV64 = 0xb,
        /// Configurable Custom Logic LUT0
        CCL_LUT0 = 0x10,
        /// Configurable Custom Logic LUT1
        CCL_LUT1 = 0x11,
        /// Configurable Custom Logic LUT2
        CCL_LUT2 = 0x12,
        /// Configurable Custom Logic LUT3
        CCL_LUT3 = 0x13,
        /// Analog Comparator 0 out
        AC0_OUT = 0x20,
        /// ADC 0 Result Ready
        ADC0_RESRDY = 0x24,
        /// Zero Cross Detect 3 out
        ZCD3 = 0x30,
        /// Port F Pin 6
        PORTF_PIN6 = 0x4e,
        /// Port F Pin 7
        PORTF_PIN7 = 0x4f,
        /// USART 0 XCK
        USART0_XCK = 0x60,
        /// USART 1 XCK
        USART1_XCK = 0x61,
        /// SPI 0 SCK
        SPI0_SCK = 0x68,
        /// Timer/Counter A0 overflow / low byte timer underflow
        TCA0_OVF_LUNF = 0x80,
        /// Timer/Counter A0 high byte timer underflow
        TCA0_HUNF = 0x81,
        /// Timer/Counter A0 compare 0 / low byte timer compare 0
        TCA0_CMP0_LCMP0 = 0x84,
        /// Timer/Counter A0 compare 1 / low byte timer compare 1
        TCA0_CMP1_LCMP1 = 0x85,
        /// Timer/Counter A0 compare 2 / low byte timer compare 2
        TCA0_CMP2_LCMP2 = 0x86,
        /// Timer/Counter B0 capture
        TCB0_CAPT = 0xa0,
        /// Timer/Counter B0 overflow
        TCB0_OVF = 0xa1,
        /// Timer/Counter B1 capture
        TCB1_CAPT = 0xa2,
        /// Timer/Counter B1 overflow
        TCB1_OVF = 0xa3,
        /// Timer/Counter B2 capture
        TCB2_CAPT = 0xa4,
        /// Timer/Counter B2 overflow
        TCB2_OVF = 0xa5,
        /// Timer/Counter D0 event 0
        TCD0_CMPBCLR = 0xb0,
        /// Timer/Counter D0 event 1
        TCD0_CMPASET = 0xb1,
        /// Timer/Counter D0 event 2
        TCD0_CMPBSET = 0xb2,
        /// Timer/Counter D0 event 3
        TCD0_PROGEV = 0xb3,
        _,
    };

    /// Software event on channel select
    pub const EVSYS_SWEVENTA = enum(u8) {
        /// Software event on channel 0
        CH0 = 0x1,
        /// Software event on channel 1
        CH1 = 0x2,
        /// Software event on channel 2
        CH2 = 0x4,
        /// Software event on channel 3
        CH3 = 0x8,
        /// Software event on channel 4
        CH4 = 0x10,
        /// Software event on channel 5
        CH5 = 0x20,
        /// Software event on channel 6
        CH6 = 0x40,
        /// Software event on channel 7
        CH7 = 0x80,
        _,
    };

    /// Software event on channel select
    pub const EVSYS_SWEVENTB = enum(u2) {
        /// Software event on channel 8
        CH8 = 0x0,
        /// Software event on channel 9
        CH9 = 0x1,
        _,
    };

    /// User channel select
    pub const EVSYS_USER = enum(u8) {
        /// Off
        OFF = 0x0,
        /// Connect user to event channel 0
        CHANNEL0 = 0x1,
        /// Connect user to event channel 1
        CHANNEL1 = 0x2,
        /// Connect user to event channel 2
        CHANNEL2 = 0x3,
        /// Connect user to event channel 3
        CHANNEL3 = 0x4,
        /// Connect user to event channel 4
        CHANNEL4 = 0x5,
        /// Connect user to event channel 5
        CHANNEL5 = 0x6,
        _,
    };

    /// Software Event A
    /// offset: 0x00
    SWEVENTA: mmio.Mmio(packed struct(u8) {
        /// Software event on channel select
        SWEVENTA: EVSYS_SWEVENTA,
    }),
    /// Software Event B
    /// offset: 0x01
    SWEVENTB: mmio.Mmio(packed struct(u8) {
        /// Software event on channel select
        SWEVENTB: EVSYS_SWEVENTB,
        padding: u6 = 0,
    }),
    /// offset: 0x02
    reserved2: [14]u8,
    /// Multiplexer Channel 0
    /// offset: 0x10
    CHANNEL0: mmio.Mmio(packed struct(u8) {
        /// Channel 0 generator select
        CHANNEL0: EVSYS_CHANNEL0,
    }),
    /// Multiplexer Channel 1
    /// offset: 0x11
    CHANNEL1: mmio.Mmio(packed struct(u8) {
        /// Channel 1 generator select
        CHANNEL1: EVSYS_CHANNEL1,
    }),
    /// Multiplexer Channel 2
    /// offset: 0x12
    CHANNEL2: mmio.Mmio(packed struct(u8) {
        /// Channel 2 generator select
        CHANNEL2: EVSYS_CHANNEL2,
    }),
    /// Multiplexer Channel 3
    /// offset: 0x13
    CHANNEL3: mmio.Mmio(packed struct(u8) {
        /// Channel 3 generator select
        CHANNEL3: EVSYS_CHANNEL3,
    }),
    /// Multiplexer Channel 4
    /// offset: 0x14
    CHANNEL4: mmio.Mmio(packed struct(u8) {
        /// Channel 4 generator select
        CHANNEL4: EVSYS_CHANNEL4,
    }),
    /// Multiplexer Channel 5
    /// offset: 0x15
    CHANNEL5: mmio.Mmio(packed struct(u8) {
        /// Channel 5 generator select
        CHANNEL5: EVSYS_CHANNEL5,
    }),
    /// offset: 0x16
    reserved22: [10]u8,
    /// User 0 - CCL0 Event A
    /// offset: 0x20
    USERCCLLUT0A: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 1 - CCL0 Event B
    /// offset: 0x21
    USERCCLLUT0B: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 2 - CCL1 Event A
    /// offset: 0x22
    USERCCLLUT1A: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 3 - CCL1 Event B
    /// offset: 0x23
    USERCCLLUT1B: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 4 - CCL2 Event A
    /// offset: 0x24
    USERCCLLUT2A: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 5 - CCL2 Event B
    /// offset: 0x25
    USERCCLLUT2B: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 6 - CCL3 Event A
    /// offset: 0x26
    USERCCLLUT3A: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 7 - CCL3 Event B
    /// offset: 0x27
    USERCCLLUT3B: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 12 - ADC0
    /// offset: 0x28
    USERADC0START: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 13 - EVOUTA
    /// offset: 0x29
    USEREVSYSEVOUTA: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 15 - EVOUTC
    /// offset: 0x2a
    USEREVSYSEVOUTC: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 16 - EVOUTD
    /// offset: 0x2b
    USEREVSYSEVOUTD: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 18 - EVOUTF
    /// offset: 0x2c
    USEREVSYSEVOUTF: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 20 - USART0
    /// offset: 0x2d
    USERUSART0IRDA: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 21 - USART1
    /// offset: 0x2e
    USERUSART1IRDA: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 26 - TCA0 Event A
    /// offset: 0x2f
    USERTCA0CNTA: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 27 - TCA0 Event B
    /// offset: 0x30
    USERTCA0CNTB: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 30 - TCB0 Event A
    /// offset: 0x31
    USERTCB0CAPT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 31 - TCB0 Event B
    /// offset: 0x32
    USERTCB0COUNT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 32 - TCB1 Event A
    /// offset: 0x33
    USERTCB1CAPT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 33 - TCB1 Event B
    /// offset: 0x34
    USERTCB1COUNT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 34 - TCB2 Event A
    /// offset: 0x35
    USERTCB2CAPT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 35 - TCB2 Event B
    /// offset: 0x36
    USERTCB2COUNT: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 40 - TCD0 Event A
    /// offset: 0x37
    USERTCD0INPUTA: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
    /// User 41 - TCD0 Event B
    /// offset: 0x38
    USERTCD0INPUTB: mmio.Mmio(packed struct(u8) {
        /// User channel select
        USER: EVSYS_USER,
    }),
};
