`timescale 1ns / 1ps

module tb_sevenseg_driver;
    reg        clk;
    reg        reset;
    reg  [3:0] d0, d1, d2, d3, d4, d5, d6, d7;
    wire [7:0] AN;
    wire       CA, CB, CC, CD, CE, CF, CG, DP;
    
    sevenseg_driver dut (
        .clk   (clk),
        .reset (reset),
        .d0    (d0),
        .d1    (d1),
        .d2    (d2),
        .d3    (d3),
        .d4    (d4),
        .d5    (d5),
        .d6    (d6),
        .d7    (d7),
        .AN    (AN),
        .CA    (CA),
        .CB    (CB),
        .CC    (CC),
        .CD    (CD),
        .CE    (CE),
        .CF    (CF),
        .CG    (CG),
        .DP    (DP)
    );
    
    // 100 MHz clock
    always #5 clk = ~clk;
    
    integer count;
    
    initial begin
        $display("====================================");
        $display("  Seven-Segment Display Testbench");
        $display("  Cycling 0-9 on all digits");
        $display("====================================");
        
        clk   = 1'b0;
        reset = 1'b1;
        count = 0;
        
        // Initialize all digits to 0
        d0 = 4'd0; d1 = 4'd0; d2 = 4'd0; d3 = 4'd0;
        d4 = 4'd0; d5 = 4'd0; d6 = 4'd0; d7 = 4'd0;
        
        #100;
        reset = 1'b0;
        $display("[%0t] Reset released - Starting count", $time);
        
        // Cycle through 0-9, displaying each number for 50ms
        for (count = 0; count < 10; count = count + 1) begin
            d0 = count[3:0];
            d1 = count[3:0];
            d2 = count[3:0];
            d3 = count[3:0];
            d4 = count[3:0];
            d5 = count[3:0];
            d6 = count[3:0];
            d7 = count[3:0];
            
            $display("[%0t] All digits showing: %0d", $time, count);
            
            // Wait 50ms (50,000,000 ns) at 100 MHz
            #50_000_000;
        end
       
        
        // Hold final value for observation
        #50_000_000;
        
        $display("[%0t] Testbench finished.", $time);
        $stop;
    end
    
    // Monitor to show what's displayed in real-time
    initial begin
        $monitor("[%0t] Display = %0d%0d%0d%0d%0d%0d%0d%0d", 
                 $time, d7, d6, d5, d4, d3, d2, d1, d0);
    end
    
endmodule