`timescale 1ns / 1ps

module sevenseg_driver_8dig(
    input  wire       clk,
    input  wire       reset,
    input  wire [3:0] d0,
    input  wire [3:0] d1,
    input  wire [3:0] d2,
    input  wire [3:0] d3,
    input  wire [3:0] d4,
    input  wire [3:0] d5,
    input  wire [3:0] d6,
    input  wire [3:0] d7,
    output reg  [7:0] an,
    output reg  [6:0] seg,
    output reg        dp
);
    reg [2:0] idx;
    reg [15:0] div;

    reg [3:0] cur_digit;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            div <= 0;
            idx <= 0;
        end else begin
            div <= div + 16'd1;
            if (div == 16'd0) begin
                idx <= idx + 3'd1;
            end
        end
    end

    always @* begin
        case (idx)
            3'd0: begin an = 8'b1111_1110; cur_digit = d0; end
            3'd1: begin an = 8'b1111_1101; cur_digit = d1; end
            3'd2: begin an = 8'b1111_1011; cur_digit = d2; end
            3'd3: begin an = 8'b1111_0111; cur_digit = d3; end
            3'd4: begin an = 8'b1110_1111; cur_digit = d4; end
            3'd5: begin an = 8'b1101_1111; cur_digit = d5; end
            3'd6: begin an = 8'b1011_1111; cur_digit = d6; end
            default: begin an = 8'b0111_1111; cur_digit = d7; end
        endcase

        dp = 1'b1; // decimal points off

        case (cur_digit)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111;
        endcase
    end
endmodule
