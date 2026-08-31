`timescale 1ns / 1ps

module tb_top_crossy;

    reg CLK100MHZ;
    reg CPU_RESETN;

    reg BTNC, BTNU, BTND, BTNL, BTNR;

    wire [3:0] VGA_R, VGA_G, VGA_B;
    wire       VGA_HS, VGA_VS;

    wire       CA, CB, CC, CD, CE, CF, CG, DP;
    wire [7:0] AN;

    top_crossy dut (
        .CLK100MHZ (CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .BTNC      (BTNC),
        .BTNU      (BTNU),
        .BTND      (BTND),
        .BTNL      (BTNL),
        .BTNR      (BTNR),
        .VGA_R     (VGA_R),
        .VGA_G     (VGA_G),
        .VGA_B     (VGA_B),
        .VGA_HS    (VGA_HS),
        .VGA_VS    (VGA_VS),
        .CA        (CA),
        .CB        (CB),
        .CC        (CC),
        .CD        (CD),
        .CE        (CE),
        .CF        (CF),
        .CG        (CG),
        .DP        (DP),
        .AN        (AN)
    );

    // 100 MHz clock
    always #5 CLK100MHZ = ~CLK100MHZ;

    initial begin
        CLK100MHZ  = 1'b0;
        CPU_RESETN = 1'b0;

        BTNC = 0; BTNU = 0; BTND = 0; BTNL = 0; BTNR = 0;

        #200;
        CPU_RESETN = 1'b1;

        // Wait on start screen
        #10_000_000;

        // Start game
        BTNC = 1'b1;
        #200_000;
        BTNC = 1'b0;

        // Some random moves
        repeat (20) begin
            BTNU = $random;
            BTND = $random;
            BTNL = $random;
            BTNR = $random;
            #1_000_000;
            BTNU = 0; BTND = 0; BTNL = 0; BTNR = 0;
            #2_000_000;
        end

        $display("tb_top_crossy finished.");
        $stop;
    end

endmodule
