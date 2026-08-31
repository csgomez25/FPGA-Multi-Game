`timescale 1ns / 1ps

module tb_pong_game;
    reg        clk_pix;
    reg        reset;
    reg        frame_tick;
    reg        btnU, btnD, btnL, btnR, btnC;
    reg  [9:0] pixel_x, pixel_y;
    reg        display_en;
    wire [3:0] vga_r, vga_g, vga_b;
    wire [3:0] score_d0, score_d1, score_d2, score_d3;
    wire [3:0] score_d4, score_d5, score_d6, score_d7;

    // Instantiate the Pong game
    pong_game dut (
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

    // Pixel clock (25 MHz simulation)
    always #20 clk_pix = ~clk_pix;  // 50ns period = 20MHz (close enough)

    // Frame tick generator (simulates ~60 Hz frame rate)
    integer ft_cnt;
    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            ft_cnt     <= 0;
            frame_tick <= 1'b0;
        end else begin
            // Generate frame_tick every 1000 clocks (~50 FPS at 20MHz)
            if (ft_cnt == 999) begin
                frame_tick <= 1'b1;
                ft_cnt     <= 0;
            end else begin
                frame_tick <= 1'b0;
                ft_cnt     <= ft_cnt + 1;
            end
        end
    end

    // Simple pixel position (static for functional sim)
    initial begin
        pixel_x    = 10'd320;  // Center of screen
        pixel_y    = 10'd240;
        display_en = 1'b1;
    end

    // Main test sequence
    initial begin
        $display("===================================");
        $display("    PONG GAME TESTBENCH START");
        $display("===================================");
        
        // Initialize
        clk_pix = 1'b0;
        reset   = 1'b1;
        btnU = 0; btnD = 0; btnL = 0; btnR = 0; btnC = 0;
        
        // Release reset after 200ns
        #200;
        reset = 1'b0;
        $display("[%0t] Reset released - Game should be in START state", $time);
        
        // Wait in start screen
        repeat (2000) @(posedge clk_pix);
        $display("[%0t] Waiting in START screen...", $time);
        
        // Press center button to start game
        $display("[%0t] Pressing CENTER button to start game", $time);
        btnC = 1'b1;
        repeat (50) @(posedge clk_pix);
        btnC = 1'b0;
        
        // Let the game play for a bit
        repeat (3000) @(posedge clk_pix);
        $display("[%0t] Game playing... Ball should be moving", $time);
        $display("[%0t] Left Score: %0d, Right Score: %0d", $time, score_d7, score_d0);
        
        // Test player controls - Move paddle UP
        $display("[%0t] Testing UP button - Moving left paddle UP", $time);
        repeat (5) begin
            btnU = 1'b1;
            repeat (500) @(posedge clk_pix);
            btnU = 1'b0;
            repeat (500) @(posedge clk_pix);
        end
        
        // Test player controls - Move paddle DOWN
        $display("[%0t] Testing DOWN button - Moving left paddle DOWN", $time);
        repeat (5) begin
            btnD = 1'b1;
            repeat (500) @(posedge clk_pix);
            btnD = 1'b0;
            repeat (500) @(posedge clk_pix);
        end
        
        // Let game continue to see scoring
        $display("[%0t] Continuing gameplay to test scoring...", $time);
        repeat (10000) @(posedge clk_pix);
        
        $display("[%0t] Current Scores - Left: %0d, Right: %0d", $time, score_d7, score_d0);
        
        // Continue until someone scores a few points
        repeat (20000) @(posedge clk_pix);
        
        $display("===================================");
        $display("    PONG GAME TESTBENCH END");
        $display("===================================");
        $display("FINAL SCORES:");
        $display("  Left Player (Human):  %0d", score_d7);
        $display("  Right Player (AI):    %0d", score_d0);
        $display("  Full BCD: %0d%0d%0d%0d_%0d%0d%0d%0d",
                 score_d7, score_d6, score_d5, score_d4,
                 score_d3, score_d2, score_d1, score_d0);
        
        // Check if game reached GAMEOVER state (score of 9)
        if (score_d7 == 4'd9 || score_d0 == 4'd9) begin
            $display("*** GAME OVER STATE REACHED ***");
            if (score_d7 == 4'd9)
                $display("*** LEFT PLAYER (HUMAN) WINS! ***");
            else
                $display("*** RIGHT PLAYER (AI) WINS! ***");
        end
        
        $stop;
    end

    // Optional: Monitor for debugging
    initial begin
        $monitor("[%0t] State=%0d, Ball_X=%0d, Ball_Y=%0d, L_Paddle=%0d, R_Paddle=%0d, Scores(L:R)=%0d:%0d", 
                 $time, dut.game_state, dut.ball_x, dut.ball_y, 
                 dut.left_paddle_y, dut.right_paddle_y,
                 score_d7, score_d0);
    end

endmodule