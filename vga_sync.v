`timescale 1ns / 1ps

// 640x480 @ 60 Hz VGA timing generator
// Pixel clock: 25 MHz
module vga_sync(
    input  wire       clk_pix,      // 25 MHz pixel clock
    input  wire       reset,        // active-high reset
    output reg        hsync,
    output reg        vsync,
    output wire       display_en,   // high when in visible 640x480 area
    output wire [9:0] pixel_x,      // 0..639
    output wire [9:0] pixel_y,      // 0..479
    output wire       frame_tick    // 1 clock tick at end of each frame
);

    // 640x480 @ 60Hz, 25.175 MHz nominal timing (we use 25 MHz)
    // Horizontal timings (in pixel clocks)
    localparam H_VISIBLE   = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE  = 96;
    localparam H_BACK_PORCH  = 48;
    localparam H_TOTAL     = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH; // 800

    // Vertical timings (in lines)
    localparam V_VISIBLE   = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE  = 2;
    localparam V_BACK_PORCH  = 33;
    localparam V_TOTAL     = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 525

    reg [9:0] h_count = 10'd0;  // 0..799
    reg [9:0] v_count = 10'd0;  // 0..524

    // Horizontal & vertical counters
    always @(posedge clk_pix or posedge reset) begin
        if (reset) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL-1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL-1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    // Generate sync pulses (active-low)
    always @* begin
        // HSYNC
        if (h_count >= (H_VISIBLE + H_FRONT_PORCH) &&
            h_count <  (H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE))
            hsync = 1'b0;
        else
            hsync = 1'b1;

        // VSYNC
        if (v_count >= (V_VISIBLE + V_FRONT_PORCH) &&
            v_count <  (V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE))
            vsync = 1'b0;
        else
            vsync = 1'b1;
    end

    // Visible area
    assign display_en = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    // Pixel coordinates in visible area
    assign pixel_x = h_count;
    assign pixel_y = v_count;

    // One-tick pulse at end of frame
    assign frame_tick = (h_count == H_TOTAL-1) && (v_count == V_TOTAL-1);

endmodule
