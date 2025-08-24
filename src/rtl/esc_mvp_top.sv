`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: N/A
// Engineer: Marco Blackwell
// 
// Create Date: 16.08.2025 17:34:51
// Design Name: 
// Module Name: esc_mvp_top
// Project Name: PYNQ ESC
// Target Devices: PYNQ-Z2
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


module esc_mvp_top(
    input clk_125_in,
    input rst_n,
    output adc_mclk_out,
    output pwm_out
    );
    
    wire mclk;
    wire mmcm1_locked;
    
    // CLKIN = 125.000 MHz, CLKOUT = 32.76801 MHz
    mmcm_stage1 u_mmcm_stage1 (
        .clk_in1 (clk_125_in),
        .reset (~rst_n),
        .clk_out1 (mclk),
        .locked (mmcm1_locked)
    );
    
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) u_oddr_mclk_out (
        .C (mclk),
        .CE (1'b1),
        .D1 (1'b1),
        .D2 (1'b0),
        .Q  (adc_mclk_out),
        .R (1'b0),
        .S (1'b0)
    );
    
    // sync mmcm1_locked into MCLK domain
    (* ASYNC_REG = "TRUE" *) reg [1:0]lock_sync;
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) lock_sync <= 2'b00;
        else lock_sync <= {lock_sync[0], mmcm1_locked};
    end
    
    // hold MMCM #2 in reset until lock is stable for a few cycles
    reg [3:0]holdoff;
    reg mmcm2_rst_r; // drives MMCM2 reset pin
    
    always @(posedge mclk or negedge rst_n) begin
        if (!rst_n) begin
            holdoff <= 4'b1111;
            mmcm2_rst_r <= 1'b1;
        end else if (!lock_sync[1]) begin
            holdoff <= 4'b1111;
            mmcm2_rst_r <= 1'b1;
        end else if (holdoff != 0) begin
            holdoff <= holdoff - 1'b1;
            mmcm2_rst_r <= 1'b1;
        end else begin
            mmcm2_rst_r <= 1'b0;
        end
    end
    
    wire clk_ctrl;
    wire mmcm2_locked;
    
    mmcm_stage2 u_mmcm_stage2 (
        .clk_in1 (mclk),
        .reset (mmcm2_rst_r),
        .clk_out1 (clk_ctrl),
        .locked (mmcm2_locked)
    );
    
    // reset: async assert, sync deassert to clk_ctrl
    (* ASYNC_REG = "TRUE" *) reg [1:0]rst_sync;
    always @(posedge clk_ctrl or negedge rst_n) begin
        if (!rst_n) rst_sync <= 2'b11;
        else rst_sync <= {1'b0, rst_sync[1]};
    end
    wire rst_ctrl = rst_sync[0]; // active high inside clk_ctrl
    
    // divider to scope output from clk_ctrl
    reg [20:0] div_cnt;
    reg div_tog;
    
    always @(posedge clk_ctrl or posedge rst_ctrl) begin
        if (rst_ctrl) begin
            div_cnt <= 21'b0;
            div_tog <= 1'b0;
        end else begin
            div_cnt <= div_cnt + 1'b1;
            if (div_cnt == 21'b0) // toggles every 2^21 cycles
                div_tog <= ~div_tog;
        end
    end
    assign pwm_out = div_tog; // probe output
    
endmodule
