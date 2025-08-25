`default_nettype none
`timescale 1ns / 1ps

module testbench;

    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;       // input bus
    reg [7:0] uio_in;      // not used
    wire [7:0] uio_out;    // not used
    wire [7:0] uio_oe;     // not used
    wire [7:0] uo_out;     // output bus

    // Instantiate DUT
    tt_um_serdes dut (
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .clk(clk),
        .rst_n(rst_n),
        .uo_out(uo_out),
        .ena(ena)
    );

    // Clock generator
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, testbench);

        clk   = 0;
        rst_n = 0;
        ena   = 0;
        ui_in = 8'd0;
        uio_in= 8'd0;

        #20 rst_n = 1;
        #10 ena = 1;

        // Send serial pattern: 10101010
        repeat (8) begin
            ui_in[0] = $random;  // toggle serial input
            #10;
        end

        // Another byte
        repeat (8) begin
            ui_in[0] = $random;
            #10;
        end

        #100;
        $finish;
    end

endmodule

