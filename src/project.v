/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ps

module tt_um_serdes (
    // TinyTapeout template ports
    input  wire [7:0] ui_in,    // dedicated inputs  (ui_in[0] = serial in)
    input  wire [7:0] uio_in,   // bidirectional inputs (unused)
    output wire [7:0] uio_out,  // bidirectional outputs (unused -> 0)
    output wire [7:0] uio_oe,   // bidirectional enables (unused -> 0)
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset (active low)
    output reg  [7:0] uo_out,   // dedicated outputs: [0]=serial out, [1]=done pulse, [7:2]=0
    input  wire       ena       // enable
);

    // ----------------------------------------------------------------
    // Constant/parameters
    // ----------------------------------------------------------------
    // Lightweight XOR key (override at instantiation if desired)
    localparam [7:0] KEY = 8'hA5;

    // ----------------------------------------------------------------
    // Unused bidirectional ports tied off
    // ----------------------------------------------------------------
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // ----------------------------------------------------------------
    // Serial input
    // ----------------------------------------------------------------
    wire si = ui_in[0];

    // ----------------------------------------------------------------
    // Internal registers
    // ----------------------------------------------------------------
    // Deserializer
    reg  [7:0] rx_shift;
    reg  [2:0] rx_cnt;
    reg  [7:0] rx_byte;

    // FIR delay line (most-recent sample = x0, then x1=d1, x2=d2, x3=d3)
    reg  [7:0] d1, d2, d3;
    reg  [7:0] fir_out;

    // Encrypt + Serializer
    reg  [7:0] enc_byte;
    reg  [7:0] tx_shift;
    reg  [2:0] tx_cnt;

    // Simple FSM
    typedef enum logic [2:0] {
        S_IDLE  = 3'd0,  // wait for ena
        S_RX    = 3'd1,  // collect 8 serial bits
        S_FIR   = 3'd2,  // compute FIR output
        S_ENC   = 3'd3,  // XOR with KEY, load TX
        S_TX    = 3'd4,  // shift out 8 bits (MSB-first)
        S_DONE  = 3'd5   // 1-cycle done pulse
    } state_t;

    state_t state;

    // ----------------------------------------------------------------
    // Main sequential logic
    // ----------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Outputs
            uo_out    <= 8'd0;

            // Deserializer
            rx_shift  <= 8'd0;
            rx_cnt    <= 3'd0;
            rx_byte   <= 8'd0;

            // FIR delay line
            d1        <= 8'd0;
            d2        <= 8'd0;
            d3        <= 8'd0;
            fir_out   <= 8'd0;

            // Encrypt + serializer
            enc_byte  <= 8'd0;
            tx_shift  <= 8'd0;
            tx_cnt    <= 3'd0;

            // FSM
            state     <= S_IDLE;

        end else begin
            // Default outputs each cycle
            uo_out[7:2] <= 6'b0;  // keep unused outputs at 0
            uo_out[1]   <= 1'b0;  // done is a pulse; default low
            // uo_out[0] is driven in states

            if (!ena) begin
                // If not enabled, hold safe state
                uo_out[0] <= 1'b0;
                state     <= S_IDLE;
                rx_shift  <= 8'd0;
                rx_cnt    <= 3'd0;
                tx_cnt    <= 3'd0;
            end else begin
                case (state)
                    // ------------------------------------------------
                    S_IDLE: begin
                        // Wait for ena (already true) and start receiving
                        uo_out[0] <= 1'b0;
                        rx_shift  <= 8'd0;
                        rx_cnt    <= 3'd0;
                        state     <= S_RX;
                    end

                    // ------------------------------------------------
                    // Collect 8 serial bits, LSB-first or MSB-first?
                    // Here: shift MSB-first OUT later, but we *capture* LSB-first
                    // to mirror earlier examples; final byte = {rx_shift[6:0], si}
                    S_RX: begin
                        uo_out[0] <= 1'b0;
                        rx_shift  <= {rx_shift[6:0], si};
                        if (rx_cnt == 3'd7) begin
                            rx_byte <= {rx_shift[6:0], si};
                            state   <= S_FIR;
                            rx_cnt  <= 3'd0;
                        end else begin
                            rx_cnt  <= rx_cnt + 3'd1;
                        end
                    end

                    // ------------------------------------------------
                    // 4-tap FIR: y = (1*x0 + 2*x1 + 2*x2 + 1*x3) >> 2
                    // Update delay line and compute output
                    S_FIR: begin
                        // Update delay line: newest sample is rx_byte
                        d3 <= d2;
                        d2 <= d1;
                        d1 <= rx_byte;

                        // Compute with the *previous* taps (use blocking math)
                        // Using 10-bit wide temporary to avoid overflow locally
                        // But we store the scaled 8-bit result in fir_out
                        // Note: because delay line updates on this clock,
                        // you can choose to compute FIR using old d1/d2/d3 and rx_byte
                        // as x0. That's what we do here:
                        begin : fir_compute
                            // acc width big enough: 8b*coeff + sum => up to 10b
                            integer acc;
                            acc = (rx_byte)      // 1*x0
                                + (d1 << 1)     // 2*x1
                                + (d2 << 1)     // 2*x2
                                + (d3);         // 1*x3
                            fir_out <= acc[9:2]; // >>2 scale, keep 8 MSBs
                        end
                        state <= S_ENC;
                    end

                    // ------------------------------------------------
                    // XOR encryption & load serializer
                    S_ENC: begin
                        enc_byte <= fir_out ^ KEY;
                        tx_shift <= fir_out ^ KEY; // load into TX shift register
                        tx_cnt   <= 3'd7;
                        // Drive first (MSB) output bit on next state
                        state    <= S_TX;
                    end

                    // ------------------------------------------------
                    // Shift out MSB-first on uo_out[0]
                    S_TX: begin
                        uo_out[0] <= tx_shift[7];
                        tx_shift  <= {tx_shift[6:0], 1'b0};

                        if (tx_cnt == 3'd0) begin
                            // Just emitted the last bit
                            state   <= S_DONE;
                        end else begin
                            tx_cnt  <= tx_cnt - 3'd1;
                        end
                    end

                    // ------------------------------------------------
                    // One-cycle done pulse
                    S_DONE: begin
                        uo_out[0] <= 1'b0;
                        uo_out[1] <= 1'b1;  // pulse
                        // Immediately go back to receive next byte
                        state     <= S_RX;
                    end

                    // ------------------------------------------------
                    default: begin
                        state <= S_IDLE;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
