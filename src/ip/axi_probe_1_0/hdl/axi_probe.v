
`timescale 1 ns / 1 ps

	module axi_probe #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here
		input wire rst_n,
		input wire dclk, drdy,
		input wire adc_d0, adc_d1, adc_d2, adc_d3, adc_d4,
		input wire hall_1, hall_2, hall_3,
		input wire enc_A, enc_B,
		input wire nfault, pgd,
		input wire mmcm1_locked, mmcm2_locked,
		input wire pwm_ctr_en, compute_trig, timing_fault, adc_sync_req,
		input wire fault_latched,
		input wire [2:0]drdy_idx,
		input wire [11:0]pwm_phase,
		input wire [11:0]bus_voltage,
		input wire [2:0]timing_state,
		input wire [11:0]pos12,
		
		input wire clk_ctrl,
		input wire rst_ctrl, 
		
		output wire sw_enable_pwm,
		output wire sw_clear_fault,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
// Instantiation of Axi Bus Interface S00_AXI
	axi_probe_slave_lite_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) axi_probe_slave_lite_v1_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
		.rst_n (rst_n),
		.dclk (dclk),
		.drdy (drdy),
		.adc_d0 (adc_d0),
		.adc_d1 (adc_d1),
		.adc_d2 (adc_d2),
		.adc_d3 (adc_d3),
		.adc_d4 (adc_d4),
		.hall_1 (hall_1),
		.hall_2 (hall_2),
		.hall_3 (hall_3),
		.enc_A (enc_A),
		.enc_B (enc_B),
		.nfault (nfault),
		.pgd (pgd),
		.mmcm1_locked (mmcm1_locked),
		.mmcm2_locked (mmcm2_locked),
		.timing_state (timing_state),
		.pwm_ctr_en (pwm_ctr_en),
		.compute_trig (compute_trig),
		.fault_latched(fault_latched),
		.timing_fault (timing_fault),
		.adc_sync_req (adc_sync_req),
		.drdy_idx (drdy_idx),
		.pwm_phase (pwm_phase),
		.bus_voltage (bus_voltage),
		.pos12 (pos12),
		
		.clk_ctrl(clk_ctrl),
		.rst_ctrl(rst_ctrl),
		
		.sw_enable_pwm(sw_enable_pwm),
		.sw_clear_fault(sw_clear_fault)
	);

	// Add user logic here

	// User logic ends

	endmodule
