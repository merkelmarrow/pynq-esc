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
    
    // SPI
    input wire miso,
    
    // hot swap controller
    input wire pgd,
    
    // OUTPUTS
    
    // SPI
    output wire sclk,
    output wire mosi,
    output wire drv_cs_n,
    output wire adc_cs_n,
    
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
    output wire miso_q,
    output wire pgd_q
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
    assign miso_q = miso;
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
    
    // always read the vp/vn status register (0x03)
    localparam [6:0]DADDR_VPVN = 7'h03;
    
    // one pulse read per conversion
    // den = DRP enable
    // for reads, assert den and wait for drdy_out to go high
    // then do_out is valid
    wire xadc_den = xadc_eoc;
    
    bus_voltage_xadc u_bus_voltage (
        .daddr_in (DADDR_VPVN),
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
        
        .vp_in (ar_an5_p),
        .vn_in (ar_an5_n)
    );
    
    // capture the bus signal when drdy asserts
    reg [15:0] xadc_sample_r;
    always @(posedge clk_ctrl) begin
        if (xadc_drdy) xadc_sample_r <= xadc_do_s;
    end
    
    assign bus_voltage = xadc_sample_r[15:4];
    

    // timing hub
    reg [11:0]pwm_phase;
    reg pwm_ctr_en;
    reg compute_trig;
    reg [2:0]drdy_idx;
    reg timing_fault;
    reg adc_sync_req;
    reg [2:0]timing_state;
   
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
    
    
endmodule
