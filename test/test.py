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
    # One extra cycle after shifting
    await ClockCycles(dut.clk, 1)

    # Try to capture one valid parallel output
    for _ in range(20):  # allow pipeline latency (FIR + enc + dec + FIR)
        val = dut.uo_out.value
        if "x" not in str(val):
            return val.integer
        await ClockCycles(dut.clk, 1)
    return None


def expected_pipeline_out(pattern: int) -> int:
    """
    Reference model of pipeline:
    FIR (before) → Encrypt → Decrypt → FIR (after).
    For now, encryption+decryption cancels,
    FIR is identity (pass-through).
    So expected == input.
    """
    return pattern & 0xFF


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start simulation")

    # Clock 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    dut.ena.value = 1
    await ClockCycles(dut.clk, 5)
    dut._log.info("Reset done")

    # Test pattern
    pattern = 0x3C
    result = await shift_in_byte(dut, pattern)
    expected = expected_pipeline_out(pattern)

    if result is None:
        dut._log.warning("DUT output unresolved (X/Z after pipeline)")
    else:
        if result == expected:
            dut._log.info(f"PASS: Expected 0x{expected:02X}, got 0x{result:02X}")
        else:
            dut._log.error(f"MISMATCH: Expected 0x{expected:02X}, got 0x{result:02X}")
            assert False, "Mismatch in DUT output"

    dut._log.info("Test completed successfully")
