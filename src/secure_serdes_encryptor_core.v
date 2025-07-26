module secure_serdes_encryptor_core (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [127:0] key,
    input wire a_bit,
    input wire b_bit,
    output reg cipher_out,
    output reg done
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
                    if (start) begin
                        bit_cnt <= 0;
                        A <= 0; B <= 0;
                        done <= 0;
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
                    bit_cnt <= bit_cnt + 1;
                    if (bit_cnt == 3'd7) begin
                        state <= IDLE;
                        done <= 1;
                    end
                end
            endcase
        end
    end

endmodule
