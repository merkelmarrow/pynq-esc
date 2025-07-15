`timescale 1ns / 1ps

module rc_pwm_capture_tb;

    localparam CLK_NS = 8; // 125 MHz
    reg clk = 0;
    always #(CLK_NS/2) clk = ~clk;
    
    reg rst_n = 0;
    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;
    end
    
    reg pwm = 0;
    
    initial begin
        wait (rst_n == 1);
        @(posedge rst_n);
        forever begin
            pwm = 1; #(1200_000); // 1.2 ms
            pwm = 0; #(18_800_000); // rest to make 20 ms (50 Hz signal)
            pwm = 1; #(1500_000); // 1.5 ms
            pwm = 0; #(18_500_000);
            pwm = 1; #(1800_000); // 1.8 ms
            pwm = 0; #(18_200_000);    
        end
    end       
    
    wire [31:0] width;
    wire flag;
    
    rc_pwm_capture uut(
        .sysclk(clk), .rst_n(rst_n),
        .rc_pwm_in(pwm),
        .pulse_width(width),
        .new_data(flag)
    );
    
    always @(posedge clk)
        if (flag) $display  ("Width captured = %0d ticks = %0.1f us",
                                width, width/100.0);
    initial begin
        #500_000_000 $finish; // 0.5 s sim
    end
endmodule
