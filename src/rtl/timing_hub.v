`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Marco Blackwell
// 
// Create Date: 24.08.2025 21:01:03
// Design Name: 
// Module Name: timing_hub
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


module timing_hub #(
    parameter integer PWM_TICKS = 4096, // ctrl ticks per pwm period
    parameter integer TS_TICKS = 512, // approximate ctrl ticks per sampling period
    parameter integer READ_DCLKS = 24, // bits per ADC sample
    parameter integer COMPUTE_BUDGET = 399, // ctrl ticks available for pwm compute
    parameter integer SETTLE_TS_MIN = 7, // minimum ADC settling delay
    parameter integer DCLK_RATIO_NOM = 4, // expected ctrl ticks per dclk tick
    parameter integer DCLK_RATIO_TOL = 1, // tolerance for expected ctrl ticks per dclk (\pm TOL)
    parameter integer DCLK_GOOD_COUNT = 255, // consecutive good dclk cycles during DCLKCHK
    parameter integer PWM_PHASE_OFFSET = 0,
    parameter integer HB_TIMEOUT_TICKS = 64 // dclk heartbeat timeout in ctrl ticks
    ) (
    input wire clk_ctrl,
    input wire rst_ctrl,
    input wire dclk,
    
    input wire drdy,
    
    input wire mmcm1_locked,
    input wire mmcm2_locked,
    
    output reg [11:0]pwm_ctr,
    output reg pwm_ctr_en,
    output reg compute_trig,
    output reg [2:0]drdy_idx,
    output reg fault,
    output reg adc_sync_req,
    output reg [2:0]state
    );
    
    localparam [11:0]DEADLINE_TICKS = PWM_TICKS - COMPUTE_BUDGET - 1;
    
    localparam [2:0]
        ST_RESET = 3'd0,
        ST_DCLKCHK = 3'd1,
        ST_DRDYWAIT = 3'd2,
        ST_RUN = 3'd3,
        ST_REALIGN = 3'd4,
        ST_FAULT = 3'd5;
        
    
        
    // dclk domain block
    // negative edge dclk sampling of drdy
    // count 24 dclk negedges to complete a frame read
    // emit 2 CDC toggles into clk_ctrl: drdy_seen, frame_done
    
    (* ASYNC_REG = "true" *) reg [1:0]rst_dclk_sync;
    always @(negedge dclk or posedge rst_ctrl) begin
        if (rst_ctrl) rst_dclk_sync <= 2'b11;
        else rst_dclk_sync <= {1'b0, rst_dclk_sync[1]};
    end
    wire rst_dclk = rst_dclk_sync[0]; // active high in dclk domain
    
    reg d_in_frame;
    reg [5:0]dclk_count; // counts 0-23 during sampling
    reg d_tog_drdy;
    reg d_tog_frame;
    
    // 3-state view in DCLK domain
    // WAIT_DRDY -> DRDY_HIGH -> SAMPLING -> WAIT...
    always @(negedge dclk or posedge rst_dclk) begin
        if (rst_dclk) begin
            d_in_frame <= 1'b0;
            dclk_count <= 6'd0;
            d_tog_drdy <= 1'b0;
            d_tog_frame <= 1'b0;
        end else begin            
            if (!d_in_frame) begin
                // DRDY_WAIT
                if (drdy) begin
                    // DRDY_HIGH
                    d_tog_drdy <= ~d_tog_drdy;
                    d_in_frame <= 1'b1;
                    dclk_count <= 6'd0;
                end
            end else begin
                // SAMPLING
                dclk_count <= dclk_count + 6'd1;
                if (dclk_count == (READ_DCLKS - 1)) begin
                    d_in_frame <= 1'b0;
                    d_tog_frame <= ~d_tog_frame;
                end
            end
        end
    end
    
    // CDC for DRDY and FRAME_DONE to clk_ctrl
    (* ASYNC_REG = "TRUE" *) reg [2:0]cdc_drdy_sync;
    (* ASYNC_REG = "TRUE" *) reg [2:0]cdc_frame_sync;
    
    reg drdy_pulse, frame_pulse;
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            cdc_drdy_sync <= 3'd0;
            cdc_frame_sync <= 3'd0;
            drdy_pulse <= 1'b0;
            frame_pulse <= 1'b0;
        end else begin
            cdc_drdy_sync <= {cdc_drdy_sync[1:0], d_tog_drdy};
            cdc_frame_sync <= {cdc_frame_sync[1:0], d_tog_frame};
            
            drdy_pulse  <= (cdc_drdy_sync[2]  ^ cdc_drdy_sync[1]); // 1-cycle pulse
            frame_pulse <= (cdc_frame_sync[2] ^ cdc_frame_sync[1]);
        end
    end
    
    // clk_ctrl DCLK stability check
    // measure clk_ctrl ticks between DCLK edges
    // many consecutive good measurements settle timer >= 7*T_s (ADC settling time)
    (* ASYNC_REG = "TRUE" *) reg [2:0]dclk_csync;
    reg dclk_sync, dclk_sync_q;
    reg [7:0]good_cnt;
    reg [7:0]tickspan; // number of ctrl ticks detected for a given dclk period
    reg [15:0]tick_counter;
    reg dclk_ok;
    reg [15:0]settle_counter;
    reg [7:0]last_cap; // timestamp of last capture
    reg have_cap; // do we have a last capture to compare against  
    
    wire settle_done = (settle_counter >= (SETTLE_TS_MIN * TS_TICKS));
    wire dclk_rise = (dclk_sync & ~dclk_sync_q);
    
    always @(posedge clk_ctrl) begin
        // sync dclk
        dclk_csync <= {dclk_csync[1:0], dclk};
        dclk_sync <= dclk_csync[2];
        dclk_sync_q <= dclk_sync;
        
        // free run counter for dclk period measurements
        tick_counter <= tick_counter + 16'd1;
        
        if (rst_ctrl) begin
            good_cnt <= 8'd0;
            tickspan <= 8'd0;
            dclk_ok <= 1'b0;
            settle_counter <= 16'd0;
            
            tick_counter <= 16'd0;
            last_cap <= 8'd0;
            have_cap <= 1'b0;
        end else begin
            if (state == ST_DCLKCHK && (mmcm1_locked && mmcm2_locked)) begin  
                settle_counter <= settle_counter + 16'd1;
                
                if (dclk_rise) begin
                    if (have_cap) begin
                        tickspan <= (tick_counter[7:0] - last_cap);
                    end
                    last_cap <= tick_counter[7:0];
                    have_cap <= 1'b1;
                    
                    if (have_cap && (tickspan >= (DCLK_RATIO_NOM - DCLK_RATIO_TOL)) &&
                        (tickspan <= (DCLK_RATIO_NOM + DCLK_RATIO_TOL))) begin
                        if (good_cnt != 8'hFF) good_cnt <= good_cnt + 8'd1;
                    end else begin
                        good_cnt <= 8'd0;
                    end
                    
                    if (good_cnt >= DCLK_GOOD_COUNT) dclk_ok <= 1'b1;
                end
            end else begin
                // when not actively checking, keep checker reset
                good_cnt <= 8'd0;
                dclk_ok <= 1'b0;
                settle_counter <= 16'd0;
                have_cap <= 1'b0;
            end
        end
    end
    
    // dclk heartbeat
    reg [15:0]hb_ctr;
    wire dclk_edge = (dclk_sync ^ dclk_sync_q); // any edge
    wire hb_tripped = (hb_ctr >= HB_TIMEOUT_TICKS[15:0]);
    
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            hb_ctr <= 16'd0;
        end else begin
            if (dclk_edge) hb_ctr <= 16'd0;
            else if (hb_ctr != 16'hFFFF) hb_ctr <= hb_ctr + 16'd1;
            
        end
    end
    
    // pwm timebase for freeze at wrap and phase offset
    reg realign_active;
    reg realign_pending;
    reg arm_pend; // apply PWM_PHASE_OFFSET after align_now
    reg [11:0]phase_cnt;
    
    wire at_wrap = (pwm_ctr == (PWM_TICKS[11:0] - 12'd1));
    wire almost_at_wrap = (pwm_ctr == (PWM_TICKS[11:0] - 12'd2));
    wire early_almost_wrap = pwm_ctr == (PWM_TICKS[11:0] - 12'd3);
    
    // hold only while phase_cnt is strictly less than offset
    wire phase_hold = arm_pend && (phase_cnt < PWM_PHASE_OFFSET[11:0]);
    wire hold_pwm = (realign_active && at_wrap) || phase_hold;
    
    // command pulses from FSM
    reg cmd_align_now;
    reg cmd_request_realign;

    
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            pwm_ctr <= 12'd0;
            pwm_ctr_en <= 1'b0; // arm after first cmd_align_now
            arm_pend <= 1'b0;
            phase_cnt <= 12'd0;
            realign_active <= 1'b0;
            realign_pending <= 1'b0;
        end else begin            
            if (cmd_align_now) begin
                pwm_ctr <= 12'd0;
                phase_cnt <= 12'd0;
                arm_pend <= (PWM_PHASE_OFFSET != 0);
                realign_active <= 1'b0; // cancel freeze
                realign_pending <= 1'b0;
                pwm_ctr_en <= 1'b1;
            end 

            else if (pwm_ctr_en && !hold_pwm) begin
                pwm_ctr <= at_wrap ? 12'd0 : (pwm_ctr + 12'd1);
            end
            
            if (arm_pend) begin
                if (phase_cnt == PWM_PHASE_OFFSET[11:0]) begin
                    arm_pend <= 1'b0;
                end else begin
                    phase_cnt <= phase_cnt + 12'd1;
                end
            end
            
            if (cmd_request_realign) begin
                realign_pending <= 1'b1;
            end
            
            // convert latched request into a freeze-at-wrap
            // assert realign_active exactly one tick before wrap
            // this is evald after the FSM's early request has been registered
            if (realign_pending && almost_at_wrap && !hold_pwm) begin
                realign_active <= 1'b1; // makes hold_pwm true at wrap
                realign_pending <= 1'b0;
            end
            
            // once at wrap and holding, counter freezes
            // release occurs at cmd_align_now on DRDY in ST_REALIGN
        end
    end
    
    // drdy indexing and compute trigger gating by deadline
    reg seen_idx7;
    reg missed_deadline;
    
    wire idx7_this_tick = (frame_pulse && (drdy_idx == 3'd7));
    
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            drdy_idx <= 3'd0;
            compute_trig <= 1'b0;
            seen_idx7 <= 1'b0;
            missed_deadline <= 1'b0;
        end else begin
            compute_trig <= 1'b0; // default low, 1 cycle pulses only
            
            if (frame_pulse) begin
                // gate compute strictly before deadline
                if (state == ST_RUN && (drdy_idx == 3'd7)) begin
                    if (pwm_ctr < DEADLINE_TICKS) begin
                        compute_trig <= 1'b1;
                    end else begin
                        missed_deadline <= 1'b1;
                    end
                end
                
                drdy_idx <= drdy_idx + 3'd1;
            end
            
            if (idx7_this_tick) begin
                seen_idx7 <= 1'b1;
            end
            
            // housekeeping
            if (at_wrap && !hold_pwm) begin
                drdy_idx <= 3'd0;
                seen_idx7 <= 1'b0;
                missed_deadline <= 1'b0;
            end
            
            if (state == ST_DRDYWAIT || state == ST_REALIGN) begin
                drdy_idx <= 3'd0;
                seen_idx7 <= 1'b0;
                missed_deadline <= 1'b0;
            end
        end
    end
    
    // finite state machine
    // uses early_almost_wrap to schedule a freeze that engages at the next cycle
        // so the counter actually holds at wrap
    // need_realign tracked to not miss scheduling window
    // missed deadline -> soft reset, freeze at wrap until next DRDY
    // no 8th sample -> hard reset, SPI reset ADC, leave PWM running with previous
        // compute until ADC settled, then soft reset
        
    
        
    reg need_realign;
    
    
    always @(posedge clk_ctrl) begin
        if (rst_ctrl) begin
            state <= ST_RESET;
            fault <= 1'b0;
            adc_sync_req <= 1'b0;
            cmd_align_now <= 1'b0;
            cmd_request_realign <= 1'b0;
            need_realign <= 1'b0;
        end else begin
            // defaults
            adc_sync_req <= 1'b0;
            fault <= 1'b0;
            cmd_align_now <= 1'b0;
            cmd_request_realign <= 1'b0;
            
            if (missed_deadline) need_realign <= 1'b1;
            
            case (state)
                ST_RESET: begin
                    need_realign <= 1'b0;
                    if (mmcm1_locked && mmcm2_locked) begin
                        state <= ST_DCLKCHK;
                    end
                end
                
                ST_DCLKCHK: begin
                    need_realign <= 1'b0;
                    if (mmcm1_locked && mmcm2_locked && dclk_ok && settle_done) begin
                        state <= ST_DRDYWAIT;
                    end
                end
                
                ST_DRDYWAIT: begin
                    need_realign <= 1'b0;
                    // align PWM start to next DRDY + optional phase offset
                    if (drdy_pulse) begin
                        cmd_align_now <= 1'b1; // timebase will zero ctr and start phase
                        state <= ST_RUN;
                    end
                end
                
                ST_RUN: begin
                    // schedule freeze at wrap, assert request at early_almost_wrap
                    if (need_realign && early_almost_wrap && !hold_pwm) begin
                        cmd_request_realign <= 1'b1; // timebase will assert realign_active at almost_at_wrap
                    end
                    
                    if (hb_tripped || !mmcm1_locked || !mmcm2_locked) begin
                        fault <= 1'b1;
                        adc_sync_req <= 1'b1; // one cycle pulse
                        need_realign <= 1'b0;
                        state <= ST_FAULT;
                    end else begin
                        // period end decisions evald at last tick
                        if (at_wrap) begin
                            if (!hold_pwm) begin
                                if (!(seen_idx7 || idx7_this_tick)) begin
                                    // no idx 7 this period, hard reset
                                    fault <= 1'b1;
                                    adc_sync_req <= 1'b1;
                                    need_realign <= 1'b0;
                                    state <= ST_FAULT;
                                end 
                                need_realign <= 1'b0;
                            end else begin
                                state <= ST_REALIGN;
                                need_realign <= 1'b0;
                            end
                        end
                    end
                end
                
                ST_REALIGN: begin
                    // freeze is active, continue at next drdy 
                    if (drdy_pulse) begin
                        cmd_align_now <= 1'b1; // re-arms phase
                        need_realign <= 1'b0;
                        state <= ST_RUN;
                    end
                end
                
                ST_FAULT: begin
                    // recheck DCLK stability for >= 7*Ts after sync
                    // return through DCLKCHK, then pause at PWM wrap and wait for DRDY
                    fault <= 1'b1;
                    need_realign <= 1'b0;
                    if (mmcm1_locked && mmcm2_locked) begin
                        state <= ST_DCLKCHK;
                    end
                end
                
                default: state <= ST_RESET;
                
            endcase
        end
    end
   
endmodule
