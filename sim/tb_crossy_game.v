`timescale 1ns / 1ps

module tb_crossy_game;

    reg        clk_pix;
    reg        reset;
    reg        frame_tick;
    reg        btnU, btnD, btnL, btnR, btnC;
    reg  [9:0] pixel_x, pixel_y;
    reg        display_en;

    wire [3:0] vga_r, vga_g, vga_b;
    wire [3:0] score_d0, score_d1, score_d2, score_d3;
    wire [3:0] score_d4, score_d5, score_d6, score_d7;

    crossy_game dut (
        .clk_pix    (clk_pix),
        .reset      (reset),
        .frame_tick (frame_tick),
        .btnU       (btnU),
        .btnD       (btnD),
        .btnL       (btnL),
        .btnR       (btnR),
        .btnC       (btnC),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .display_en (display_en),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .score_d0   (score_d0),
        .score_d1   (score_d1),
        .score_d2   (score_d2),
        .score_d3   (score_d3),
        .score_d4   (score_d4),
        .score_d5   (score_d5),
        .score_d6   (score_d6),
        .score_d7   (score_d7)
    );

    // pixel clock (any reasonable frequency for sim)
    always #10 clk_pix = ~clk_pix;

    integer ft_cnt;
    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            ft_cnt     <= 0;
            frame_tick <= 1'b0;
        end else begin
            if (ft_cnt == 999) begin
                frame_tick <= 1'b1;
                ft_cnt     <= 0;
            end else begin
                frame_tick <= 1'b0;
                ft_cnt     <= ft_cnt + 1;
            end
        end
    end

    initial begin
        pixel_x    = 10'd0;
        pixel_y    = 10'd0;
        display_en = 1'b1;
    end

    initial begin
        clk_pix = 1'b0;
        reset   = 1'b1;

        btnU = 0; btnD = 0; btnL = 0; btnR = 0; btnC = 0;

        #200;
        reset = 1'b0;

        // Wait in start screen
        repeat (2000) @(posedge clk_pix);

        // Press center to start game
        btnC = 1'b1;
        repeat (50) @(posedge clk_pix);
        btnC = 1'b0;

        // Wait a bit
        repeat (5000) @(posedge clk_pix);

        // Some UP presses
        repeat (10) begin
            btnU = 1'b1;
            repeat (1000) @(posedge clk_pix);
            btnU = 1'b0;
            repeat (2000) @(posedge clk_pix);
        end

        $display("FINAL SCORE BCD = %0d%0d%0d%0d_%0d%0d%0d%0d",
                 score_d7, score_d6, score_d5, score_d4,
                 score_d3, score_d2, score_d1, score_d0);

        $stop;
    end

endmodule
