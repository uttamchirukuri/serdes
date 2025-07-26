`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a VCD file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
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

  // Replace tt_um_example with your module name:
  tt_um_secure_serdes_encryptor user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );
 // Clock generation
  always #5 clk = ~clk;

  // Test data
  reg [7:0] A_data = 8'hC3;
  reg [7:0] B_data = 8'h5A;
  integer i;

  initial begin
    // Init
    clk = 0;
    rst_n = 0;
    ena = 1;
    ui_in = 8'b0;
    uio_in = 8'b0;

    // Apply reset
    #12 rst_n = 1;

    // Start encryption
    #10 ui_in[0] = 1'b1; // start signal

    // Feed serial bits (MSB first)
    for (i = 7; i >= 0; i = i - 1) begin
      #10 ui_in[1] = A_data[i]; // a_bit
           ui_in[2] = B_data[i]; // b_bit
    end

    // Clear start signal
    #10 ui_in[0] = 1'b0;

    // Wait for done signal
    #200 $finish;
  end
   
   
endmodule
