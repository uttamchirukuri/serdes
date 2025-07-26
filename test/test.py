# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

A = 0xC3  # 11000011
B = 0x5A  # 01011010

# Trigger 'start' for 1 clock
dut.ui_in.value = 0b00000001  # ui_in[0] = start
await ClockCycles(dut.clk, 1)
dut.ui_in.value = 0  # Clear start
await ClockCycles(dut.clk, 1)

# Serially shift 8 bits of a_bit and b_bit (MSB to LSB)
for i in range(7, -1, -1):
    a_bit = (A >> i) & 1
    b_bit = (B >> i) & 1
    dut.ui_in.value = (b_bit << 2) | (a_bit << 1)  # ui_in[2] = b_bit, ui_in[1] = a_bit
    await ClockCycles(dut.clk, 1)

# Wait for encryption + output shift
await ClockCycles(dut.clk, 20)

# Log final output
dut._log.info(f"uo_out = {dut.uo_out.value.integer:08b}")

# Check if 'done' (uo_out[1]) went high
assert ((dut.uo_out.value.integer >> 1) & 1) == 1, "Done signal did not go high"



    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
