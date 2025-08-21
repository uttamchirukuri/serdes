# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


def simple_filter(input_bits):
    """
    Python model of the 3-tap moving average filter used in project.v
    (low-pass smoothing of the serial output).
    """
    y = []
    for i in range(len(input_bits)):
        prev2 = input_bits[i - 2] if i >= 2 else 0
        prev1 = input_bits[i - 1] if i >= 1 else 0
        curr  = input_bits[i]
        avg = (prev2 + prev1 + curr) // 3
        y.append(avg)
    return y


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start simulation with filtering enabled")

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

    # Allow time for encryption + filter latency
    await ClockCycles(dut.clk, 15)

    # Capture filtered output bits
    filtered_bits = []
    for _ in range(8):
        filtered_bits.append(dut.uo_out.value.integer & 1)  # serial_out (filtered)
        await ClockCycles(dut.clk, 1)

    # Convert to integer
    filtered_result = 0
    for bit in filtered_bits:
        filtered_result = (filtered_result << 1) | bit

    dut._log.info(f"Filtered encrypted result (serial): {filtered_result:02X}")

    # Optional golden model check
    ref_bits = simple_filter(filtered_bits)
    dut._log.info(f"Reference filtered bits (Python model): {ref_bits}")

    # Check done flag went high at some point
    assert ((dut.uo_out.value.integer >> 1) & 1) == 1, "Done signal did not go high"
