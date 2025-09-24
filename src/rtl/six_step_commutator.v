`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.09.2025 14:31:27
// Design Name: 
// Module Name: six_step_commutator
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


module six_step_commutator #(
    parameter integer PWM_BITS = 12,
    parameter integer PWM_TICKS = 4096 // should match 2^PWM_BITS
    ) (
    input wire clk_ctrl, rst_ctrl,
    input wire run_en,
    
    input wire [PWM_BITS-1:0]pwm_ctr,
    
    input wire hall_1, hall_2, hall_3,
    
    input wire [PWM_BITS-1:0]duty,
    input wire dir,
    input wire brake, // all lows on
    input wire coast, // all off
    
    output reg inha, inla, inhb, inlb, inhc, inlc
    
    );
    
    `define SYNC_CTRL(sig) \
	   (* ASYNC_REG = "TRUE" *) reg sig``_q1; \
	   (* ASYNC_REG = "TRUE" *) reg sig``_q2; \
	   always @(posedge clk_ctrl or posedge rst_ctrl) begin \
	       if (rst_ctrl) begin sig``_q1 <= 1'b0; sig``_q2 <= 1'b0; end \
	       else begin sig``_q1 <= sig; sig``_q2 <= sig``_q1; end \
	   end \
	   wire sig``_ctrl = sig``_q2;
	   
    `SYNC_CTRL(hall_1)
    `SYNC_CTRL(hall_2)
    `SYNC_CTRL(hall_3)
	   
    wire [2:0]halls;
    assign halls = {hall_3_ctrl, hall_2_ctrl, hall_1_ctrl};
    
    // sector decode 
    reg [2:0]sec_raw;
    always @(*) begin
        case ({halls[2], halls[1], halls[0]})
            3'b001: sec_raw = 3'd0; // A+ B-
            3'b101: sec_raw = 3'd1; // A+ C-
            3'b100: sec_raw = 3'd2; // B+ C-
            3'b110: sec_raw = 3'd3; // B+ A-
            3'b010: sec_raw = 3'd4; // C+ A-
            3'b011: sec_raw = 3'd5; // C+ B-
            default: sec_raw = 3'd7; // invalid
        endcase
    end
    
    wire [2:0]sector = (sec_raw == 3'd7) ? 3'd7 : (dir ? (3'd5 - sec_raw) : sec_raw);
    
    // center aligned PWM 
    localparam [PWM_BITS-1:0]HALF_TICKS = (PWM_TICKS / 2);
    localparam [PWM_BITS-1:0]D_MAX = {PWM_BITS{1'b1}}; // 2^(PWM_BITS) - 1
    
    // clamp duty to max
    wire [PWM_BITS-1:0]duty_clamped = (duty > D_MAX) ? D_MAX : duty;
    
    // duty half = ceil(duty/2)
    wire [PWM_BITS-1:0]duty_half = (duty_clamped >> 1) + duty_clamped[0];
    
    // absolute difference to centre
    reg [PWM_BITS-1:0]diff_to_mid;
    
    always @(*) begin
        if (pwm_ctr >= HALF_TICKS)
            diff_to_mid = pwm_ctr - HALF_TICKS;
        else
            diff_to_mid = HALF_TICKS - pwm_ctr;
    end
    
    wire pwm_active = (diff_to_mid < duty_half);
    
    // for commutation, one high, one low, one OFF
    // coast - all OFF
    // break - all LOW
    
    always @(*) begin
        // default coast
        inha = 1'b0; inla = 1'b0;
        inhb = 1'b0; inlb = 1'b0;
        inhc = 1'b0; inlc = 1'b0;
        
        // safety gate
        if (!run_en) begin
            // OFF
        end else if (coast) begin
            // OFF
        end else if (sector == 3'd7) begin
            // OFF
        end else if (brake) begin
            inla = 1'b1;
            inlb = 1'b1;
            inlc = 1'b1;
        end else begin
            case (sector)
                3'd0: begin
                    inha = pwm_active; inla = 1'b0;
                    inhb = 1'b0; inlb = 1'b1;
                    inhc = 1'b0; inlc = 1'b0;
                end 3'd1: begin
                    inha = pwm_active; inla = 1'b0;
                    inhb = 1'b0; inlb = 1'b0;
                    inhc = 1'b0; inlc = 1'b1;
                end 3'd2: begin
                    inha = 1'b0; inla = 1'b0;
                    inhb = pwm_active; inlb = 1'b0;
                    inhc = 1'b0; inlc = 1'b1;
                end 3'd3: begin
                    inha = 1'b0; inla = 1'b1;
                    inhb = pwm_active; inlb = 1'b0;
                    inhc = 1'b0; inlc = 1'b0;
                end 3'd4: begin
                    inha = 1'b0; inla = 1'b1;
                    inhb = 1'b0; inlb = 1'b0;
                    inhc = pwm_active; inlc = 1'b0;
                end 3'd5: begin
                    inha = 1'b0; inla = 1'b0;
                    inhb = 1'b0; inlb = 1'b1;
                    inhc = pwm_active; inlc = 1'b0;
                end 
            endcase
        end
    end
    
endmodule
