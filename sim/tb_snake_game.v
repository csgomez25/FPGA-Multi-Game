`timescale 1ns / 1ps

module tb_snake_game;
    reg clk_pix = 0;
    reg reset   = 1;
    reg frame_tick = 0;
    reg btnU = 0, btnD = 0, btnL = 0, btnR = 0, btnC = 0;
    reg [9:0] pixel_x = 0;
    reg [9:0] pixel_y = 0;
    reg       display_en = 1;

    wire [3:0] vga_r, vga_g, vga_b;
    wire [3:0] d0,d1,d2,d3,d4,d5,d6,d7;

    snake_game dut(
        .clk_pix(clk_pix),
        .reset(reset),
        .frame_tick(frame_tick),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR), .btnC(btnC),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .display_en(display_en),
        .vga_r(vga_r), .vga_g(vga_g), .vga_b(vga_b),
        .score_d0(d0), .score_d1(d1), .score_d2(d2), .score_d3(d3),
        .score_d4(d4), .score_d5(d5), .score_d6(d6), .score_d7(d7)
    );

    always #20 clk_pix = ~clk_pix;        // 25 MHz-ish
    always #400 frame_tick = ~frame_tick; // fake frame tick

    initial begin
        #200; reset = 0;

        // Press center to start
        #1000; btnC = 1; #400; btnC = 0;

        // Run a while
        #200000;

        $stop;
    end
endmodule
