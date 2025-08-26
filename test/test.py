# SPDX-FileCopyrightText: © 2025
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


async def shift_in_byte(dut, pattern: int):
    """Shift in an 8-bit pattern (LSB first, matches tb.v)."""
    for i in range(8):
        bit = (pattern >> i) & 1
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)

    # Wait one extra cycle for DUT to latch
    await ClockCycles(dut.clk, 1)

    return dut.uo_out.value.integer


@cocotb.test()
async def test_serdes_shift(dut):
    dut._log.info("Start simulation")

    # Clock: 100 MHz (10 ns)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Defaults
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Hold reset low for 5 cycles (~50ns like tb.v)
    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    dut._log.info("Reset released")

    # Keep enable low for 2 more cycles
    await ClockCycles(dut.clk, 2)

    dut.ena.value = 1
    dut._log.info("Enable asserted")

    # ---------------- Test vector ----------------
    test_byte = 0x00  # same as tb.v
    result = await shift_in_byte(dut, test_byte)

    dut._log.info(f"Shifted in 0x{test_byte:02X}, DUT latched 0x{result:02X}")
    assert result == test_byte, f"Expected 0x{test_byte:02X}, got 0x{result:02X}"

    dut._log.info("Test completed successfully")
