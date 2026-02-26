`timescale 1ns / 1ps

module sevenseg_driver(
    input  wire       clk,      // 100 MHz system clock
    input  wire       reset,    // active high reset

    input  wire [3:0] d0,       // least significant digit
    input  wire [3:0] d1,
    input  wire [3:0] d2,
    input  wire [3:0] d3,
    input  wire [3:0] d4,
    input  wire [3:0] d5,
    input  wire [3:0] d6,
    input  wire [3:0] d7,       // most significant digit

    output reg  [7:0] AN,       // active-low anodes AN[7:0]
    output reg        CA,       // active-low segment A
    output reg        CB,
    output reg        CC,
    output reg        CD,
    output reg        CE,
    output reg        CF,
    output reg        CG,
    output reg        DP        // active-low decimal point
);

    // 17-bit counter for multiplexing
    reg [16:0] mux_cnt;
    wire [2:0] digit_sel;

    assign digit_sel = mux_cnt[16:14];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mux_cnt <= 17'd0;
        end else begin
            mux_cnt <= mux_cnt + 17'd1;
        end
    end

    reg [3:0] curr_digit;

    always @* begin
        // Default: all digits off
        AN = 8'b11111111;
        curr_digit = 4'd0;

        case (digit_sel)
            3'd0: begin
                AN[0]      = 1'b0;   // right-most digit
                curr_digit = d0;
            end
            3'd1: begin
                AN[1]      = 1'b0;
                curr_digit = d1;
            end
            3'd2: begin
                AN[2]      = 1'b0;
                curr_digit = d2;
            end
            3'd3: begin
                AN[3]      = 1'b0;
                curr_digit = d3;
            end
            3'd4: begin
                AN[4]      = 1'b0;
                curr_digit = d4;
            end
            3'd5: begin
                AN[5]      = 1'b0;
                curr_digit = d5;
            end
            3'd6: begin
                AN[6]      = 1'b0;
                curr_digit = d6;
            end
            3'd7: begin
                AN[7]      = 1'b0;   // left-most digit
                curr_digit = d7;
            end
            default: begin
                AN         = 8'b11111111;
                curr_digit = 4'd0;
            end
        endcase

        // Decode BCD digit to active-low segments
        DP = 1'b1; // decimal point off

        case (curr_digit)
            4'd0: begin // 0
                CA = 1'b0; CB = 1'b0; CC = 1'b0; CD = 1'b0; CE = 1'b0; CF = 1'b0; CG = 1'b1;
            end
            4'd1: begin // 1
                CA = 1'b1; CB = 1'b0; CC = 1'b0; CD = 1'b1; CE = 1'b1; CF = 1'b1; CG = 1'b1;
            end
            4'd2: begin // 2
                CA = 1'b0; CB = 1'b0; CC = 1'b1; CD = 1'b0; CE = 1'b0; CF = 1'b1; CG = 1'b0;
            end
            4'd3: begin // 3
                CA = 1'b0; CB = 1'b0; CC = 1'b0; CD = 1'b0; CE = 1'b1; CF = 1'b1; CG = 1'b0;
            end
            4'd4: begin // 4
                CA = 1'b1; CB = 1'b0; CC = 1'b0; CD = 1'b1; CE = 1'b1; CF = 1'b0; CG = 1'b0;
            end
            4'd5: begin // 5
                CA = 1'b0; CB = 1'b1; CC = 1'b0; CD = 1'b0; CE = 1'b1; CF = 1'b0; CG = 1'b0;
            end
            4'd6: begin // 6
                CA = 1'b0; CB = 1'b1; CC = 1'b0; CD = 1'b0; CE = 1'b0; CF = 1'b0; CG = 1'b0;
            end
            4'd7: begin // 7
                CA = 1'b0; CB = 1'b0; CC = 1'b0; CD = 1'b1; CE = 1'b1; CF = 1'b1; CG = 1'b1;
            end
            4'd8: begin // 8
                CA = 1'b0; CB = 1'b0; CC = 1'b0; CD = 1'b0; CE = 1'b0; CF = 1'b0; CG = 1'b0;
            end
            4'd9: begin // 9
                CA = 1'b0; CB = 1'b0; CC = 1'b0; CD = 1'b0; CE = 1'b1; CF = 1'b0; CG = 1'b0;
            end
            default: begin // blank
                CA = 1'b1; CB = 1'b1; CC = 1'b1; CD = 1'b1; CE = 1'b1; CF = 1'b1; CG = 1'b1;
            end
        endcase
    end

endmodule
