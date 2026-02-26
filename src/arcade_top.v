`timescale 1ns / 1ps

// Top-level: Verilog Arcade with game select (Road Cross / Snake / Pong)
module arcade_top(
    input  wire        CLK100MHZ,

    // User buttons (active-high)
    input  wire        btnU,
    input  wire        btnD,
    input  wire        btnL,
    input  wire        btnR,
    input  wire        btnC,

    // Dedicated CPU reset button on Nexys A7 (ACTIVE-LOW on the board)
    input  wire        CPU_RESETN,

    // VGA outputs
    output wire        Hsync,
    output wire        Vsync,
    output wire [3:0]  vgaRed,
    output wire [3:0]  vgaGreen,
    output wire [3:0]  vgaBlue,

    // 7-seg outputs
    output wire [7:0]  an,     // 7-seg anodes (active low)
    output wire [6:0]  seg,    // segments a-g (active low)
    output wire        dp      // decimal point (active low)
);

    //----------------------------------------------------------------
    // Active-high internal reset from active-low CPU_RESETN button
    //----------------------------------------------------------------
    wire reset = ~CPU_RESETN;

    //----------------------------------------------------------------
    // Clock divide: 100 MHz -> 25 MHz pixel clock
    //----------------------------------------------------------------
    reg [1:0] clk_div = 2'd0;
    always @(posedge CLK100MHZ) begin
        clk_div <= clk_div + 2'd1;
    end
    wire clk_pix = clk_div[1]; // 25 MHz

    //----------------------------------------------------------------
    // VGA sync
    //----------------------------------------------------------------
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire       display_en;
    wire       frame_tick;

    vga_sync vga_inst (
        .clk_pix    (clk_pix),
        .reset      (reset),
        .hsync      (Hsync),
        .vsync      (Vsync),
        .display_en (display_en),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .frame_tick (frame_tick)
    );

    //----------------------------------------------------------------
    // Game select state machine
    //----------------------------------------------------------------
    localparam [1:0] ST_MENU       = 2'd0;
    localparam [1:0] ST_ROADCROSS  = 2'd1;
    localparam [1:0] ST_SNAKE      = 2'd2;
    localparam [1:0] ST_PONG       = 2'd3;

    reg [1:0] arcade_state = ST_MENU;

    // Which game is highlighted on menu:
    //   0 = Road Cross, 1 = Snake, 2 = Pong
    reg [1:0] menu_sel = 2'd0;

    // Button edge detection for menu logic (sync'd to clk_pix)
    reg prevL, prevR, prevU, prevD, prevC;
    wire edgeL = btnL & ~prevL;
    wire edgeR = btnR & ~prevR;
    wire edgeU = btnU & ~prevU;
    wire edgeD = btnD & ~prevD;
    wire edgeC = btnC & ~prevC;

    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            arcade_state <= ST_MENU;
            menu_sel     <= 2'd0;
            prevL        <= 1'b0;
            prevR        <= 1'b0;
            prevU        <= 1'b0;
            prevD        <= 1'b0;
            prevC        <= 1'b0;
        end else begin
            prevL <= btnL;
            prevR <= btnR;
            prevU <= btnU;
            prevD <= btnD;
            prevC <= btnC;

            case (arcade_state)
                ST_MENU: begin
                    // Change selection:
                    //  left/up  = previous option (wrap)
                    //  right/down = next option (wrap)
                    if (edgeL | edgeU) begin
                        if (menu_sel == 2'd0)
                            menu_sel <= 2'd2;
                        else
                            menu_sel <= menu_sel - 2'd1;
                    end else if (edgeR | edgeD) begin
                        if (menu_sel == 2'd2)
                            menu_sel <= 2'd0;
                        else
                            menu_sel <= menu_sel + 2'd1;
                    end

                    // Center selects game
                    if (edgeC) begin
                        case (menu_sel)
                            2'd0: arcade_state <= ST_ROADCROSS;
                            2'd1: arcade_state <= ST_SNAKE;
                            2'd2: arcade_state <= ST_PONG;
                            default: arcade_state <= ST_ROADCROSS;
                        endcase
                    end
                end

                ST_ROADCROSS: begin
                    // Road Cross handles its own start / game over.
                    // For now, only external reset returns to menu.
                end

                ST_SNAKE: begin
                    // Snake handles its own start / game over.
                end

                ST_PONG: begin
                    // Pong handles its own start / game over.
                end

                default: arcade_state <= ST_MENU;
            endcase
        end
    end

    //----------------------------------------------------------------
    // Instantiate games (all wired, but held in reset when inactive)
    //----------------------------------------------------------------
    wire [3:0] rc_r, rc_g, rc_b;
    wire [3:0] sn_r, sn_g, sn_b;
    wire [3:0] pg_r, pg_g, pg_b;

    wire [3:0] rc_d0, rc_d1, rc_d2, rc_d3, rc_d4, rc_d5, rc_d6, rc_d7;
    wire [3:0] sn_d0, sn_d1, sn_d2, sn_d3, sn_d4, sn_d5, sn_d6, sn_d7;
    wire [3:0] pg_d0, pg_d1, pg_d2, pg_d3, pg_d4, pg_d5, pg_d6, pg_d7;

    // Games are held in reset when not active so they restart clean
    wire rc_reset = reset | (arcade_state != ST_ROADCROSS);
    wire sn_reset = reset | (arcade_state != ST_SNAKE);
    wire pg_reset = reset | (arcade_state != ST_PONG);

    // Road-Crossing game
    crossy_game road_cross_inst (
        .clk_pix    (clk_pix),
        .reset      (rc_reset),
        .frame_tick (frame_tick),
        .btnU       (btnU),
        .btnD       (btnD),
        .btnL       (btnL),
        .btnR       (btnR),
        .btnC       (btnC),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .display_en (display_en),
        .vga_r      (rc_r),
        .vga_g      (rc_g),
        .vga_b      (rc_b),
        .score_d0   (rc_d0),
        .score_d1   (rc_d1),
        .score_d2   (rc_d2),
        .score_d3   (rc_d3),
        .score_d4   (rc_d4),
        .score_d5   (rc_d5),
        .score_d6   (rc_d6),
        .score_d7   (rc_d7)
    );

    // Snake game
    snake_game snake_inst (
        .clk_pix    (clk_pix),
        .reset      (sn_reset),
        .frame_tick (frame_tick),
        .btnU       (btnU),
        .btnD       (btnD),
        .btnL       (btnL),
        .btnR       (btnR),
        .btnC       (btnC),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .display_en (display_en),
        .vga_r      (sn_r),
        .vga_g      (sn_g),
        .vga_b      (sn_b),
        .score_d0   (sn_d0),
        .score_d1   (sn_d1),
        .score_d2   (sn_d2),
        .score_d3   (sn_d3),
        .score_d4   (sn_d4),
        .score_d5   (sn_d5),
        .score_d6   (sn_d6),
        .score_d7   (sn_d7)
    );

    // Pong game
    pong_game pong_inst (
        .clk_pix    (clk_pix),
        .reset      (pg_reset),
        .frame_tick (frame_tick),
        .btnU       (btnU),
        .btnD       (btnD),
        .btnL       (btnL),
        .btnR       (btnR),
        .btnC       (btnC),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .display_en (display_en),
        .vga_r      (pg_r),
        .vga_g      (pg_g),
        .vga_b      (pg_b),
        .score_d0   (pg_d0),
        .score_d1   (pg_d1),
        .score_d2   (pg_d2),
        .score_d3   (pg_d3),
        .score_d4   (pg_d4),
        .score_d5   (pg_d5),
        .score_d6   (pg_d6),
        .score_d7   (pg_d7)
    );

    //----------------------------------------------------------------
    // Menu rendering (Verilog Arcade title + selection)
    //----------------------------------------------------------------
    // Character coordinates
    wire [6:0] char_x       = pixel_x[9:3];
    wire [5:0] char_y       = pixel_y[8:3];
    wire [2:0] row_in_char  = pixel_y[2:0];
    wire [2:0] col_in_char  = pixel_x[2:0];

    // Font function (minimal subset)
    function [7:0] font_row;
        input [7:0] ch;
        input [2:0] row;
        begin
            font_row = 8'b00000000;
            if (row > 3'd6) begin
                font_row = 8'b00000000;
            end else begin
                case (ch)
                    8'h20: font_row = 8'b00000000; // space

                    "0": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10011000;
                            3'd3: font_row = 8'b10101000;
                            3'd4: font_row = 8'b11001000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b01110000;
                         endcase
                    "1": case(row)
                            3'd0: font_row = 8'b00100000;
                            3'd1: font_row = 8'b01100000;
                            3'd2: font_row = 8'b00100000;
                            3'd3: font_row = 8'b00100000;
                            3'd4: font_row = 8'b00100000;
                            3'd5: font_row = 8'b00100000;
                            3'd6: font_row = 8'b01110000;
                         endcase

                    // Minimal letters needed for menu: V,E,R,I,L,O,G,A,D,C,S,N,K,P
                    "A": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b11111000;
                            3'd4: font_row = 8'b10001000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b10001000;
                         endcase
                    "C": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10000000;
                            3'd3: font_row = 8'b10000000;
                            3'd4: font_row = 8'b10000000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b01110000;
                         endcase
                    "D": case(row)
                            3'd0: font_row = 8'b11100000;
                            3'd1: font_row = 8'b10010000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b10001000;
                            3'd4: font_row = 8'b10001000;
                            3'd5: font_row = 8'b10010000;
                            3'd6: font_row = 8'b11100000;
                         endcase
                    "E": case(row)
                            3'd0: font_row = 8'b11111000;
                            3'd1: font_row = 8'b10000000;
                            3'd2: font_row = 8'b10000000;
                            3'd3: font_row = 8'b11110000;
                            3'd4: font_row = 8'b10000000;
                            3'd5: font_row = 8'b10000000;
                            3'd6: font_row = 8'b11111000;
                         endcase
                    "G": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10000000;
                            3'd3: font_row = 8'b10111000;
                            3'd4: font_row = 8'b10001000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b01110000;
                         endcase
                    "I": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b00100000;
                            3'd2: font_row = 8'b00100000;
                            3'd3: font_row = 8'b00100000;
                            3'd4: font_row = 8'b00100000;
                            3'd5: font_row = 8'b00100000;
                            3'd6: font_row = 8'b01110000;
                         endcase
                    "K": case(row)
                            3'd0: font_row = 8'b10001000;
                            3'd1: font_row = 8'b10010000;
                            3'd2: font_row = 8'b10100000;
                            3'd3: font_row = 8'b11000000;
                            3'd4: font_row = 8'b10100000;
                            3'd5: font_row = 8'b10010000;
                            3'd6: font_row = 8'b10001000;
                         endcase
                    "L": case(row)
                            3'd0: font_row = 8'b10000000;
                            3'd1: font_row = 8'b10000000;
                            3'd2: font_row = 8'b10000000;
                            3'd3: font_row = 8'b10000000;
                            3'd4: font_row = 8'b10000000;
                            3'd5: font_row = 8'b10000000;
                            3'd6: font_row = 8'b11111000;
                         endcase
                    "N": case(row)
                            3'd0: font_row = 8'b10001000;
                            3'd1: font_row = 8'b11001000;
                            3'd2: font_row = 8'b10101000;
                            3'd3: font_row = 8'b10011000;
                            3'd4: font_row = 8'b10001000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b10001000;
                         endcase
                    "O": case(row)
                            3'd0: font_row = 8'b01110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b10001000;
                            3'd4: font_row = 8'b10001000;
                            3'd5: font_row = 8'b10001000;
                            3'd6: font_row = 8'b01110000;
                         endcase
                    "P": case(row)
                            3'd0: font_row = 8'b11110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b11110000;
                            3'd4: font_row = 8'b10000000;
                            3'd5: font_row = 8'b10000000;
                            3'd6: font_row = 8'b10000000;
                         endcase
                    "R": case(row)
                            3'd0: font_row = 8'b11110000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b11110000;
                            3'd4: font_row = 8'b10100000;
                            3'd5: font_row = 8'b10010000;
                            3'd6: font_row = 8'b10001000;
                         endcase
                    "S": case(row)
                            3'd0: font_row = 8'b01111000;
                            3'd1: font_row = 8'b10000000;
                            3'd2: font_row = 8'b10000000;
                            3'd3: font_row = 8'b01110000;
                            3'd4: font_row = 8'b00001000;
                            3'd5: font_row = 8'b00001000;
                            3'd6: font_row = 8'b11110000;
                         endcase
                    "V": case(row)
                            3'd0: font_row = 8'b10001000;
                            3'd1: font_row = 8'b10001000;
                            3'd2: font_row = 8'b10001000;
                            3'd3: font_row = 8'b01010000;
                            3'd4: font_row = 8'b01010000;
                            3'd5: font_row = 8'b00100000;
                            3'd6: font_row = 8'b00100000;
                         endcase

                    default: font_row = 8'b00000000;
                endcase
            end
        end
    endfunction

    // "VERILOG ARCADE"
    localparam integer TITLE_LEN = 14;
    reg [7:0] title_str [0:TITLE_LEN-1];
    initial begin
        title_str[0]  = "V";
        title_str[1]  = "E";
        title_str[2]  = "R";
        title_str[3]  = "I";
        title_str[4]  = "L";
        title_str[5]  = "O";
        title_str[6]  = "G";
        title_str[7]  = " ";
        title_str[8]  = "A";
        title_str[9]  = "R";
        title_str[10] = "C";
        title_str[11] = "A";
        title_str[12] = "D";
        title_str[13] = "E";
    end

    // "ROAD CROSS", "SNAKE", "PONG"
    localparam integer RC_LEN = 10;
    localparam integer SN_LEN = 5;
    localparam integer PG_LEN = 4;
    reg [7:0] rc_str [0:RC_LEN-1];
    reg [7:0] sn_str [0:SN_LEN-1];
    reg [7:0] pg_str [0:PG_LEN-1];

    initial begin
        rc_str[0] = "R"; rc_str[1] = "O"; rc_str[2] = "A"; rc_str[3] = "D";
        rc_str[4] = " "; rc_str[5] = "C"; rc_str[6] = "R"; rc_str[7] = "O";
        rc_str[8] = "S"; rc_str[9] = "S";

        sn_str[0] = "S"; sn_str[1] = "N"; sn_str[2] = "A"; sn_str[3] = "K";
        sn_str[4] = "E";

        pg_str[0] = "P"; pg_str[1] = "O"; pg_str[2] = "N"; pg_str[3] = "G";
    end

    //----------------------------------------------------------------
    // 7-seg driver (shows active game's score)
    //----------------------------------------------------------------
    reg [3:0] dig[0:7];
    wire [3:0] d0 = dig[0];
    wire [3:0] d1 = dig[1];
    wire [3:0] d2 = dig[2];
    wire [3:0] d3 = dig[3];
    wire [3:0] d4 = dig[4];
    wire [3:0] d5 = dig[5];
    wire [3:0] d6 = dig[6];
    wire [3:0] d7 = dig[7];

    // Select which game's score appears
    always @* begin
        if (arcade_state == ST_ROADCROSS) begin
            dig[0] = rc_d0; dig[1] = rc_d1; dig[2] = rc_d2; dig[3] = rc_d3;
            dig[4] = rc_d4; dig[5] = rc_d5; dig[6] = rc_d6; dig[7] = rc_d7;
        end else if (arcade_state == ST_SNAKE) begin
            dig[0] = sn_d0; dig[1] = sn_d1; dig[2] = sn_d2; dig[3] = sn_d3;
            dig[4] = sn_d4; dig[5] = sn_d5; dig[6] = sn_d6; dig[7] = sn_d7;
        end else if (arcade_state == ST_PONG) begin
            dig[0] = pg_d0; dig[1] = pg_d1; dig[2] = pg_d2; dig[3] = pg_d3;
            dig[4] = pg_d4; dig[5] = pg_d5; dig[6] = pg_d6; dig[7] = pg_d7;
        end else begin
            dig[0] = 4'd0; dig[1] = 4'd0; dig[2] = 4'd0; dig[3] = 4'd0;
            dig[4] = 4'd0; dig[5] = 4'd0; dig[6] = 4'd0; dig[7] = 4'd0;
        end
    end

    sevenseg_driver_8dig sevenseg_inst (
        .clk   (clk_pix),
        .reset (reset),
        .d0    (d0),
        .d1    (d1),
        .d2    (d2),
        .d3    (d3),
        .d4    (d4),
        .d5    (d5),
        .d6    (d6),
        .d7    (d7),
        .an    (an),
        .seg   (seg),
        .dp    (dp)
    );

    //----------------------------------------------------------------
    // VGA MUX: menu vs selected game
    //----------------------------------------------------------------
    reg [3:0] v_r, v_g, v_b;

    assign vgaRed   = v_r;
    assign vgaGreen = v_g;
    assign vgaBlue  = v_b;

    reg [7:0] bits;
    reg [7:0] ch;
    integer   idx;
    reg       text_pixel;

    always @* begin
        v_r = 4'h0; v_g = 4'h0; v_b = 4'h0;
        text_pixel = 1'b0;
        ch = 8'h20;
        bits = 8'h00;
        idx = 0;

        if (!display_en) begin
            v_r = 4'h0; v_g = 4'h0; v_b = 4'h0;
        end else begin
            case (arcade_state)
                ST_MENU: begin
                    // Background
                    v_r = 4'h0; v_g = 4'h0; v_b = 4'h4;

                    // Title row
                    if (char_y == 6'd8) begin
                        if (char_x >= 7'd33 && char_x < 7'd33 + TITLE_LEN) begin
                            idx = char_x - 7'd33;
                            ch  = title_str[idx];
                        end
                    end
                    // Option: Road Cross (row 24)
                    else if (char_y == 6'd24) begin
                        if (char_x >= 7'd30 && char_x < 7'd30 + RC_LEN) begin
                            idx = char_x - 7'd30;
                            ch  = rc_str[idx];
                        end
                    end
                    // Option: Snake (row 30)
                    else if (char_y == 6'd30) begin
                        if (char_x >= 7'd34 && char_x < 7'd34 + SN_LEN) begin
                            idx = char_x - 7'd34;
                            ch  = sn_str[idx];
                        end
                    end
                    // Option: Pong (row 36)
                    else if (char_y == 6'd36) begin
                        if (char_x >= 7'd34 && char_x < 7'd34 + PG_LEN) begin
                            idx = char_x - 7'd34;
                            ch  = pg_str[idx];
                        end
                    end

                    bits = font_row(ch, row_in_char);
                    text_pixel = (col_in_char < 3'd5) && (bits[7 - col_in_char] == 1'b1);

                    if (text_pixel) begin
                        v_r = 4'hF; v_g = 4'hF; v_b = 4'hF;
                    end

                    // Highlight selection line with green bar behind text
                    if (display_en) begin
                        if (menu_sel == 2'd0 && char_y == 6'd24 && !text_pixel) begin
                            v_r = 4'h0; v_g = 4'hF; v_b = 4'h0;
                        end else if (menu_sel == 2'd1 && char_y == 6'd30 && !text_pixel) begin
                            v_r = 4'h0; v_g = 4'hF; v_b = 4'h0;
                        end else if (menu_sel == 2'd2 && char_y == 6'd36 && !text_pixel) begin
                            v_r = 4'h0; v_g = 4'hF; v_b = 4'h0;
                        end
                    end
                end

                ST_ROADCROSS: begin
                    v_r = rc_r; v_g = rc_g; v_b = rc_b;
                end

                ST_SNAKE: begin
                    v_r = sn_r; v_g = sn_g; v_b = sn_b;
                end

                ST_PONG: begin
                    v_r = pg_r; v_g = pg_g; v_b = pg_b;
                end

                default: begin
                    v_r = 4'h0; v_g = 4'h0; v_b = 4'h0;
                end
            endcase
        end
    end

endmodule
