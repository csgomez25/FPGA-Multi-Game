`timescale 1ns / 1ps

module crossy_game(
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

    //================================================================
    //  GRID / GAME CONSTANTS
    //================================================================
    localparam integer CELL_SIZE   = 32;
    localparam integer GRID_COLS   = 20;
    localparam integer GRID_ROWS   = 15;

    localparam integer START_ROW   = GRID_ROWS - 1;
    localparam integer START_COL   = GRID_COLS / 2;

    localparam integer GOAL_ROW    = 0;

    localparam [1:0] RT_GRASS   = 2'b00;
    localparam [1:0] RT_ROAD    = 2'b01;
    localparam [1:0] RT_RIVER   = 2'b10;
    localparam [1:0] RT_SPECIAL = 2'b11;

    localparam [1:0]
        GS_START   = 2'd0,
        GS_PLAY    = 2'd1,
        GS_GO_ANIM = 2'd2,
        GS_GAMEOVER= 2'd3;

    //================================================================
    //  INTERNAL GAME STATE
    //================================================================
    reg [1:0] game_state;

    reg [4:0] frog_row;
    reg [4:0] frog_col;

    reg [4:0] best_row;

    reg [3:0] level;

    reg prevU, prevD, prevL, prevR, prevC;
    wire edgeU = btnU & ~prevU;
    wire edgeD = btnD & ~prevD;
    wire edgeL = btnL & ~prevL;
    wire edgeR = btnR & ~prevR;
    wire edgeC = btnC & ~prevC;

    reg [1:0]  row_kind    [0:GRID_ROWS-1];
    reg [19:0] lane_pattern[0:GRID_ROWS-1];
    reg        lane_dir    [0:GRID_ROWS-1];

    reg [3:0] tick_div;
    wire      move_tick = frame_tick && (tick_div == 4'd0);

    reg [5:0] go_anim_cnt;

    reg  [15:0] lfsr;
    wire        lfsr_fb = lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];

    integer i;

    //================================================================
    //  BCD SCORE INCREMENT TASK
    //================================================================
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

    //================================================================
    //  SHIFT HELPERS
    //================================================================
    function [19:0] shift_left(input [19:0] p);
    begin
        shift_left = {p[18:0], p[19]};
    end
    endfunction

    function [19:0] shift_right(input [19:0] p);
    begin
        shift_right = {p[0], p[19:1]};
    end
    endfunction

    //================================================================
    //  LEVEL / ROW LAYOUT INITIALIZATION
    //================================================================
    task automatic init_level;
        integer r;
        reg [1:0]  kind_sel;
        reg [19:0] base_road;
        reg [19:0] base_river;
        integer    road_count;
        integer    river_count;
    begin
        case (level)
            4'd0, 4'd1: begin
                base_road  = 20'b00000111000000000000;
                base_river = 20'b00111100000000000000;
            end
            4'd2, 4'd3: begin
                base_road  = 20'b00011100001110000000;
                base_river = 20'b00111000011100000000;
            end
            default: begin
                base_road  = 20'b00111100011110000111;
                base_river = 20'b00111100011100001110;
            end
        endcase

        road_count  = 0;
        river_count = 0;

        for (r = 0; r < GRID_ROWS; r = r + 1) begin
            lane_pattern[r] <= 20'b0;
            lane_dir[r]     <= 1'b0;
            row_kind[r]     <= RT_GRASS;

            if (r == START_ROW || r == GOAL_ROW) begin
                row_kind[r] <= RT_SPECIAL;
            end else begin
                kind_sel = { lfsr[(r + level)      % 16],
                            lfsr[(r + 5 + level)  % 16] };

                case (kind_sel)
                    2'b01: begin
                        row_kind[r]     <= RT_ROAD;
                        lane_dir[r]     <= lfsr[(r + 2) % 16];
                        lane_pattern[r] <= base_road;
                        road_count      = road_count + 1;
                    end

                    2'b10: begin
                        row_kind[r]     <= RT_RIVER;
                        lane_dir[r]     <= lfsr[(r + 3) % 16];
                        lane_pattern[r] <= base_river;
                        river_count     = river_count + 1;
                    end

                    default: begin
                        row_kind[r] <= RT_GRASS;
                    end
                endcase
            end
        end

        if (road_count == 0) begin
            r = START_ROW + 1;
            if (r >= GRID_ROWS) r = START_ROW - 1;
            row_kind[r]     <= RT_ROAD;
            lane_dir[r]     <= lfsr[(r + 2) % 16];
            lane_pattern[r] <= base_road;
        end

        if (river_count == 0) begin
            r = START_ROW + 2;
            if (r >= GRID_ROWS) r = START_ROW - 2;
            row_kind[r]     <= RT_RIVER;
            lane_dir[r]     <= lfsr[(r + 3) % 16];
            lane_pattern[r] <= base_river;
        end
    end
    endtask

    //================================================================
    //  HELPER WIRES FOR COLLISIONS
    //================================================================
    wire [4:0] start_row_5 = START_ROW[4:0];
    wire [4:0] start_col_5 = START_COL[4:0];
    wire [4:0] goal_row_5  = GOAL_ROW[4:0];

    wire frog_on_river = (row_kind[frog_row] == RT_RIVER);
    wire frog_on_pad   = frog_on_river && lane_pattern[frog_row][frog_col];

    //================================================================
    //  MAIN SEQUENTIAL GAME LOGIC
    //================================================================
    always @(posedge clk_pix) begin
        if (reset) begin
            game_state <= GS_START;

            frog_row   <= start_row_5;
            frog_col   <= start_col_5;
            best_row   <= start_row_5;
            level      <= 4'd1;

            score_d0 <= 4'd0;
            score_d1 <= 4'd0;
            score_d2 <= 4'd0;
            score_d3 <= 4'd0;
            score_d4 <= 4'd0;
            score_d5 <= 4'd0;
            score_d6 <= 4'd0;
            score_d7 <= 4'd0;

            prevU <= 1'b0;
            prevD <= 1'b0;
            prevL <= 1'b0;
            prevR <= 1'b0;
            prevC <= 1'b0;

            tick_div    <= 4'd0;
            go_anim_cnt <= 6'd0;

            lfsr <= 16'hACE1;

            init_level();
        end else begin
            prevU <= btnU;
            prevD <= btnD;
            prevL <= btnL;
            prevR <= btnR;
            prevC <= btnC;

            if (frame_tick) begin
                lfsr     <= {lfsr[14:0], lfsr_fb};
                tick_div <= tick_div + 4'd1;

                if (game_state == GS_GO_ANIM)
                    go_anim_cnt <= go_anim_cnt + 6'd1;
                else
                    go_anim_cnt <= 6'd0;
            end

            case (game_state)
                GS_START: begin
                    frog_row <= start_row_5;
                    frog_col <= start_col_5;
                    best_row <= start_row_5;

                    if (edgeC) begin
                        game_state <= GS_PLAY;
                    end
                end

                GS_PLAY: begin
                    if (edgeU && frog_row > 5'd0) begin
                        frog_row <= frog_row - 5'd1;
                        if ((frog_row - 5'd1) < best_row) begin
                            best_row <= frog_row - 5'd1;
                            inc_score();
                        end
                    end

                    if (edgeD && frog_row < start_row_5) begin
                        frog_row <= frog_row + 5'd1;
                    end

                    if (edgeL && frog_col > 5'd0) begin
                        frog_col <= frog_col - 5'd1;
                    end

                    if (edgeR && frog_col < (GRID_COLS-1)) begin
                        frog_col <= frog_col + 5'd1;
                    end

                    if (move_tick) begin
                        if (row_kind[frog_row] == RT_RIVER &&
                            lane_pattern[frog_row][frog_col]) begin
                            if (lane_dir[frog_row] == 1'b0) begin
                                if (frog_col < GRID_COLS-1)
                                    frog_col <= frog_col - 5'd1;
                            end else begin
                                if (frog_col > 0)
                                    frog_col <= frog_col + 5'd1;
                            end
                        end

                        for (i = 0; i < GRID_ROWS; i = i + 1) begin
                            if (row_kind[i] == RT_ROAD || row_kind[i] == RT_RIVER) begin
                                if (lane_dir[i] == 1'b0)
                                    lane_pattern[i] <= shift_right(lane_pattern[i]);
                                else
                                    lane_pattern[i] <= shift_left(lane_pattern[i]);
                            end
                        end
                    end

                    if (row_kind[frog_row] == RT_ROAD &&
                        lane_pattern[frog_row][frog_col]) begin
                        game_state <= GS_GO_ANIM;
                    end
                    else begin
                        if (row_kind[frog_row] == RT_RIVER &&
                           !lane_pattern[frog_row][frog_col]) begin
                            game_state <= GS_GO_ANIM;
                        end else begin
                            if (frog_row == goal_row_5) begin
                                inc_score();

                                if (level < 4'd9)
                                    level <= level + 4'd1;

                                frog_row <= start_row_5;
                                frog_col <= start_col_5;
                                best_row <= start_row_5;
                                init_level();
                            end
                        end
                    end
                end

                GS_GO_ANIM: begin
                    if (go_anim_cnt == 6'd40) begin
                        game_state <= GS_GAMEOVER;
                    end
                end

                GS_GAMEOVER: begin
                    if (edgeC) begin
                        level    <= 4'd1;
                        frog_row <= start_row_5;
                        frog_col <= start_col_5;
                        best_row <= start_row_5;

                        score_d0 <= 4'd0;
                        score_d1 <= 4'd0;
                        score_d2 <= 4'd0;
                        score_d3 <= 4'd0;
                        score_d4 <= 4'd0;
                        score_d5 <= 4'd0;
                        score_d6 <= 4'd0;
                        score_d7 <= 4'd0;

                        init_level();
                        game_state <= GS_START;
                    end
                end

            endcase
        end
    end

    //================================================================
    //  RENDERING: BACKGROUND + CARS + LILYPADS + FROG
    //================================================================
    wire [4:0] cell_x = pixel_x / CELL_SIZE;
    wire [4:0] cell_y = pixel_y / CELL_SIZE;

    reg [3:0] r, g, b;

    always @* begin
        if (!display_en) begin
            r = 4'h0; g = 4'h0; b = 4'h0;
        end else begin
            case (row_kind[cell_y])
                RT_GRASS: begin
                    r = 4'h0; g = 4'h7; b = 4'h0;
                end
                RT_ROAD: begin
                    r = 4'h4; g = 4'h4; b = 4'h4;
                end
                RT_RIVER: begin
                    r = 4'h0; g = 4'h0; b = 4'h8;
                end
                default: begin
                    r = 4'h9; g = 4'h7; b = 4'h0;
                end
            endcase

            if (row_kind[cell_y] == RT_ROAD && lane_pattern[cell_y][cell_x]) begin
                if (cell_y[1:0] == 2'b00) begin
                    r = 4'hF; g = 4'h0; b = 4'h0;
                end else if (cell_y[1:0] == 2'b01) begin
                    r = 4'hF; g = 4'hF; b = 4'h0;
                end else begin
                    r = 4'h0; g = 4'h0; b = 4'hF;
                end
            end

            if (row_kind[cell_y] == RT_RIVER && lane_pattern[cell_y][cell_x]) begin
                r = 4'h8; g = 4'h4; b = 4'h2;
            end

            if (cell_y == frog_row && cell_x == frog_col) begin
                r = 4'h0; g = 4'hF; b = 4'h0;
            end

            if (game_state == GS_GO_ANIM && go_anim_cnt[3]) begin
                r = 4'hF; g = 4'h0; b = 4'h0;
            end
        end
    end

    //================================================================
    //  FONT FOR TEXT OVERLAY
    //================================================================
    function [7:0] font_row2(
        input [7:0] ch,
        input [2:0] row
    );
    begin
        font_row2 = 8'b00000000;
        if (row > 3'd6) begin
            font_row2 = 8'b00000000;
        end else begin
            case (ch)
                8'h20: font_row2 = 8'b00000000;

                "A": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b10001000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b11111000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10001000;
                        3'd6: font_row2 = 8'b10001000;
                     endcase
                "B": case(row)
                        3'd0: font_row2 = 8'b01111000;
                        3'd1: font_row2 = 8'b01000100;
                        3'd2: font_row2 = 8'b01111000;
                        3'd3: font_row2 = 8'b01000100;
                        3'd4: font_row2 = 8'b01111000;
                        default: font_row2 = 8'b00000000;
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
                "D": case(row)
                        3'd0: font_row2 = 8'b11100000;
                        3'd1: font_row2 = 8'b10010000;
                        3'd2: font_row2 = 8'b10001000;
                        3'd3: font_row2 = 8'b10001000;
                        3'd4: font_row2 = 8'b10001000;
                        3'd5: font_row2 = 8'b10010000;
                        3'd6: font_row2 = 8'b11100000;
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
                "H": case(row)
                        3'd0: font_row2 = 8'b01000100;
                        3'd1: font_row2 = 8'b01000100;
                        3'd2: font_row2 = 8'b01111100;
                        3'd3: font_row2 = 8'b01000100;
                        3'd4: font_row2 = 8'b01000100;
                        default: font_row2 = 8'b00000000;
                     endcase
                "I": case(row)
                        3'd0: font_row2 = 8'b01110000;
                        3'd1: font_row2 = 8'b00100000;
                        3'd2: font_row2 = 8'b00100000;
                        3'd3: font_row2 = 8'b00100000;
                        3'd4: font_row2 = 8'b00100000;
                        3'd5: font_row2 = 8'b00100000;
                        3'd6: font_row2 = 8'b01110000;
                     endcase
                "J": case(row)
                        3'd0: font_row2 = 8'b00011100;
                        3'd1: font_row2 = 8'b00001000;
                        3'd2: font_row2 = 8'b00001000;
                        3'd3: font_row2 = 8'b01001000;
                        3'd4: font_row2 = 8'b00110000;
                        default: font_row2 = 8'b00000000;
                     endcase
                "L": case(row)
                        3'd0: font_row2 = 8'b10000000;
                        3'd1: font_row2 = 8'b10000000;
                        3'd2: font_row2 = 8'b10000000;
                        3'd3: font_row2 = 8'b10000000;
                        3'd4: font_row2 = 8'b10000000;
                        3'd5: font_row2 = 8'b10000000;
                        3'd6: font_row2 = 8'b11111000;
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
                "U": case(row)
                        3'd0: font_row2 = 8'b01000100;
                        3'd1: font_row2 = 8'b01000100;
                        3'd2: font_row2 = 8'b01000100;
                        3'd3: font_row2 = 8'b01000100;
                        3'd4: font_row2 = 8'b00111000;
                        default: font_row2 = 8'b00000000;
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
                "X": case(row)
                        3'd0: font_row2 = 8'b01000100;
                        3'd1: font_row2 = 8'b00101000;
                        3'd2: font_row2 = 8'b00010000;
                        3'd3: font_row2 = 8'b00101000;
                        3'd4: font_row2 = 8'b01000100;
                        default: font_row2 = 8'b00000000;
                     endcase
                "Y": case(row)
                        3'd0: font_row2 = 8'b01000100;
                        3'd1: font_row2 = 8'b00101000;
                        3'd2: font_row2 = 8'b00010000;
                        3'd3: font_row2 = 8'b00010000;
                        3'd4: font_row2 = 8'b00010000;
                        default: font_row2 = 8'b00000000;
                     endcase

                default: font_row2 = 8'b00000000;
            endcase
        end
    end
    endfunction

    //================================================================
    //  TEXT OVERLAY - WITH 2X SCALING ON GAME OVER SCREEN
    //================================================================
    reg [3:0] r_out, g_out, b_out;
    reg       text_px;
    reg [7:0] ch;
    reg [6:0] char_x;
    reg [5:0] char_y;
    reg [2:0] row_in_char;
    reg [2:0] col_in_char;
    reg [7:0] bits;

    // Scaled character coordinates for game over (2x size)
    reg [6:0] char_x_scaled;
    reg [5:0] char_y_scaled;
    reg [2:0] row_in_char_scaled;
    reg [2:0] col_in_char_scaled;

    always @* begin
        r_out = r;
        g_out = g;
        b_out = b;
        text_px = 1'b0;

        if (display_en) begin
            if (game_state == GS_GAMEOVER) begin
               r_out = 4'h0;
               g_out = 4'h0;
               b_out = 4'h0;
            end 
            
            ch   = 8'd0;
            bits = 8'd0;

            case (game_state)
                GS_START: begin
  
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
                            if (col_in_char_scaled < 3'd5 && bits[7 - col_in_char_scaled])
                                text_px = 1'b1;
                        end
                    end
                    //----------------------------------------------
                    // "PRESS CENTER" - 2X size
                    //----------------------------------------------
                    if (char_y_scaled == 6'd15) begin
                        if (char_x_scaled >= 7'd20 && char_x_scaled < 7'd32) begin
                            case (char_x_scaled - 7'd20)
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
                            if (col_in_char_scaled < 3'd5 && bits[7 - col_in_char_scaled])
                                text_px = 1'b1;
                        end
                    end
                end

                default: begin
                end
            endcase
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