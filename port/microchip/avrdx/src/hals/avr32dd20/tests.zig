//! Host-side test entry point for the AVR32DD20 HAL.
//!
//! These tests run on the build host, not the target: they cover every pure
//! calculation in the package (ADC accumulation truncation, temperature
//! calibration, baud-rate formulas, CCP window arithmetic) against the values
//! derived from DS40002413B. See plan.md Phase 5's gate: "host tests cover
//! every calculation and boundary".

comptime {
    _ = @import("ccp.zig");
    _ = @import("adc_math.zig");
    _ = @import("ccl.zig");
    _ = @import("capabilities.zig");
    _ = @import("nvmctrl.zig");
}

test {
    @import("std").testing.refAllDecls(@This());
}
