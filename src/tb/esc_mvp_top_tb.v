`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Marco Blackwell
// 
// Create Date: 24.08.2025 19:07:26
// Design Name: 
// Module Name: esc_mvp_top_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module esc_mvp_top_tb;

    reg clk_125_in = 1'b0;
    reg rst_n = 1'b0;
    wire adc_mclk_out;
    wire pwm_out;
    
    // 125 MHz clock
    always #4 clk_125_in = ~clk_125_in;
    
    esc_mvp_top uut (
        .clk_125_in (clk_125_in),
        .rst_n (rst_n),
        .adc_mclk_out (adc_mclk_out),
        .pwm_out (pwm_out)
    );
    
    // scope out internals so they show on testbench waveform
    wire mclk = uut.mclk;
    wire mmcm1_locked = uut.mmcm1_locked;
    wire [1:0] lock_sync = uut.lock_sync;
    wire [3:0] holdoff = uut.holdoff;
    wire mmcm2_rst_r = uut.mmcm2_rst_r;
    
    wire clk_ctrl = uut.clk_ctrl;
    wire mmcm2_locked = uut.mmcm2_locked;
    wire [1:0] rst_sync = uut.rst_sync;
    wire rst_ctrl = uut.rst_ctrl;
    
    wire [20:0] div_cnt = uut.div_cnt;
    wire div_tog = uut.div_tog;
    
    initial begin
        rst_n = 1'b0;
        repeat (10) @(posedge clk_125_in);
        rst_n = 1'b1;
    end
    
    initial begin
        #(15_000);
        $finish;
    end
endmodule
