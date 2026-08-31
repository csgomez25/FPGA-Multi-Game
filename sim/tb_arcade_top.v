`timescale 1ns / 1ps

module tb_arcade_top;
    reg CLK100MHZ = 0;
    reg btnU = 0, btnD = 0, btnL = 0, btnR = 0, btnC = 0;
    reg reset = 1;

    wire Hsync, Vsync;
    wire [3:0] vgaRed, vgaGreen, vgaBlue;
    wire [7:0] an;
    wire [6:0] seg;
    wire dp;

    arcade_top dut(
        .CLK100MHZ(CLK100MHZ),
        .btnU(btnU), .btnD(btnD), .btnL(btnL), .btnR(btnR), .btnC(btnC),
        .reset(reset),
        .Hsync(Hsync), .Vsync(Vsync),
        .vgaRed(vgaRed), .vgaGreen(vgaGreen), .vgaBlue(vgaBlue),
        .an(an), .seg(seg), .dp(dp)
    );

    always #5 CLK100MHZ = ~CLK100MHZ; // 100 MHz

    initial begin
        // Reset
        #100;
        reset = 0;

        // Wait on menu, then select Snake
        #100000;
        btnR = 1; #100000; btnR = 0;
        #200000;
        btnC = 1; #100000; btnC = 0;

        // Run some time in Snake
        #2000000;

        $stop;
    end
endmodule
