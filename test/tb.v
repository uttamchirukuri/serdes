`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // VCD Dump
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
  end

  // DUT Interface
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate DUT
  tt_um_secure_serdes_encryptor user_project (
`ifdef GL_TEST
    .VPWR(VPWR),
    .VGND(VGND),
`endif
    .clk    (clk),
    .rst_n  (rst_n),
    .ena    (ena),
    .ui_in  (ui_in),
    .uo_out (uo_out),
    .uio_in (uio_in),
    .uio_out(uio_out),
    .uio_oe (uio_oe)
  );

  // Clock generation: 10ns period
  always #5 clk = ~clk;

  // Internal test registers
  reg [7:0] A_data = 8'h02; // 11000011
  reg [7:0] B_data = 8'h03; // 01011010
  integer i;

  initial begin
    // Initialize
    clk = 0;
    rst_n = 0;
    ena = 1;
    ui_in = 0;
    uio_in = 0;

    // Apply reset
    #20 rst_n = 1;

    // Pulse start = 1 for 1 cycle
    ui_in[0] = 1'b1;  // start
    #10;
    ui_in[0] = 1'b0;  // stop start signal

    // Shift in 8 bits MSB to LSB
    for (i = 7; i >= 0; i = i - 1) begin
      ui_in[1] = A_data[i];  // a_bit
      ui_in[2] = B_data[i];  // b_bit
      #10;
    end

    // Wait to observe cipher output and done
   // #50 $finish;
  end

endmodule
