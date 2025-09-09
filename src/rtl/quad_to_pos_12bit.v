`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08.09.2025 21:40:41
// Design Name: 
// Module Name: quad_to_pos_12bit
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


module quad_to_pos_12bit #(
    parameter INVERT_A = 1'b0, // inversion in case wired wrong
    parameter INVERT_B = 1'b0,
    parameter integer MIN_STEP_CYCLES = 2 // must be less than 255
    ) (
    input wire clk,
    input wire rst,
    input wire a_in,
    input wire b_in,
    input wire zero_req,
    output wire [11:0]pos12,
    output reg [13:0]pos14,
    output reg step_pulse, dir, illegal
    );
    
    // assumes CPR = 4096, STATES -> 16384, 14 bits
    localparam integer STATES = (4 * 4096);
    localparam [13:0]MAX14 = 14'd16383; // STATES - 1
    
    // cdc, double flip flop sync
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0]a_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [2:0]b_sync;
    always @(posedge clk) begin
        a_sync <= {a_sync[1:0], (a_in ^ INVERT_A)};
        b_sync <= {b_sync[1:0], (b_in ^ INVERT_B)};
    end
    wire a = a_sync[2];
    wire b = b_sync[2];
    
    
    reg [1:0]prev;
    reg [1:0]curr;
    wire same = (curr == prev);
    
    // deglitch, require MIN_STEP_CYCLES between accepted steps
    reg [7:0]step_age;
    
    // don't evaluate transitions until prev is seeded
    reg primed;
    
    // CW/ACW decode
    wire is_cw, is_acw;
    
    // 00 -> 01 -> 11 -> 10 -> 00 is CW
    assign is_cw = (prev == 2'b00 && curr == 2'b01) ||
        (prev == 2'b01 && curr == 2'b11) ||
        (prev == 2'b11 && curr == 2'b10) ||
        (prev == 2'b10 && curr == 2'b00);
            
    assign is_acw = (prev == 2'b00 && curr == 2'b10) ||
        (prev == 2'b10 && curr == 2'b11) ||
        (prev == 2'b11 && curr == 2'b01) || 
        (prev == 2'b01 && curr == 2'b00);
        
    // illegal change
    wire two_bits_changed = (prev[1]^curr[1]) & (prev[0]^curr[0]);
    
    // position updates
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev <= 2'b00;
            curr <= 2'b00;
            primed <= 1'b0;
            
            pos14 <= 14'b0;
            
            step_pulse <= 1'b0;
            dir <= 1'b0;
            illegal <= 1'b0;
            
            step_age <= 8'hFF; // long time ago
        end else begin
            curr <= {a,b};
            
            // defaults
            step_pulse <= 1'b0;
            illegal <= 1'b0;
            if (step_age != 8'hFF) step_age <= step_age + 8'd1;
            
            if (zero_req) begin
                pos14 <= 14'd0;
                // pos12 updates from pos14
            end else begin
                // avoid registering first step until prev is seeded
                if (!primed) begin
                    primed <= 1'b1;
                end else if (!same) begin
                    if (two_bits_changed) begin
                        illegal <= 1'b1;
                    end else if ((is_cw || is_acw) &&
                        (step_age >= MIN_STEP_CYCLES)) begin
                        step_pulse <= 1'b1;
                        dir <= is_cw;
                        step_age <= 8'd0;
                        
                        if (is_cw) begin
                            pos14 <= (pos14 == MAX14) ? 14'd0 : (pos14 + 14'd1);
                        end else begin
                            pos14 <= (pos14 == 14'd0) ? MAX14 : (pos14 - 14'd1);
                        end
                    end
                end
            end
            
            prev <= curr;
        end
    end
    
    assign pos12 = pos14[13:2];
    
endmodule
