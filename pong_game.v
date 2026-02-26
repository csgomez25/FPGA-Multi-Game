`timescale 1ns / 1ps

// Simple Pong-style game for 640x480 VGA
module pong_game(
    input  wire       clk_pix,      // ~25 MHz pixel clock
    input  wire       reset,        // active-high reset
    input  wire       frame_tick,   // game update tick (e.g. 60 Hz)
    input  wire       btnU,
    input  wire       btnD,
    input  wire       btnL,         // unused
    input  wire       btnR,         // unused
    input  wire       btnC,         // start/restart
    input  wire [9:0] pixel_x,      // current pixel x (0..639)
    input  wire [9:0] pixel_y,      // current pixel y (0..479)
    input  wire       display_en,   // high in visible area

    output reg  [3:0] vga_r,
    output reg  [3:0] vga_g,
    output reg  [3:0] vga_b,

    output reg  [3:0] score_d0,
    output reg  [3:0] score_d1,
    output reg  [3:0] score_d2,
    output reg  [3:0] score_d3,
    output reg  [3:0] score_d4,
    output reg  [3:0] score_d5,
    output reg  [3:0] score_d6,
    output reg  [3:0] score_d7
);

    // ----------------------------------------------------------------
    // Game parameters
    // ----------------------------------------------------------------
    localparam H_VISIBLE      = 640;
    localparam V_VISIBLE      = 480;

    localparam PADDLE_W       = 8;
    localparam PADDLE_H       = 64;
    localparam PADDLE_X_LEFT  = 32;
    localparam PADDLE_X_RIGHT = H_VISIBLE - 32 - PADDLE_W;

    localparam BALL_SIZE      = 8;
    localparam BALL_SPEED_X   = 2;     // Start slower
    localparam BALL_SPEED_Y   = 2;
    localparam PADDLE_SPEED   = 4;
    localparam AI_SPEED       = 2;     // AI much slower now (50% of player speed)
    localparam MAX_SPEED      = 5;     // Maximum ball speed

    // Game states - REMOVED START STATE, GO DIRECTLY TO PLAY
    localparam [1:0] GS_PLAY     = 2'd0;
    localparam [1:0] GS_GAMEOVER = 2'd1;

    reg [1:0] game_state;

    // Paddle and ball positions
    reg [9:0] left_paddle_y;
    reg [9:0] right_paddle_y;

    reg [9:0] ball_x;
    reg [9:0] ball_y;
    reg       ball_dir_right;  // 1 = right, 0 = left
    reg       ball_dir_down;   // 1 = down,  0 = up
    
    // Dynamic ball speed (increases over time)
    reg [2:0] current_speed_x;
    reg [2:0] current_speed_y;
    reg [7:0] rally_count;     // Count paddle hits to increase speed

    // Scores (0..9)
    reg [3:0] left_score;
    reg [3:0] right_score;

    // Button edge detection
    reg prevC;
    wire edgeC = btnC & ~prevC;

    // ----------------------------------------------------------------
    // Main game state update
    // ----------------------------------------------------------------
    always @(posedge clk_pix) begin
        if (reset) begin
            game_state     <= GS_PLAY;  // Changed from GS_START to GS_PLAY
            left_score     <= 4'd0;
            right_score    <= 4'd0;
            prevC          <= 1'b0;
            
            // Initialize positions
            left_paddle_y  <= 10'd208;  // (480-64)/2
            right_paddle_y <= 10'd208;
            ball_x         <= 10'd316;  // (640-8)/2
            ball_y         <= 10'd236;  // (480-8)/2
            ball_dir_right <= 1'b1;
            ball_dir_down  <= 1'b0;
            
            // Initialize speed
            current_speed_x <= BALL_SPEED_X;
            current_speed_y <= BALL_SPEED_Y;
            rally_count     <= 8'd0;
        end else begin
            // sync button for edge detection
            prevC <= btnC;

            case (game_state)
                // ============================================
                GS_PLAY: begin
                    if (frame_tick) begin
                        // -----------------------------
                        // Human paddle (left) movement
                        // -----------------------------
                        if (btnU) begin
                            if (left_paddle_y >= PADDLE_SPEED)
                                left_paddle_y <= left_paddle_y - PADDLE_SPEED;
                            else
                                left_paddle_y <= 10'd0;
                        end
                        if (btnD) begin
                            if (left_paddle_y <= V_VISIBLE - PADDLE_H - PADDLE_SPEED)
                                left_paddle_y <= left_paddle_y + PADDLE_SPEED;
                            else
                                left_paddle_y <= V_VISIBLE - PADDLE_H;
                        end

                        // -----------------------------
                        // Simple AI paddle (right) - MUCH LESS PRECISE
                        // -----------------------------
                        // Large deadband (16 pixels) makes AI miss more shots
                        if (ball_y + BALL_SIZE/2 > right_paddle_y + PADDLE_H/2 + 16) begin
                            if (right_paddle_y <= V_VISIBLE - PADDLE_H - AI_SPEED)
                                right_paddle_y <= right_paddle_y + AI_SPEED;
                            else
                                right_paddle_y <= V_VISIBLE - PADDLE_H;
                        end else if (ball_y + BALL_SIZE/2 < right_paddle_y + PADDLE_H/2 - 16) begin
                            if (right_paddle_y >= AI_SPEED)
                                right_paddle_y <= right_paddle_y - AI_SPEED;
                            else
                                right_paddle_y <= 10'd0;
                        end

                        // -----------------------------
                        // Vertical movement + wall bounce (using dynamic speed)
                        // -----------------------------
                        if (ball_dir_down) begin
                            if (ball_y >= V_VISIBLE - BALL_SIZE - current_speed_y) begin
                                ball_y        <= V_VISIBLE - BALL_SIZE;
                                ball_dir_down <= 1'b0;
                            end else begin
                                ball_y <= ball_y + current_speed_y;
                            end
                        end else begin
                            if (ball_y <= current_speed_y) begin
                                ball_y        <= 10'd0;
                                ball_dir_down <= 1'b1;
                            end else begin
                                ball_y <= ball_y - current_speed_y;
                            end
                        end

                        // -----------------------------
                        // Horizontal movement + paddles + scoring (using dynamic speed)
                        // -----------------------------
                        if (ball_dir_right) begin
                            // Moving right: check right paddle collision
                            if ( ball_x + BALL_SIZE >= PADDLE_X_RIGHT &&
                                 ball_x <= PADDLE_X_RIGHT + PADDLE_W &&
                                 ball_y + BALL_SIZE >= right_paddle_y &&
                                 ball_y <= right_paddle_y + PADDLE_H ) begin
                                // bounce left
                                ball_dir_right <= 1'b0;
                                ball_x <= PADDLE_X_RIGHT - BALL_SIZE;
                                
                                // Increase speed after paddle hit (up to MAX_SPEED)
                                rally_count <= rally_count + 1;
                                if (rally_count >= 8'd3) begin  // Every 3 hits
                                    if (current_speed_x < MAX_SPEED)
                                        current_speed_x <= current_speed_x + 1;
                                    if (current_speed_y < MAX_SPEED)
                                        current_speed_y <= current_speed_y + 1;
                                    rally_count <= 8'd0;
                                end
                            end else if (ball_x >= H_VISIBLE - BALL_SIZE - current_speed_x) begin
                                // Missed right paddle → left scores
                                if (left_score == 4'd4) begin  // Changed from 4'd8 to 4'd4 (first to 5)
                                    left_score  <= 4'd5;       // Changed from 4'd9 to 4'd5
                                    game_state  <= GS_GAMEOVER;
                                end else begin
                                    left_score     <= left_score + 4'd1;
                                    ball_x         <= 10'd316;
                                    ball_y         <= 10'd236;
                                    ball_dir_right <= 1'b1;
                                    ball_dir_down  <= 1'b0;
                                    // Reset speed on score
                                    current_speed_x <= BALL_SPEED_X;
                                    current_speed_y <= BALL_SPEED_Y;
                                    rally_count     <= 8'd0;
                                end
                            end else begin
                                ball_x <= ball_x + current_speed_x;
                            end
                        end else begin
                            // Moving left: check left paddle collision
                            if ( ball_x <= PADDLE_X_LEFT + PADDLE_W &&
                                 ball_x + BALL_SIZE >= PADDLE_X_LEFT &&
                                 ball_y + BALL_SIZE >= left_paddle_y &&
                                 ball_y <= left_paddle_y + PADDLE_H ) begin
                                // bounce right
                                ball_dir_right <= 1'b1;
                                ball_x <= PADDLE_X_LEFT + PADDLE_W;
                                
                                // Increase speed after paddle hit (up to MAX_SPEED)
                                rally_count <= rally_count + 1;
                                if (rally_count >= 8'd3) begin  // Every 3 hits
                                    if (current_speed_x < MAX_SPEED)
                                        current_speed_x <= current_speed_x + 1;
                                    if (current_speed_y < MAX_SPEED)
                                        current_speed_y <= current_speed_y + 1;
                                    rally_count <= 8'd0;
                                end
                            end else if (ball_x <= current_speed_x) begin
                                // Missed left paddle → right scores
                                if (right_score == 4'd4) begin  // Changed from 4'd8 to 4'd4 (first to 5)
                                    right_score <= 4'd5;        // Changed from 4'd9 to 4'd5
                                    game_state  <= GS_GAMEOVER;
                                end else begin
                                    right_score    <= right_score + 4'd1;
                                    ball_x         <= 10'd316;
                                    ball_y         <= 10'd236;
                                    ball_dir_right <= 1'b1;
                                    ball_dir_down  <= 1'b0;
                                    // Reset speed on score
                                    current_speed_x <= BALL_SPEED_X;
                                    current_speed_y <= BALL_SPEED_Y;
                                    rally_count     <= 8'd0;
                                end
                            end else begin
                                ball_x <= ball_x - current_speed_x;
                            end
                        end
                    end
                end

                // ============================================
                GS_GAMEOVER: begin
                    // Wait for center button to restart
                    if (edgeC) begin
                        left_score     <= 4'd0;
                        right_score    <= 4'd0;
                        left_paddle_y  <= 10'd208;
                        right_paddle_y <= 10'd208;
                        ball_x         <= 10'd316;
                        ball_y         <= 10'd236;
                        ball_dir_right <= 1'b1;
                        ball_dir_down  <= 1'b0;
                        current_speed_x <= BALL_SPEED_X;
                        current_speed_y <= BALL_SPEED_Y;
                        rally_count     <= 8'd0;
                        game_state     <= GS_PLAY;  // Changed from GS_START to GS_PLAY
                    end
                end

                default: begin
                    game_state <= GS_PLAY;  // Changed from GS_START to GS_PLAY
                end
            endcase
        end
    end

    // ----------------------------------------------------------------
    // Scoreboard mapping (always reflects current scores)
    // ----------------------------------------------------------------
    always @* begin
        score_d0 = right_score;  // right player score on rightmost digit
        score_d1 = 4'd0;
        score_d2 = 4'd0;
        score_d3 = 4'd0;
        score_d4 = 4'd0;
        score_d5 = 4'd0;
        score_d6 = 4'd0;
        score_d7 = left_score;   // left player score on leftmost digit
    end

    // ----------------------------------------------------------------
    // Base graphics: paddles, ball, center line
    // ----------------------------------------------------------------
    reg [3:0] r, g, b;

    always @* begin
        // Default background: black
        r = 4'h0;
        g = 4'h0;
        b = 4'h0;

        if (display_en) begin
            // Center dashed line
            if (pixel_x == (H_VISIBLE>>1) && (pixel_y[4] == 1'b0)) begin
                r = 4'h4;
                g = 4'h4;
                b = 4'h4;
            end

            // Left paddle
            if (pixel_x >= PADDLE_X_LEFT &&
                pixel_x <  PADDLE_X_LEFT + PADDLE_W &&
                pixel_y >= left_paddle_y &&
                pixel_y <  left_paddle_y + PADDLE_H) begin
                r = 4'hF;
                g = 4'hF;
                b = 4'hF;
            end

            // Right paddle
            if (pixel_x >= PADDLE_X_RIGHT &&
                pixel_x <  PADDLE_X_RIGHT + PADDLE_W &&
                pixel_y >= right_paddle_y &&
                pixel_y <  right_paddle_y + PADDLE_H) begin
                r = 4'hF;
                g = 4'hF;
                b = 4'hF;
            end

            // Ball
            if (pixel_x >= ball_x &&
                pixel_x <  ball_x + BALL_SIZE &&
                pixel_y >= ball_y &&
                pixel_y <  ball_y + BALL_SIZE) begin
                r = 4'hF;
                g = 4'hF;
                b = 4'hF;
            end
        end
    end

    // ----------------------------------------------------------------
    // Text overlay: START screen and GAMEOVER screen
    // ----------------------------------------------------------------

    function [7:0] font_row2(
        input [7:0] ch,
        input [2:0] row  // Changed to [2:0] for 7 rows (0-6)
    );
    begin
        font_row2 = 8'b00000000;
        if (row > 3'd6) begin
            font_row2 = 8'b00000000;
        end else begin
            case (ch)
                8'h20: font_row2 = 8'b00000000; // space

                "A": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b11111000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b10001000;
                     endcase
                "C": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10000000;
                        3'd3: font_row2 = 8'b10000000;
                        3'd4: font_row2 = 8'b10000000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b01110000;
                     endcase
                "E": case(row)
                        3'd0: font_row2 = 8'b11111000;
                        3'd1: font_row2 = 8'b10000000;
                        3'd2: font_row2 = 8'b10000000;
                        3'd3: font_row2 = 8'b11110000;
                        3'd4: font_row2 = 8'b10000000;
                        3'd5: font_row2 = 8'b10000000;
                        3'd6: font_row2 = 8'b11111000;
                     endcase
                "G": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10000000;
                        3'd3: font_row2 = 8'b10111000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b01110000;
                     endcase
                "M": case(row)
                        3'd0: font_row2 = 8'b10001000;
                        3'd1: font_row2 = 8'b11011000;
                        3'd2: font_row2 = 8'b10101000;
                        3'd3: font_row2 = 8'b10101000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b10001000;
                     endcase
                "N": case(row)
                        3'd0: font_row2 = 8'b10001000;
                        3'd1: font_row2 = 8'b11001000;
                        3'd2: font_row2 = 8'b10101000;
                        3'd3: font_row2 = 8'b10011000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b10001000;
                     endcase
                "O": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b10001000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b01110000;
                     endcase
                "P": case(row)
                        3'd0: font_row2 = 8'b11110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b11110000;
                        3'd4: font_row2 = 8'b10000000;
                        3'd5: font_row2 = 8'b10000000;
                        3'd6: font_row2 = 8'b10000000;
                     endcase
                "R": case(row)
                        3'd0: font_row2 = 8'b11110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b11110000;
                        3'd4: font_row2 = 8'b10100000;
                        3'd5: font_row2 = 8'b10010000;
                        3'd6: font_row2 = 8'b10001000;
                     endcase
                "S": case(row)
                        3'd0: font_row2 = 8'b01111000;
                        3'd1: font_row2 = 8'b10000000;
                        3'd2: font_row2 = 8'b10000000;
                        3'd3: font_row2 = 8'b01110000;
                        3'd4: font_row2 = 8'b00001000;
                        3'd5: font_row2 = 8'b00001000;
                        3'd6: font_row2 = 8'b11110000;
                     endcase
                "T": case(row)
                        3'd0: font_row2 = 8'b11111000;
                        3'd1: font_row2 = 8'b00100000;
                        3'd2: font_row2 = 8'b00100000;
                        3'd3: font_row2 = 8'b00100000;
                        3'd4: font_row2 = 8'b00100000;
                        3'd5: font_row2 = 8'b00100000;
                        3'd6: font_row2 = 8'b00100000;
                     endcase
                "V": case(row)
                        3'd0: font_row2 = 8'b10001000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b01010000;
                        3'd4: font_row2 = 8'b01010000;
                        3'd5: font_row2 = 8'b00100000;
                        3'd6: font_row2 = 8'b00100000;
                     endcase
                "Y": case(row)
                        3'd0: font_row2 = 8'b10001000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b01010000;
                        3'd3: font_row2 = 8'b00100000;
                        3'd4: font_row2 = 8'b00100000;
                        3'd5: font_row2 = 8'b00100000;
                        3'd6: font_row2 = 8'b00100000;
                     endcase

                default: font_row2 = 8'b00000000;
            endcase
        end
    end
    endfunction

    reg [3:0] row_in_char;
    reg [2:0] col_in_char;
    reg [6:0] char_x;
    reg [5:0] char_y;
    reg [7:0] bits;
    reg [7:0] ch;
    reg       text_px;

    // Scaled character coordinates for game over (2x size)
    reg [6:0] char_x_scaled;
    reg [5:0] char_y_scaled;
    reg [2:0] row_in_char_scaled;
    reg [2:0] col_in_char_scaled;

    reg [3:0] r_out, g_out, b_out;

    always @* begin
        // start from base graphics
        r_out   = r;
        g_out   = g;
        b_out   = b;
        text_px = 1'b0;

        if (display_en) begin
            ch   = 8'd0;
            bits = 8'd0;

            if (game_state == GS_GAMEOVER) begin
                // black background for GAME OVER
                r_out = 4'h0;
                g_out = 4'h0;
                b_out = 4'h0;

                // 2X SCALED text grid for GAME OVER screen
                char_x_scaled      = pixel_x / 12;  // 2x width
                char_y_scaled      = pixel_y / 16;  // 2x height
                row_in_char_scaled = (pixel_y % 16) / 2;
                col_in_char_scaled = (pixel_x % 12) / 2;

                // "GAME OVER" - 2X size, centered
                if (char_y_scaled == 6'd14) begin
                    if (char_x_scaled >= 7'd24 && char_x_scaled < 7'd33) begin
                        case (char_x_scaled - 7'd24)
                            0: ch = "G";
                            1: ch = "A";
                            2: ch = "M";
                            3: ch = "E";
                            4: ch = " ";
                            5: ch = "O";
                            6: ch = "V";
                            7: ch = "E";
                            8: ch = "R";
                            default: ch = " ";
                        endcase
                        bits = font_row2(ch, row_in_char_scaled[2:0]);
                        if (col_in_char_scaled < 3'd5 && bits[6 - col_in_char_scaled])
                            text_px = 1'b1;
                    end
                end

                // "PRESS CENTER" - 2X size
                if (char_y_scaled == 6'd18) begin
                    if (char_x_scaled >= 7'd23 && char_x_scaled < 7'd35) begin
                        case (char_x_scaled - 7'd23)
                            0:  ch = "P";
                            1:  ch = "R";
                            2:  ch = "E";
                            3:  ch = "S";
                            4:  ch = "S";
                            5:  ch = " ";
                            6:  ch = "C";
                            7:  ch = "E";
                            8:  ch = "N";
                            9:  ch = "T";
                            10: ch = "E";
                            11: ch = "R";
                            default: ch = " ";
                        endcase
                        bits = font_row2(ch, row_in_char_scaled[2:0]);
                        if (col_in_char_scaled < 3'd5 && bits[6 - col_in_char_scaled])
                            text_px = 1'b1;
                    end
                end
            end
        end

        if (text_px) begin
            r_out = 4'hF;
            g_out = 4'hF;
            b_out = 4'hF;
        end
    end

    always @* begin
        vga_r = r_out;
        vga_g = g_out;
        vga_b = b_out;
    end

endmodule