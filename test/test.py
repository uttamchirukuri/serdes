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

    # ---------------- Test vector 1 ----------------
    pattern1 = 0x3C
    result1 = await shift_in_byte(dut, pattern1)
    norm1 = normalize_result(result1, pattern1)
    if norm1 is None:
        result1 = await shift_in_byte(dut, pattern1)
        norm1 = normalize_result(result1, pattern1)
    dut._log.info(f"Captured byte 1 = 0x{result1:02X} (normalized=0x{norm1:02X})")
    assert norm1 == pattern1, f"Expected 0x{pattern1:02X}, got 0x{result1:02X}"

    # ---------------- Test vector 2 ----------------
    pattern2 = 0xA5
    result2 = await shift_in_byte(dut, pattern2)
    norm2 = normalize_result(result2, pattern2)
    if norm2 is None:
        result2 = await shift_in_byte(dut, pattern2)
        norm2 = normalize_result(result2, pattern2)
    dut._log.info(f"Captured byte 2 = 0x{result2:02X} (normalized=0x{norm2:02X})")
    assert norm2 == pattern2, f"Expected 0x{pattern2:02X}, got 0x{result2:02X}"

    # ---------------- Test vector 3 ----------------
    pattern3 = 0xFF
    result3 = await shift_in_byte(dut, pattern3)
    norm3 = normalize_result(result3, pattern3)
    if norm3 is None:
        result3 = await shift_in_byte(dut, pattern3)
        norm3 = normalize_result(result3, pattern3)
    dut._log.info(f"Captured byte 3 = 0x{result3:02X} (normalized=0x{norm3:02X})")
    assert norm3 == pattern3, f"Expected 0x{pattern3:02X}, got 0x{result3:02X}"

    # ---------------- Test vector 4 ----------------
    pattern4 = 0x12
    result4 = await shift_in_byte(dut, pattern4)
    norm4 = normalize_result(result4, pattern4)
    if norm4 is None:
        result4 = await shift_in_byte(dut, pattern4)
        norm4 = normalize_result(result4, pattern4)
    dut._log.info(f"Captured byte 4 = 0x{result4:02X} (normalized=0x{norm4:02X})")
    assert norm4 == pattern4, f"Expected 0x{pattern4:02X}, got 0x{result4:02X}"

    dut._log.info("Test completed successfully")
