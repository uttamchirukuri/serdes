# SPDX-FileCopyrightText: © 2025
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


async def shift_in_byte(dut, pattern: int):
    """Shift in an 8-bit pattern (LSB first, matches tb.v)."""
    for i in range(8):
        bit = (pattern >> i) & 1  # LSB first
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)
    await ClockCycles(dut.clk, 1)

    # Retry until output is resolved (avoid 'x' crash in GL sim)
    for _ in range(5):
        val = dut.uo_out.value
        if "x" not in str(val):
            return val.integer
        await ClockCycles(dut.clk, 1)

    dut._log.warning("uo_out stayed 'x' after shift")
    return None


def normalize_result(result: int, expected: int) -> int:
    """Normalize DUT output to match expected."""
    if result is None:
        return None
    # Ignore sync word if DUT outputs one
    if result == 0x7E:
        return None
    return result


@cocotb.test()
async def test_dut(dut):
    """Basic test for TinyTapeout DUT with safer reset/enable sequence."""
    dut._log.info("Start simulation")

    # Clock 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Defaults
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Hold reset low for 20 cycles
    for _ in range(20):
        await RisingEdge(dut.clk)

    dut.rst_n.value = 1
    dut._log.info("Reset released")

    # Keep enable low for another 10 cycles after reset
    for _ in range(10):
        await RisingEdge(dut.clk)

    dut.ena.value = 1
    dut._log.info("Enable asserted")

    # ---------------- Test vector ----------------
    pattern1 = 0x00
    result1 = await shift_in_byte(dut, pattern1)
    norm1 = normalize_result(result1, pattern1)

    # If DUT emitted sync word, capture again
    if norm1 is None:
        result1 = await shift_in_byte(dut, pattern1)
        norm1 = normalize_result(result1, pattern1)

    if norm1 is None:
        dut._log.error("DUT output never resolved to a valid byte")
        assert False, "Test failed: DUT never produced valid data"

    dut._log.info(f"Captured byte 1 = 0x{result1:02X} (normalized=0x{norm1:02X})")
    assert norm1 == pattern1, f"Expected 0x{pattern1:02X}, got 0x{result1:02X}"

    dut._log.info("Test completed successfully")
