# SPDX-FileCopyrightText: © 2025
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


async def shift_in_byte(dut, pattern: int):
    """Shift in an 8-bit pattern (LSB first, matches tb.v)."""
    for i in range(8):
        bit = (pattern >> i) & 1  # LSB first
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)
    await ClockCycles(dut.clk, 1)
    return dut.uo_out.value.integer


def normalize_result(result: int, expected: int) -> int:
    """Normalize DUT output to match expected."""
    # Ignore sync word if DUT outputs one
    if result == 0x7E:
        return None
    return result


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start simulation")

    # Clock 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Apply reset and enable
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)  # longer reset
    dut.rst_n.value = 1
    dut.ena.value = 1
    dut._log.info("Reset done")

    # ---------------- Test vector ----------------
    pattern1 = 0xFF
    result1 = await shift_in_byte(dut, pattern1)
    norm1 = normalize_result(result1, pattern1)
    if norm1 is None:
        result1 = await shift_in_byte(dut, pattern1)
        norm1 = normalize_result(result1, pattern1)
    dut._log.info(f"Captured byte 1 = 0x{result1:02X} (normalized=0x{norm1:02X})")
    assert norm1 == pattern1, f"Expected 0x{pattern1:02X}, got 0x{result1:02X}"

    dut._log.info("Test completed successfully")
