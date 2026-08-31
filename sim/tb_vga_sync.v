`timescale 1ns / 1ps

module tb_vga_sync;

    reg clk;
    reg reset;

    wire [9:0] x;
    wire [9:0] y;
    wire       hsync;
    wire       vsync;
    wire       display_en;
    wire       pix_clk;
    wire       frame_tick;

    vga_sync dut (
        .clk        (clk),
        .reset      (reset),
        .x          (x),
        .y          (y),
        .hsync      (hsync),
        .vsync      (vsync),
        .display_en (display_en),
        .pix_clk    (pix_clk),
        .frame_tick (frame_tick)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    initial begin
        clk   = 1'b0;
        reset = 1'b1;

        #100;
        reset = 1'b0;

        #50_000_000;  // 50 ms

        $display("tb_vga_sync finished.");
        $stop;
    end

    always @(posedge frame_tick) begin
        $display("[%0t] Frame tick: x=%0d y=%0d display_en=%b",
                 $time, x, y, display_en);
    end

    always @(negedge hsync) begin
        $display("[%0t] HSYNC start: x=%0d y=%0d", $time, x, y);
    end

    always @(negedge vsync) begin
        $display("[%0t] VSYNC start: x=%0d y=%0d", $time, x, y);
    end

endmodule
