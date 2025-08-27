/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns / 1ps

// -------------------- Wrapper with Filters --------------------
module tt_um_serdes (
    // TinyTapeout template ports
    input  wire [7:0] ui_in,    // dedicated inputs
    input  wire [7:0] uio_in,   // bidirectional inputs
    output wire [7:0] uio_out,  // bidirectional outputs
    output wire [7:0] uio_oe,   // bidirectional enables
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset (active low)
    output reg  [7:0] uo_out,   // dedicated outputs
    input  wire       ena       // enable
);

    // Unused bidirectional outputs -> set to 0
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Map serial input to ui_in[0]
    wire si = ui_in[0];

    // --- Deserializer (8-bit parallel from serial input) ---
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg;
    reg [7:0] parallel_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt     <= 3'd0;
            shift_reg   <= 8'd0;
            parallel_in <= 8'd0;
        end else if (ena) begin
            shift_reg <= {shift_reg[6:0], si};  // shift in serial data
            bit_cnt   <= bit_cnt + 1;

            if (bit_cnt == 3'd7) begin
                parallel_in <= {shift_reg[6:0], si}; // latch after 8 bits
            end
        end
    end

    // --- FIR filter after deserialization ---
    wire [7:0] filtered_in;
    fir_filter u_fir_in (
        .clk(clk),
        .rst(~rst_n),
        .din(parallel_in),
        .dout(filtered_in)
    );

    // --- Serializer with FIR filter before serialization ---
    reg [2:0] ser_cnt;
    reg [7:0] ser_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ser_cnt <= 3'd0;
            ser_reg <= 8'd0;
            uo_out  <= 8'd0;
        end else if (ena) begin
            // Load filtered parallel data into serializer
            if (ser_cnt == 3'd0) begin
                ser_reg <= filtered_in;
            end else begin
                ser_reg <= {ser_reg[6:0], 1'b0};
            end

            // Output MSB of serialized register
            uo_out[0] <= ser_reg[7];  

            ser_cnt <= ser_cnt + 1;
        end
    end

endmodule
