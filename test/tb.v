`default_nettype none
`timescale 1ns / 1ps

module tb;

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

    // Clock generator: 100MHz (10ns period)
    always #5 clk = ~clk;

    // Task to send one byte serially (LSB first)
    task send_byte(input [7:0] data);
        integer i;
        begin
            $display("[%0t] Sending byte 0x%02h", $time, data);
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[0] = data[i];  // serial input bit
                #10;                 // hold for one clock
            end
        end
    endtask

    // Monitor output serial bitstream
    always @(posedge clk) begin
        if (ena) begin
            $display("[%0t] Output bit: %b", $time, uo_out[0]);
        end
    end

    // Test sequence
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        clk    = 0;
        rst_n  = 0;
        ena    = 0;
        ui_in  = 8'd0;
        uio_in = 8'd0;

        // Reset sequence
        #50 rst_n = 1;

        // Idle cycles before enable
        #20;
        ena = 1;

        // Send test patterns (same style as test.py)
        send_byte(8'h3C);   // example byte
        send_byte(8'hA5);
        send_byte(8'hFF);
        send_byte(8'h12);

        // Extra idle cycles
        #200;
        $finish;
    end

endmodule
