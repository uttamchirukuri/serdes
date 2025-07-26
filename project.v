/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none



module tt_um_secure_serdes_encryptor (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Map input signals
    wire start     = ui_in[0];
    wire a_bit     = ui_in[1];
    wire b_bit     = ui_in[2];
    wire rst       = ~rst_n;

    // Output signals
    wire cipher_bit;
    wire done;


    secure_serdes_encryptor_core core (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a_bit(a_bit),
        .b_bit(b_bit),
        .key(key),
        .cipher_out(cipher_bit),
        .done(done)
    );

    assign uo_out[0] = cipher_bit;
    assign uo_out[1] = done;
    assign uo_out[7:2] = 0;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule
