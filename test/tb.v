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

    // Clock generator
    always #5 clk = ~clk;

    // Task to send one byte serially (LSB first)
    task send_byte(input [7:0] data);
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                ui_in[0] = data[i];
                #10;  // 1 clock cycle at 100MHz (10ns)
            end
        end
    endtask

    // Test sequence
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        clk   = 0;
        rst_n = 0;
        ena   = 0;
        ui_in = 8'd0;
        uio_in= 8'd0;

        #20 rst_n = 1;
        #10 ena = 1;

        // Send 0xAA (10101010)
        send_byte(8'hAA);

        // Send 0xCC (11001100)
        send_byte(8'hCC);

        #100;
        $finish;
    end

endmodule
