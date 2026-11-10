`timescale 1ns/1ps
// Memory Interface with real SECDED ECC logic
// Extended Hamming (13,8): 8 data bits + 4 Hamming parity bits + 1 overall parity bit.
// Data positions: 3,5,6,7,9,10,11,12. Parity positions: 1,2,4,8,13.
module memory_interface #(
    parameter DATA_W = 8,
    parameter MEM_D  = 16,
    parameter CW_W   = 13
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 we,
    input  wire                 re,
    input  wire [3:0]           addr,
    input  wire [DATA_W-1:0]    wdata,
    output reg  [DATA_W-1:0]    rdata,
    output reg                  single_error,
    output reg                  double_error
);
    reg [CW_W-1:0] mem [0:MEM_D-1];
    integer i;

    // Encode one 8-bit data word into a 13-bit SECDED codeword.
    function [12:0] ecc_encode;
        input [7:0] data;
        reg [12:0] cw;
        begin
            cw = 13'b0;
            // Data bits are placed in Hamming positions 3,5,6,7,9,10,11,12.
            cw[2]  = data[0];
            cw[4]  = data[1];
            cw[5]  = data[2];
            cw[6]  = data[3];
            cw[8]  = data[4];
            cw[9]  = data[5];
            cw[10] = data[6];
            cw[11] = data[7];

            // Even Hamming parity bits at positions 1,2,4,8.
            cw[0] = cw[2] ^ cw[4] ^ cw[6] ^ cw[8] ^ cw[10];
            cw[1] = cw[2] ^ cw[5] ^ cw[6] ^ cw[9] ^ cw[10];
            cw[3] = cw[4] ^ cw[5] ^ cw[6] ^ cw[11];
            cw[7] = cw[8] ^ cw[9] ^ cw[10] ^ cw[11];

            // Overall even parity at position 13.
            cw[12] = ^cw[11:0];
            ecc_encode = cw;
        end
    endfunction

    // Decoder result format: {single_error, double_error, corrected_data[7:0]}.
    // SECDED corrects every single-bit error and detects every double-bit error.
    function [9:0] ecc_decode;
        input [12:0] received;
        reg [12:0] corrected;
        reg [3:0] syndrome;
        reg overall_mismatch;
        reg single_flag;
        reg double_flag;
        begin
            syndrome[0] = received[0] ^ received[2] ^ received[4] ^
                          received[6] ^ received[8] ^ received[10];
            syndrome[1] = received[1] ^ received[2] ^ received[5] ^
                          received[6] ^ received[9] ^ received[10];
            syndrome[2] = received[3] ^ received[4] ^ received[5] ^
                          received[6] ^ received[11];
            syndrome[3] = received[7] ^ received[8] ^ received[9] ^
                          received[10] ^ received[11];
            overall_mismatch = ^received;
            corrected = received;
            single_flag = 1'b0;
            double_flag = 1'b0;

            if ((syndrome != 4'd0) && overall_mismatch) begin
                // Odd parity + non-zero syndrome: one error in positions 1..12.
                if (syndrome <= 4'd12) begin
                    corrected[syndrome - 1'b1] = ~corrected[syndrome - 1'b1];
                    single_flag = 1'b1;
                end else begin
                    double_flag = 1'b1;
                end
            end else if ((syndrome == 4'd0) && overall_mismatch) begin
                // Overall parity bit (position 13) alone is incorrect.
                corrected[12] = ~corrected[12];
                single_flag = 1'b1;
            end else if ((syndrome != 4'd0) && !overall_mismatch) begin
                // Non-zero syndrome + even overall parity: two-bit error.
                double_flag = 1'b1;
            end

            ecc_decode = {single_flag, double_flag,
                          corrected[2], corrected[4], corrected[5], corrected[6],
                          corrected[8], corrected[9], corrected[10], corrected[11]};
        end
    endfunction

    wire [12:0] encoded_word;
    wire [9:0] decoded_result;
    assign encoded_word = ecc_encode(wdata[7:0]);
    assign decoded_result = ecc_decode(mem[addr]);

    // Synchronous write and read interface. Read data/status update on the
    // rising clock edge when re=1. A double-error word is flagged; its data
    // output is not guaranteed to be correct and must not be treated as valid.
    always @(posedge clk) begin
        if (rst) begin
            rdata <= {DATA_W{1'b0}};
            single_error <= 1'b0;
            double_error <= 1'b0;
            for (i = 0; i < MEM_D; i = i + 1)
                mem[i] <= {CW_W{1'b0}};
        end else begin
            single_error <= 1'b0;
            double_error <= 1'b0;

            if (we && (addr < MEM_D))
                mem[addr] <= encoded_word;

            if (re && (addr < MEM_D)) begin
                rdata <= decoded_result[7:0];
                single_error <= decoded_result[9];
                double_error <= decoded_result[8];
            end
        end
    end

endmodule
