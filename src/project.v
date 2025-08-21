/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// -------------------- FIR Low-Pass Filter --------------------
module fir_filter #(
    parameter N = 8,    // data width
    parameter TAPS = 4  // number of taps
)(
    input  wire             clk,
    input  wire             rst,
    input  wire signed [N-1:0] din,
    output reg  signed [N-1:0] dout
);

    // Example coefficients: [1 2 2 1]
    reg signed [N-1:0] coeff [0:TAPS-1];
    initial begin
        coeff[0] = 8'd1;
        coeff[1] = 8'd2;
        coeff[2] = 8'd2;
        coeff[3] = 8'd1;
    end

    // Shift register for past inputs
    reg signed [N-1:0] shift_reg [0:TAPS-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < TAPS; i = i+1)
                shift_reg[i] <= 0;
            dout <= 0;
        end else begin
            // Shift
            for (i = TAPS-1; i > 0; i = i-1)
                shift_reg[i] <= shift_reg[i-1];
            shift_reg[0] <= din;

            // FIR sum of products
            integer acc;
            acc = 0;
            for (i = 0; i < TAPS; i = i+1)
                acc = acc + shift_reg[i] * coeff[i];

            dout <= acc >>> 3;  // scaling
        end
    end

endmodule

// -------------------- Original Core --------------------
module secure_serdes_encryptor_core (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [127:0] key,
    input  wire        a_bit,
    input  wire        b_bit,
    output reg         cipher_out,
    output reg         done
);

    reg [7:0] A, B;
    reg [2:0] bit_cnt;
    reg [7:0] encrypted_byte;
    reg [1:0] state;

    localparam IDLE    = 2'b00;
    localparam SHIFT   = 2'b01;
    localparam ENCRYPT = 2'b10;
    localparam OUTPUT  = 2'b11;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            A <= 0; B <= 0; bit_cnt <= 0;
            encrypted_byte <= 0;
            state <= IDLE;
            cipher_out <= 0;
            done <= 0;
        end else begin
            case (state)

                IDLE: begin
                    cipher_out <= 0;
                    if (start) begin
                        done <= 0;      // clear done on new start
                        bit_cnt <= 0;
                        A <= 0; B <= 0;
                        state <= SHIFT;
                    end
                end

                SHIFT: begin
                    A <= {A[6:0], a_bit};
                    B <= {B[6:0], b_bit};
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == 3'd7)
                        state <= ENCRYPT;
                end

                ENCRYPT: begin
                    encrypted_byte <= A ^ B ^ key[7:0];
                    bit_cnt <= 0;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    cipher_out <= encrypted_byte[7];
                    encrypted_byte <= {encrypted_byte[6:0], 1'b0};

                    if (bit_cnt == 3'd7) begin
                        done <= 1;      // latch done high
                        state <= IDLE;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule

// -------------------- Wrapper with Filters --------------------
module tt_um_serdes (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire [127:0] key = 128'hA1B2_C3D4_E5F6_0123_4567_89AB_CDEF_1234;

    // Map input signals
    wire start = ui_in[0];
    wire rst   = ~rst_n;

    // Filtered inputs
    wire [7:0] a_filtered, b_filtered;

    fir_filter in_filter_a (
        .clk(clk),
        .rst(rst),
        .din({7'b0, ui_in[1]}),   // expand single bit to 8-bit
        .dout(a_filtered)
    );

    fir_filter in_filter_b (
        .clk(clk),
        .rst(rst),
        .din({7'b0, ui_in[2]}),
        .dout(b_filtered)
    );

    // Core outputs
    wire cipher_raw;
    wire done;

    secure_serdes_encryptor_core core (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a_bit(a_filtered[0]),   // use filtered LSB
        .b_bit(b_filtered[0]),
        .key(key),
        .cipher_out(cipher_raw),
        .done(done)
    );

    // Output filter
    wire [7:0] cipher_filtered;
    fir_filter out_filter (
        .clk(clk),
        .rst(rst),
        .din({7'b0, cipher_raw}),
        .dout(cipher_filtered)
    );

    assign uo_out[0] = cipher_filtered[0];
    assign uo_out[1] = done;
    assign uo_out[7:2] = 0;

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

endmodule
