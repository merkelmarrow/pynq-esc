`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2025 19:39:35
// Design Name: 
// Module Name: pwm_kill
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


module pwm_kill(
    input wire clk_ctrl, rst_ctrl,
    input wire trip_src,
    input wire sw_enable,
    input wire sw_clear_fault,
    output reg run_en,
    output reg fault_latched
    );
    
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            fault_latched <= 1'b0;
            run_en <= 1'b0;
        end else begin
            if (trip_src) fault_latched <= 1'b1;
            if (sw_clear_fault) fault_latched <= 1'b0;
            run_en <= sw_enable & ~fault_latched;
        end
    end
endmodule
