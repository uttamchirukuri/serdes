# SPDX-FileCopyrightText: © 2025
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_serdes(dut):
    dut._log.info("Start simulation")

    # Clock 100 MHz
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Apply reset
    dut.ena.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut.ena.value = 1
    dut._log.info("Reset done")

    # Test pattern 1: 0b10101010
    pattern1 = 0b10101010
    for i in range(8):
        bit = (pattern1 >> (7 - i)) & 1  # MSB first
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)

    # After 8 bits, uo_out should equal pattern1
    await ClockCycles(dut.clk, 1)
    result1 = dut.uo_out.value.integer
    dut._log.info(f"Captured byte 1 = 0x{result1:02X}")
    assert result1 == pattern1, f"Expected {pattern1:08b}, got {result1:08b}"

    # Test pattern 2: 0b11001100
    pattern2 = 0b11001100
    for i in range(8):
        bit = (pattern2 >> (7 - i)) & 1
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)

    await ClockCycles(dut.clk, 1)
    result2 = dut.uo_out.value.integer
    dut._log.info(f"Captured byte 2 = 0x{result2:02X}")
    assert result2 == pattern2, f"Expected {pattern2:08b}, got {result2:08b}"

    dut._log.info("Test completed successfully")
