`timescale 1ns / 1ps

module snake_game(
    input  wire       clk_pix,
    input  wire       reset,
    input  wire       frame_tick,
    input  wire       btnU,
    input  wire       btnD,
    input  wire       btnL,
    input  wire       btnR,
    input  wire       btnC,
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       display_en,

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

    //------------------------------------------------------------
    // Parameters
    //------------------------------------------------------------
    localparam integer CELL_SIZE = 32;
    localparam integer GRID_COLS = 20;
    localparam integer GRID_ROWS = 15;
    localparam integer MAX_LEN   = 100;

    // Game states
    localparam [1:0]
        GS_START   = 2'd0,
        GS_PLAY    = 2'd1,
        GS_GO_ANIM = 2'd2,
        GS_GAMEOVER= 2'd3;

    //------------------------------------------------------------
    // Internal signals
    //------------------------------------------------------------
    reg [1:0] game_state;

    // Snake body as arrays of row/col
    reg [4:0] snake_row [0:MAX_LEN-1];
    reg [4:0] snake_col [0:MAX_LEN-1];
    reg [6:0] snake_len;   // number of segments actually used (>=1)

    // Directions: 2'b00=UP, 01=DOWN, 10=LEFT, 11=RIGHT
    reg [1:0] dir;

    reg [4:0] apple_row;
    reg [4:0] apple_col;

    // LFSR for randomness
    reg [15:0] lfsr;
    wire       lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    // Game tick (faster) - controls how often the snake moves
    // (was very slow before: one move every 32 frames)
    // Now: 3-bit divider -> one move every 8 frames (~7.5 moves/sec at 60 Hz)
    reg [2:0] tick_div;
    wire      game_tick = frame_tick && (tick_div == 3'd0);

    // Button edge detect
    reg prevU, prevD, prevL, prevR, prevC;
    wire edgeU = btnU & ~prevU;
    wire edgeD = btnD & ~prevD;
    wire edgeL = btnL & ~prevL;
    wire edgeR = btnR & ~prevR;
    wire edgeC = btnC & ~prevC;

    // Game over anim counter
    reg [5:0] go_anim_cnt;

    //------------------------------------------------------------
    // BCD increment (score = apples eaten)
    //------------------------------------------------------------
    task automatic inc_score;
    begin
        if (!(score_d0 == 4'd9 && score_d1 == 4'd9 &&
              score_d2 == 4'd9 && score_d3 == 4'd9 &&
              score_d4 == 4'd9 && score_d5 == 4'd9 &&
              score_d6 == 4'd9 && score_d7 == 4'd9)) begin
            if (score_d0 == 4'd9) begin
                score_d0 <= 4'd0;
                if (score_d1 == 4'd9) begin
                    score_d1 <= 4'd0;
                    if (score_d2 == 4'd9) begin
                        score_d2 <= 4'd0;
                        if (score_d3 == 4'd9) begin
                            score_d3 <= 4'd0;
                            if (score_d4 == 4'd9) begin
                                score_d4 <= 4'd0;
                                if (score_d5 == 4'd9) begin
                                    score_d5 <= 4'd0;
                                    if (score_d6 == 4'd9) begin
                                        score_d6 <= 4'd0;
                                        score_d7 <= score_d7 + 4'd1;
                                    end else score_d6 <= score_d6 + 4'd1;
                                end else score_d5 <= score_d5 + 4'd1;
                            end else score_d4 <= score_d4 + 4'd1;
                        end else score_d3 <= score_d3 + 4'd1;
                    end else score_d2 <= score_d2 + 4'd1;
                end else score_d1 <= score_d1 + 4'd1;
            end else score_d0 <= score_d0 + 4'd1;
        end
    end
    endtask

    //------------------------------------------------------------
    // Helper: new apple position from LFSR
    //------------------------------------------------------------
    task automatic place_apple;
    begin
        // Derive new apple from LFSR
        apple_row <= (lfsr[4:0] % GRID_ROWS[4:0]);
        apple_col <= (lfsr[9:5] % GRID_COLS[4:0]);
    end
    endtask

    //------------------------------------------------------------
    // Main state machine
    //------------------------------------------------------------
    integer i;
    reg [4:0] new_head_row;
    reg [4:0] new_head_col;
    reg       self_hit, wall_hit;

    always @(posedge clk_pix) begin
        if (reset) begin
            game_state <= GS_START;

            // Initialize a short snake in the center, moving right
            snake_len <= 7'd3;
            snake_row[0] <= 5'd7;  snake_col[0] <= 5'd10;
            snake_row[1] <= 5'd7;  snake_col[1] <= 5'd9;
            snake_row[2] <= 5'd7;  snake_col[2] <= 5'd8;

            for (i = 3; i < MAX_LEN; i = i + 1) begin
                snake_row[i] <= 5'd7;
                snake_col[i] <= 5'd8;
            end

            dir <= 2'b11; // right

            apple_row <= 5'd5;
            apple_col <= 5'd5;

            lfsr <= 16'hBEEF;

            tick_div <= 3'd0;
            go_anim_cnt <= 6'd0;

            prevU <= 0; prevD <= 0; prevL <= 0; prevR <= 0; prevC <= 0;

            score_d0 <= 0; score_d1 <= 0; score_d2 <= 0; score_d3 <= 0;
            score_d4 <= 0; score_d5 <= 0; score_d6 <= 0; score_d7 <= 0;
        end else begin
            // Button history
            prevU <= btnU; prevD <= btnD; prevL <= btnL; prevR <= btnR; prevC <= btnC;

            // LFSR & tick divider
            if (frame_tick) begin
                lfsr     <= {lfsr[14:0], lfsr_fb};
                tick_div <= tick_div + 3'd1;

                if (game_state == GS_GO_ANIM)
                    go_anim_cnt <= go_anim_cnt + 6'd1;
                else
                    go_anim_cnt <= 6'd0;
            end

            case (game_state)
                //--------------------------------------------------------
                GS_START: begin
                    // re-center snake on each entry
                    snake_len <= 7'd3;
                    snake_row[0] <= 5'd7; snake_col[0] <= 5'd10;
                    snake_row[1] <= 5'd7; snake_col[1] <= 5'd9;
                    snake_row[2] <= 5'd7; snake_col[2] <= 5'd8;
                    dir <= 2'b11;

                    // reset score for new run
                    score_d0 <= 0; score_d1 <= 0; score_d2 <= 0; score_d3 <= 0;
                    score_d4 <= 0; score_d5 <= 0; score_d6 <= 0; score_d7 <= 0;

                    if (edgeC)
                        game_state <= GS_PLAY;
                end

                //--------------------------------------------------------
                GS_PLAY: begin
                    // Direction control (no 180-degree reverse)
                    if (edgeU && dir != 2'b01) dir <= 2'b00;
                    else if (edgeD && dir != 2'b00) dir <= 2'b01;
                    else if (edgeL && dir != 2'b11) dir <= 2'b10;
                    else if (edgeR && dir != 2'b10) dir <= 2'b11;

                    if (game_tick) begin
                        // Compute new head position
                        new_head_row = snake_row[0];
                        new_head_col = snake_col[0];

                        case (dir)
                            2'b00: new_head_row = snake_row[0] - 1; // up
                            2'b01: new_head_row = snake_row[0] + 1; // down
                            2'b10: new_head_col = snake_col[0] - 1; // left
                            2'b11: new_head_col = snake_col[0] + 1; // right
                        endcase

                        // Check wall hit
                        wall_hit = (new_head_row >= GRID_ROWS[4:0]) ||
                                   (new_head_col >= GRID_COLS[4:0]);

                        // Check self hit
                        self_hit = 1'b0;
                        for (i = 0; i < MAX_LEN; i = i + 1) begin
                            if (i < snake_len) begin
                                if (snake_row[i] == new_head_row &&
                                    snake_col[i] == new_head_col)
                                    self_hit = 1'b1;
                            end
                        end

                        if (wall_hit || self_hit) begin
                            game_state <= GS_GO_ANIM;
                        end else begin
                            // Eat apple?
                            if (new_head_row == apple_row && new_head_col == apple_col) begin
                                // grow: shift body, add new head, keep tail
                                if (snake_len < MAX_LEN)
                                    snake_len <= snake_len + 1;

                                for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                                    if (i < snake_len)
                                        snake_row[i] <= snake_row[i-1];
                                end
                                for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                                    if (i < snake_len)
                                        snake_col[i] <= snake_col[i-1];
                                end

                                snake_row[0] <= new_head_row;
                                snake_col[0] <= new_head_col;

                                // Score++
                                inc_score();

                                // new apple
                                place_apple();
                            end else begin
                                // normal move: shift, drop tail
                                for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                                    if (i < snake_len)
                                        snake_row[i] <= snake_row[i-1];
                                end
                                for (i = MAX_LEN-1; i > 0; i = i - 1) begin
                                    if (i < snake_len)
                                        snake_col[i] <= snake_col[i-1];
                                end

                                snake_row[0] <= new_head_row;
                                snake_col[0] <= new_head_col;
                            end
                        end
                    end
                end

                //--------------------------------------------------------
                GS_GO_ANIM: begin
                    // after some animation frames, go to GAMEOVER
                    if (go_anim_cnt == 6'd40) begin
                        game_state <= GS_GAMEOVER;
                    end
                end

                //--------------------------------------------------------
                GS_GAMEOVER: begin
                    if (edgeC) begin
                        // back to START
                        game_state <= GS_START;
                    end
                end

            endcase
        end
    end

    //------------------------------------------------------------
    // Rendering
    //------------------------------------------------------------
    wire [4:0] cell_x = pixel_x / CELL_SIZE;
    wire [4:0] cell_y = pixel_y / CELL_SIZE;

    reg snake_here;
    reg apple_here;

    integer j;

    always @* begin
        snake_here = 1'b0;
        apple_here = 1'b0;

        for (j = 0; j < MAX_LEN; j = j + 1) begin
            if (j < snake_len) begin
                if (snake_row[j] == cell_y && snake_col[j] == cell_x)
                    snake_here = 1'b1;
            end
        end

        if (apple_row == cell_y && apple_col == cell_x)
            apple_here = 1'b1;
    end

    //------------------------------------------------------------
    // Simple background & snake/apple colors
    //------------------------------------------------------------
    reg [3:0] r, g, b;

    always @* begin
        if (!display_en) begin
            r = 4'h0; g = 4'h0; b = 4'h0;
        end else begin
            // Checkerboard background
            if ((cell_x + cell_y) & 1) begin
                r = 4'h0; g = 4'h2; b = 4'h0;
            end else begin
                r = 4'h0; g = 4'h4; b = 4'h0;
            end

            // Apple
            if (apple_here) begin
                r = 4'hF; g = 4'h0; b = 4'h0;
            end

            // Snake body
            if (snake_here) begin
                r = 4'h0; g = 4'hF; b = 4'h0;
            end

            // Game over animation: flash whole screen red in GO_ANIM
            if (game_state == GS_GO_ANIM) begin
                if (go_anim_cnt[3]) begin
                    r = 4'hF; g = 4'h0; b = 4'h0;
                end
            end
        end
    end

    //------------------------------------------------------------
    // Overlay text for START and GAMEOVER screens
    //------------------------------------------------------------
    // We have a separate tiny ROM here for "SNAKE" etc.

    function [7:0] font_row2(
        input [7:0] ch,
        input [3:0] row
    );
    begin
        // crude 5x8 font, same style as in arcade_top
        case (ch)
            "S": case (row)
                    0: font_row2 = 8'b01111100;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01111000;
                    3: font_row2 = 8'b00000100;
                    4: font_row2 = 8'b01111100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "N": case (row)
                    0: font_row2 = 8'b01000100;
                    1: font_row2 = 8'b01100100;
                    2: font_row2 = 8'b01010100;
                    3: font_row2 = 8'b01001100;
                    4: font_row2 = 8'b01000100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "A": case (row)
                    0: font_row2 = 8'b00111000;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01111100;
                    3: font_row2 = 8'b01000100;
                    4: font_row2 = 8'b01000100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "K": case (row)
                    0: font_row2 = 8'b01000100;
                    1: font_row2 = 8'b01001000;
                    2: font_row2 = 8'b01110000;
                    3: font_row2 = 8'b01001000;
                    4: font_row2 = 8'b01000100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "E": case (row)
                    0: font_row2 = 8'b01111100;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01111000;
                    3: font_row2 = 8'b01000000;
                    4: font_row2 = 8'b01111100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "G": case (row)
                    0: font_row2 = 8'b00111100;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01001100;
                    3: font_row2 = 8'b01000100;
                    4: font_row2 = 8'b00111000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "A": case (row)
                    0: font_row2 = 8'b00111000;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01111100;
                    3: font_row2 = 8'b01000100;
                    4: font_row2 = 8'b01000100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "M": case (row)
                    0: font_row2 = 8'b01000100;
                    1: font_row2 = 8'b01101100;
                    2: font_row2 = 8'b01010100;
                    3: font_row2 = 8'b01000100;
                    4: font_row2 = 8'b01000100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "O": case (row)
                    0: font_row2 = 8'b00111000;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01000100;
                    3: font_row2 = 8'b01000100;
                    4: font_row2 = 8'b00111000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "V": case (row)
                    0: font_row2 = 8'b01000100;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01000100;
                    3: font_row2 = 8'b00101000;
                    4: font_row2 = 8'b00010000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "R": case (row)
                    0: font_row2 = 8'b01111000;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01111000;
                    3: font_row2 = 8'b01010000;
                    4: font_row2 = 8'b01001000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "P": case (row)
                    0: font_row2 = 8'b01111000;
                    1: font_row2 = 8'b01000100;
                    2: font_row2 = 8'b01111000;
                    3: font_row2 = 8'b01000000;
                    4: font_row2 = 8'b01000000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "L": case (row)
                    0: font_row2 = 8'b01000000;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01000000;
                    3: font_row2 = 8'b01000000;
                    4: font_row2 = 8'b01111100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "Y": case (row)
                    0: font_row2 = 8'b01000100;
                    1: font_row2 = 8'b00101000;
                    2: font_row2 = 8'b00010000;
                    3: font_row2 = 8'b00010000;
                    4: font_row2 = 8'b00010000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "C": case (row)
                    0: font_row2 = 8'b00111000;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01000000;
                    3: font_row2 = 8'b01000000;
                    4: font_row2 = 8'b00111000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "T": case (row)
                    0: font_row2 = 8'b01111100;
                    1: font_row2 = 8'b00100000;
                    2: font_row2 = 8'b00100000;
                    3: font_row2 = 8'b00100000;
                    4: font_row2 = 8'b00100000;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            "E": case (row)
                    0: font_row2 = 8'b01111100;
                    1: font_row2 = 8'b01000000;
                    2: font_row2 = 8'b01111000;
                    3: font_row2 = 8'b01000000;
                    4: font_row2 = 8'b01111100;
                    5: font_row2 = 8'b00000000;
                    6: font_row2 = 8'b00000000;
                    7: font_row2 = 8'b00000000;
                    default: font_row2 = 8'b00000000;
                endcase
            default: font_row2 = 8'b00000000;
        endcase
    end
    endfunction

    //================================================================
    // TEXT OVERLAY - reuse Crossy 2X GAME OVER (no START text)
    //================================================================
    reg [3:0] r_out, g_out, b_out;
    reg       text_px;
    reg [7:0] ch;
    reg [7:0] bits;

    // Scaled character coordinates for game over (2x size)
    reg [6:0] char_x_scaled;
    reg [5:0] char_y_scaled;
    reg [2:0] row_in_char_scaled;
    reg [2:0] col_in_char_scaled;

    always @* begin
        // Base colors: Snake game background/sprites
        r_out   = r;
        g_out   = g;
        b_out   = b;
        text_px = 1'b0;

        if (display_en) begin
            // Black out background when in GAMEOVER
            if (game_state == GS_GAMEOVER) begin
                r_out = 4'h0;
                g_out = 4'h0;
                b_out = 4'h0;
            end

            ch   = 8'd0;
            bits = 8'd0;

            case (game_state)
                GS_START: begin
                    // No intro text for Snake; just show the grid & snake head.
                end

                GS_GAMEOVER: begin
                    // 2X SCALED text grid for GAME OVER screen
                    char_x_scaled      = pixel_x / 12;  // 2x width
                    char_y_scaled      = pixel_y / 16;  // 2x height
                    row_in_char_scaled = (pixel_y % 16) / 2;
                    col_in_char_scaled = (pixel_x % 12) / 2;

                    //----------------------------------------------
                    // "GAME OVER" - 2X size, centered
                    //----------------------------------------------
                    if (char_y_scaled == 6'd10) begin
                        if (char_x_scaled >= 7'd21 && char_x_scaled < 7'd30) begin
                            case (char_x_scaled - 7'd21)
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

                    //----------------------------------------------
                    // "PRESS CENTER" - 2X size
                    //----------------------------------------------
                    if (char_y_scaled == 6'd15) begin
                        if (char_x_scaled >= 7'd19 && char_x_scaled < 7'd31) begin
                            case (char_x_scaled - 7'd19)
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

                default: begin
                    // PLAY / death animation already drawn in r,g,b
                end
            endcase
        end

        // If text pixel active, draw white on top
        if (text_px) begin
            r_out = 4'hF;
            g_out = 4'hF;
            b_out = 4'hF;
        end
    end

    // Final outputs for Snake VGA
    always @* begin
        vga_r = r_out;
        vga_g = g_out;
        vga_b = b_out;
    end


endmodule
