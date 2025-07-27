# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start simulation")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Apply reset
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    dut._log.info("Reset done")

    # Set input values
    A = 0x02  # 00000010
    B = 0x03  # 00000011

    # Trigger start for 1 clock
    dut.ui_in.value = 0b00000001  # ui_in[0] = start
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0  # Clear start
    await ClockCycles(dut.clk, 1)

    # Serially shift 8 bits of a_bit and b_bit (MSB to LSB)
    for i in range(7, -1, -1):
        a_bit = (A >> i) & 1
        b_bit = (B >> i) & 1
        dut.ui_in.value = (b_bit << 2) | (a_bit << 1)  # [2]=b_bit, [1]=a_bit
        await ClockCycles(dut.clk, 1)

    # Wait for encryption + output shift
    await ClockCycles(dut.clk, 10)

    # Capture output bits
    result_bits = []
    for _ in range(8):
        result_bits.append(dut.uo_out.value.integer & 1)
        await ClockCycles(dut.clk, 1)

    # Combine bits into final byte
    result = 0
    for bit in result_bits:
        result = (result << 1) | bit

    dut._log.info(f"Encrypted result: {result:02X}")
    assert ((dut.uo_out.value.integer >> 1) & 1) == 1, "Done signal did not go high"
