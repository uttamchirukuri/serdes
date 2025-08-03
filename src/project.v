/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

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

    wire [127:0] key = 128'hA1B2_C3D4_E5F6_0123_4567_89AB_CDEF_1234;

    // Map input signals
    wire start = ui_in[0];
    wire a_bit = ui_in[1];
    wire b_bit = ui_in[2];
    wire rst   = ~rst_n;

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
