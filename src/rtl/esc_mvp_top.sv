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

    // INPUTS
    
    // PYNQ
    input wire clk_125_in,
    input wire rst_n,
    
    // adc
    input wire dclk,
    input wire drdy,
    input wire adc_d0,
    input wire adc_d1,
    input wire adc_d2,
    input wire adc_d3,
    input wire adc_d4,
    
    // xadc
    input wire ar_an5_p,
    input wire ar_an5_n,
    
    // sensors
    input wire hall_1,
    input wire hall_2,
    input wire hall_3,
    input wire enc_A,
    input wire enc_B,
    
    // gate driver
    input wire nfault,
    
    
    // hot swap controller
    input wire pgd,
    
    // OUTPUTS
   
    
    // gate driver
    output wire inlc,
    output wire inhc,
    output wire inlb,
    output wire inhb,
    output wire inla,
    output wire inha,
    output wire drv_en,
    
    // adc
    output wire adc_mclk_out,
    output wire adc_rst_n,
    
    // xadc bus voltage
    output wire [11:0]bus_voltage,
    
    // debug outputs to PS
    output wire rst_n_q,
    output wire dclk_q,
    output wire drdy_q,
    output wire adc_d0_q,
    output wire adc_d1_q,
    output wire adc_d2_q,
    output wire adc_d3_q,
    output wire adc_d4_q,
    output wire hall_1_q,
    output wire hall_2_q,
    output wire hall_3_q,
    output wire enc_A_q,
    output wire enc_B_q,
    output wire nfault_q,
    output wire pgd_q,
    
    // axi
    output wire mmcm1_locked_q,
    output wire mmcm2_locked_q,
    output wire rst_ctrl_q,
    output wire pwm_ctr_en_q,
    output wire compute_trig_q,
    output wire timing_fault_q,
    output wire adc_sync_req_q,
    output wire [2:0]drdy_idx_q,
    output wire [11:0]pwm_phase_q,
    output wire [2:0]timing_state_q,
    output wire [11:0]pos12_q,
    
    input wire sw_enable,
    input wire sw_clear_fault,
    
    input wire [11:0]sw_pwm_duty,
    input wire sw_dir,
    input wire sw_brake,
    input wire sw_coast,
    
    output wire fault_latched,
    output wire clk_ctrl_out
    );
    
    // debug outputs
    assign rst_n_q = rst_n;
    assign dclk_q = dclk;
    assign drdy_q = drdy;
    assign adc_d0_q = adc_d0;
    assign adc_d1_q = adc_d1;
    assign adc_d2_q = adc_d2;
    assign adc_d3_q = adc_d3;
    assign adc_d4_q = adc_d4;
    assign hall_1_q = hall_1;
    assign hall_2_q = hall_2;
    assign hall_3_q = hall_3;
    assign enc_A_q = enc_A;
    assign enc_B_q = enc_B;
    assign nfault_q = nfault;
    assign pgd_q = pgd;
    
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
    
    assign clk_ctrl_out = clk_ctrl;
    
    // reset: async assert, sync deassert to clk_ctrl
    (* ASYNC_REG = "TRUE" *) reg [1:0]rst_sync;
    always @(posedge clk_ctrl or negedge rst_n) begin
        if (!rst_n) rst_sync <= 2'b11;
        else rst_sync <= {1'b0, rst_sync[1]};
    end
    wire rst_ctrl = rst_sync[0]; // active high inside clk_ctrl
    
    // bus voltage XADC instantiation
    
    wire xadc_eoc, xadc_drdy;
    wire [15:0]xadc_do_s;
    
    // always read VAUX13 (arduino a5) status register (0x1D)
    localparam [6:0]DADDR_VAUX13 = 7'h1D;
    
    // one pulse read per conversion
    // den = DRP enable
    // for reads, assert den and wait for drdy_out to go high
    // then do_out is valid
    wire xadc_den = xadc_eoc;
    
    bus_voltage_xadc u_bus_voltage (
        .daddr_in (DADDR_VAUX13),
        .dclk_in (clk_ctrl),
        .den_in (xadc_den),
        .di_in (16'h0000), // never reconfiguring at run time
        .dwe_in (1'b0), // read-only
        .reset_in (rst_ctrl),
        
        .busy_out (),
        .channel_out (), // no sequencing
        
        // 12 MSBs hold ADC code [15:4]
        .do_out (xadc_do_s), // output data
        .drdy_out (xadc_drdy),
        .eoc_out (xadc_eoc),
        .eos_out (),
        .alarm_out (),
        
        .vauxp13 (ar_an5_p),
        .vauxn13 (ar_an5_n),
        
        .vp_in (),
        .vn_in ()
    );
    
    // capture the bus signal when drdy asserts
    reg [15:0] xadc_sample_r;
    always @(posedge clk_ctrl) begin
        if (xadc_drdy) xadc_sample_r <= xadc_do_s;
    end
    
    assign bus_voltage = xadc_sample_r[15:4];
    

    // timing hub
    wire [11:0]pwm_phase;
    wire pwm_ctr_en;
    wire compute_trig;
    wire [2:0]drdy_idx;
    wire timing_fault;
    wire adc_sync_req;
    wire [2:0]timing_state;
   
    timing_hub u_timing (
        .clk_ctrl(clk_ctrl),
        .rst_ctrl(rst_ctrl),
        .dclk(dclk),
        .drdy(drdy),
        .mmcm1_locked(mmcm1_locked),
        .mmcm2_locked(mmcm2_locked),
        .pwm_ctr(pwm_phase),
        .pwm_ctr_en(pwm_ctr_en),
        .compute_trig(compute_trig),
        .drdy_idx(drdy_idx),
        .fault(timing_fault),
        .adc_sync_req(adc_sync_req),
        .state(timing_state)
    );
    
    reg position_zero_cmd; // one cycle pulse
    wire [11:0]pos12;
    wire [13:0]pos14;
    wire pos_step_pulse, dir, enc_illegal;
    
    quad_to_pos_12bit u_pos_decoder (
        .clk(clk_ctrl),
        .rst(rst_ctrl),
        .a_in(enc_A),
        .b_in(enc_B),
        .zero_req(position_zero_cmd),
        .pos12(pos12),
        .pos14(pos14),
        .step_pulse(pos_step_pulse),
        .dir(dir),
        .illegal(enc_illegal)
    );
    
    reg adc_rst_n_reg;
    
    always @(posedge clk_ctrl) begin
        if (!mmcm1_locked || !mmcm2_locked) adc_rst_n_reg <= 1'b0;
        else adc_rst_n_reg <= 1'b1;
    end
    
    assign adc_rst_n = adc_rst_n_reg;
    
    wire trip_src = nfault || enc_illegal || timing_fault || ~mmcm1_locked || ~mmcm2_locked || ~pgd;
    wire pwm_run_enabled, pwm_fault_latched;
    
    pwm_kill u_pwm_kill (
        .clk_ctrl(clk_ctrl),
        .rst_ctrl(rst_ctrl),
        .trip_src(trip_src),
        .sw_enable(sw_enable),
        .sw_clear_fault(sw_clear_fault),
        .run_en(pwm_run_enabled),
        .fault_latched(pwm_fault_latched)
    );
    
    assign fault_latched = pwm_fault_latched;
    
    assign drv_en = pwm_run_enabled;
    
    six_step_commutator u_sixstep (
        .clk_ctrl(clk_ctrl),
        .rst_ctrl(rst_ctrl),
        .run_en(pwm_run_enabled),
        
        .pwm_ctr(pwm_phase),
        
        .hall_1(hall_1),
        .hall_2(hall_2),
        .hall_3(hall_3),
        
        .duty(sw_pwm_duty),
        .dir(sw_dir),
        .brake(sw_brake),
        .coast(sw_coast),
        
        .inha(inha),
        .inla(inla),
        .inhb(inhb),
        .inlb(inlb),
        .inhc(inhc),
        .inlc(inlc)
    );
    
    assign mmcm1_locked_q = mmcm1_locked;
    assign mmcm2_locked_q = mmcm2_locked;
    assign rst_ctrl_q = rst_ctrl;
    assign pwm_ctr_en_q = pwm_ctr_en;
    assign compute_trig_q = compute_trig;
    assign timing_fault_q = timing_fault;
    assign adc_sync_req_q = adc_sync_req;
    assign drdy_idx_q = drdy_idx;
    assign pwm_phase_q = pwm_phase;
    assign timing_state_q = timing_state;
    assign pos12_q = pos12;
    
endmodule
