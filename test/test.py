import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def shift_in_byte(dut, pattern: int):
    """Shift in an 8-bit pattern (LSB first, matches tb.v)."""
    for i in range(8):
        bit = (pattern >> i) & 1
        dut.ui_in.value = bit
        await ClockCycles(dut.clk, 1)

    # Wait one extra cycle for DUT to latch
    await ClockCycles(dut.clk, 1)

    # Retry until output is resolved (avoid 'x' crash in GL sim)
    for _ in range(10):
        val = dut.uo_out.value
        if "x" not in str(val):
            return val.integer
        await ClockCycles(dut.clk, 1)

    dut._log.warning("uo_out stayed 'x' after shift")
    return None


@cocotb.test()
async def test_dut(dut):
    """Basic test for TinyTapeout DUT with safer reset/enable sequence."""

    # Start 100 MHz clock (10 ns period)
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

    # === Example test ===
    test_byte = 0xA5
    dut._log.info(f"Sending byte 0x{test_byte:02X}")
    result = await shift_in_byte(dut, test_byte)

    if result is None:
        assert False, "Test failed: DUT never produced valid data"
    else:
        dut._log.info(f"Received 0x{result:02X}")
        assert result == test_byte, f"Expected 0x{test_byte:02X}, got 0x{result:02X}"
