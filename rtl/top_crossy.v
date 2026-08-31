`timescale 1ns / 1ps

module top_crossy(
    input  wire CLK100MHZ,
    input  wire CPU_RESETN,  // active low reset button

    input  wire BTNC,
    input  wire BTNU,
    input  wire BTND,
    input  wire BTNL,
    input  wire BTNR,

    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,

    output wire       CA,
    output wire       CB,
    output wire       CC,
    output wire       CD,
    output wire       CE,
    output wire       CF,
    output wire       CG,
    output wire       DP,
    output wire [7:0] AN
);

    wire reset = ~CPU_RESETN;  // convert board's active-low to active-high

    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       display_en;
    wire       pix_clk;
    wire       frame_tick;

    // VGA timing generator
    vga_sync vga_inst (
        .clk        (CLK100MHZ),
        .reset      (reset),
        .x          (x),
        .y          (y),
        .hsync      (hsync),
        .vsync      (vsync),
        .display_en (display_en),
        .pix_clk    (pix_clk),
        .frame_tick (frame_tick)
    );

    // Game renderer + score
    wire [3:0] r;
    wire [3:0] g;
    wire [3:0] b;

    wire [3:0] score_d0;
    wire [3:0] score_d1;
    wire [3:0] score_d2;
    wire [3:0] score_d3;
    wire [3:0] score_d4;
    wire [3:0] score_d5;
    wire [3:0] score_d6;
    wire [3:0] score_d7;

    crossy_game game_inst (
        .clk_pix    (pix_clk),
        .reset      (reset),
        .frame_tick (frame_tick),
        .btnU       (BTNU),
        .btnD       (BTND),
        .btnL       (BTNL),
        .btnR       (BTNR),
        .btnC       (BTNC),
        .pixel_x    (x),
        .pixel_y    (y),
        .display_en (display_en),
        .vga_r      (r),
        .vga_g      (g),
        .vga_b      (b),
        .score_d0   (score_d0),
        .score_d1   (score_d1),
        .score_d2   (score_d2),
        .score_d3   (score_d3),
        .score_d4   (score_d4),
        .score_d5   (score_d5),
        .score_d6   (score_d6),
        .score_d7   (score_d7)
    );

    assign VGA_R = r;
    assign VGA_G = g;
    assign VGA_B = b;
    assign VGA_HS = hsync;
    assign VGA_VS = vsync;

    // Seven-seg driver
    sevenseg_driver seg_inst (
        .clk   (CLK100MHZ),
        .reset (reset),
        .d0    (score_d0),
        .d1    (score_d1),
        .d2    (score_d2),
        .d3    (score_d3),
        .d4    (score_d4),
        .d5    (score_d5),
        .d6    (score_d6),
        .d7    (score_d7),
        .AN    (AN),
        .CA    (CA),
        .CB    (CB),
        .CC    (CC),
        .CD    (CD),
        .CE    (CE),
        .CF    (CF),
        .CG    (CG),
        .DP    (DP)
    );

endmodule
