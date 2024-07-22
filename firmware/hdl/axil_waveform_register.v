////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	easyaxil
// {{{
// Project:	WB2AXIPSP: bus bridges and other odds and ends
//
// Purpose:	Demonstrates a simple AXI-Lite interface.
//
//	This was written in light of my last demonstrator, for which others
//	declared that it was much too complicated to understand.  The goal of
//	this demonstrator is to have logic that's easier to understand, use,
//	and copy as needed.
//
//	Since there are two basic approaches to AXI-lite signaling, both with
//	and without skidbuffers, this example demonstrates both so that the
//	differences can be compared and contrasted.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2020-2024, Gisselquist Technology, LLC
// {{{
//
// This file is part of the WB2AXIP project.
//
// The WB2AXIP project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
//
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
// original file: https://github.com/ZipCPU/wb2axip/blob/master/rtl/easyaxil.v
// }}}
module	axil_waveform_register #(
		// {{{
		//
		// Size of the AXI-lite bus.  These are fixed, since 1) AXI-lite
		// is fixed at a width of 32-bits by Xilinx def'n, and 2) since
		// we only ever have 4 configuration words.
		parameter	C_AXI_ADDR_WIDTH = 4,
		localparam	C_AXI_DATA_WIDTH = 32,
		// parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
		parameter [0:0]	OPT_LOWPOWER = 0
		// }}}
	) (
		// {{{
		input	wire					S_AXI_ACLK,
		input	wire					S_AXI_ARESETN,
		//
		input	wire					S_AXI_AWVALID,
		output	wire					S_AXI_AWREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_AWADDR,
		input	wire	[2:0]				S_AXI_AWPROT,
		//
		input	wire					S_AXI_WVALID,
		output	wire					S_AXI_WREADY,
		input	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_WDATA,
		input	wire	[C_AXI_DATA_WIDTH/8-1:0]	S_AXI_WSTRB,
		//
		output	wire					S_AXI_BVALID,
		input	wire					S_AXI_BREADY,
		output	wire	[1:0]				S_AXI_BRESP,
		//
		input	wire					S_AXI_ARVALID,
		output	wire					S_AXI_ARREADY,
		input	wire	[C_AXI_ADDR_WIDTH-1:0]		S_AXI_ARADDR,
		input	wire	[2:0]				S_AXI_ARPROT,
		//
		output	wire					S_AXI_RVALID,
		input	wire					S_AXI_RREADY,
		output	wire	[C_AXI_DATA_WIDTH-1:0]		S_AXI_RDATA,
		output	wire	[1:0]				S_AXI_RRESP,
		input	wire	[255:0]				dac0,
		input	wire	[255:0]				dac1,
		input	wire	[255:0]				dac2,
		input	wire	[255:0]				dac3,
		input	wire	[255:0]				dac4,
		input	wire	[255:0]				dac5,
		input	wire	[255:0]				dac6,
		input	wire						dac0_clk,
		input	wire						dac1_clk,
		input	wire						dac2_clk,
		input	wire						dac3_clk,
		input	wire						dac4_clk,
		input	wire						dac5_clk,
		input	wire						dac6_clk
		// }}}
	);

	////////////////////////////////////////////////////////////////////////
	//
	// Register/wire signal declarations
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	localparam	ADDRLSB = $clog2(C_AXI_DATA_WIDTH)-3;

	wire	i_reset = !S_AXI_ARESETN;

	wire				axil_write_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	awskd_addr;
	//
	wire	[C_AXI_DATA_WIDTH-1:0]	wskd_data;
	wire [C_AXI_DATA_WIDTH/8-1:0]	wskd_strb;
	reg				axil_bvalid;
	//
	wire				axil_read_ready;
	wire	[C_AXI_ADDR_WIDTH-ADDRLSB-1:0]	arskd_addr;
	reg	[C_AXI_DATA_WIDTH-1:0]	axil_read_data;
	reg				axil_read_valid;

	reg		[31:0]	r0, r1;
	wire	[31:0]	wskd_r0, wskd_r1;
	reg		[15:0]	last_value;
	reg		[255:0] dac0_r, dac1_r, dac2_r, dac3_r, dac4_r, dac5_r, dac6_r;
	reg				dac0_f, dac1_f, dac2_f, dac3_f, dac4_f, dac5_f, dac6_f;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite signaling
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	//
	// Write signaling
	//
	// {{{

	generate 
	// if (OPT_SKIDBUFFER)
	// begin : SKIDBUFFER_WRITE
	// 	// {{{
	// 	wire	awskd_valid, wskd_valid;

	// 	skidbuffer #(.OPT_OUTREG(0),
	// 			.OPT_LOWPOWER(OPT_LOWPOWER),
	// 			.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
	// 	axilawskid(//
	// 		.i_clk(S_AXI_ACLK), .i_reset(i_reset),
	// 		.i_valid(S_AXI_AWVALID), .o_ready(S_AXI_AWREADY),
	// 		.i_data(S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
	// 		.o_valid(awskd_valid), .i_ready(axil_write_ready),
	// 		.o_data(awskd_addr));

	// 	skidbuffer #(.OPT_OUTREG(0),
	// 			.OPT_LOWPOWER(OPT_LOWPOWER),
	// 			.DW(C_AXI_DATA_WIDTH+C_AXI_DATA_WIDTH/8))
	// 	axilwskid(//
	// 		.i_clk(S_AXI_ACLK), .i_reset(i_reset),
	// 		.i_valid(S_AXI_WVALID), .o_ready(S_AXI_WREADY),
	// 		.i_data({ S_AXI_WDATA, S_AXI_WSTRB }),
	// 		.o_valid(wskd_valid), .i_ready(axil_write_ready),
	// 		.o_data({ wskd_data, wskd_strb }));

	// 	assign	axil_write_ready = awskd_valid && wskd_valid
	// 			&& (!S_AXI_BVALID || S_AXI_BREADY);
	// 	// }}}
	// end else 
	begin : SIMPLE_WRITES
		// {{{
		reg	axil_awready;

		initial	axil_awready = 1'b0;
		always @(posedge S_AXI_ACLK)
		if (!S_AXI_ARESETN)
			axil_awready <= 1'b0;
		else
			axil_awready <= !axil_awready
				&& (S_AXI_AWVALID && S_AXI_WVALID)
				&& (!S_AXI_BVALID || S_AXI_BREADY);

		assign	S_AXI_AWREADY = axil_awready;
		assign	S_AXI_WREADY  = axil_awready;

		assign 	awskd_addr = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	wskd_data  = S_AXI_WDATA;
		assign	wskd_strb  = S_AXI_WSTRB;

		assign	axil_write_ready = axil_awready;
		// }}}
	end endgenerate

	initial	axil_bvalid = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_bvalid <= 0;
	else if (axil_write_ready)
		axil_bvalid <= 1;
	else if (S_AXI_BREADY)
		axil_bvalid <= 0;

	assign	S_AXI_BVALID = axil_bvalid;
	assign	S_AXI_BRESP = 2'b00;
	// }}}

	//
	// Read signaling
	//
	// {{{

	generate 
	// if (OPT_SKIDBUFFER)
	// begin : SKIDBUFFER_READ
	// 	// {{{
	// 	wire	arskd_valid;

	// 	skidbuffer #(.OPT_OUTREG(0),
	// 			.OPT_LOWPOWER(OPT_LOWPOWER),
	// 			.DW(C_AXI_ADDR_WIDTH-ADDRLSB))
	// 	axilarskid(//
	// 		.i_clk(S_AXI_ACLK), .i_reset(i_reset),
	// 		.i_valid(S_AXI_ARVALID), .o_ready(S_AXI_ARREADY),
	// 		.i_data(S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB]),
	// 		.o_valid(arskd_valid), .i_ready(axil_read_ready),
	// 		.o_data(arskd_addr));

	// 	assign	axil_read_ready = arskd_valid
	// 			&& (!axil_read_valid || S_AXI_RREADY);
	// 	// }}}
	// end else 
	begin : SIMPLE_READS
		// {{{
		reg	axil_arready;

		always @(*)
			axil_arready = !S_AXI_RVALID;

		assign	arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
		assign	S_AXI_ARREADY = axil_arready;
		assign	axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);
		// }}}
	end endgenerate

	initial	axil_read_valid = 1'b0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
		axil_read_valid <= 1'b0;
	else if (axil_read_ready)
		axil_read_valid <= 1'b1;
	else if (S_AXI_RREADY)
		axil_read_valid <= 1'b0;

	assign	S_AXI_RVALID = axil_read_valid;
	assign	S_AXI_RDATA  = axil_read_data;
	assign	S_AXI_RRESP = 2'b00;
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// AXI-lite register logic
	//
	////////////////////////////////////////////////////////////////////////
	//
	// {{{

	// apply_wstrb(old_data, new_data, write_strobes)
	assign	wskd_r0 = apply_wstrb(r0, wskd_data, wskd_strb);
	assign	wskd_r1 = apply_wstrb(r1, wskd_data, wskd_strb);

	initial	r0 = 32'hffffffff;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		r0 <= 32'hffffffff;
	end else if (axil_write_ready)
	begin
		case(awskd_addr)
		2'b00:		r0 <= wskd_r0;
		2'b10:		r0 <= wskd_r0;
		endcase
	end

	initial	r1 = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		r1 <= 0;
	end else
	begin
		case(r0[7:0])
		8'h00:		r1 <= dac0_r[255:224];
		8'h01:		r1 <= dac0_r[223:192];
		8'h02:		r1 <= dac0_r[191:160];
		8'h03:		r1 <= dac0_r[159:128];
		8'h04:		r1 <= dac0_r[127:96];
		8'h05:		r1 <= dac0_r[95:64];
		8'h06:		r1 <= dac0_r[63:32];
		8'h07:		r1 <= dac0_r[31:0];
		8'h10:		r1 <= dac1_r[255:224];
		8'h11:		r1 <= dac1_r[223:192];
		8'h12:		r1 <= dac1_r[191:160];
		8'h13:		r1 <= dac1_r[159:128];
		8'h14:		r1 <= dac1_r[127:96];
		8'h15:		r1 <= dac1_r[95:64];
		8'h16:		r1 <= dac1_r[63:32];
		8'h17:		r1 <= dac1_r[31:0];
		8'h20:		r1 <= dac2_r[255:224];
		8'h21:		r1 <= dac2_r[223:192];
		8'h22:		r1 <= dac2_r[191:160];
		8'h23:		r1 <= dac2_r[159:128];
		8'h24:		r1 <= dac2_r[127:96];
		8'h25:		r1 <= dac2_r[95:64];
		8'h26:		r1 <= dac2_r[63:32];
		8'h27:		r1 <= dac2_r[31:0];
		8'h30:		r1 <= dac3_r[255:224];
		8'h31:		r1 <= dac3_r[223:192];
		8'h32:		r1 <= dac3_r[191:160];
		8'h33:		r1 <= dac3_r[159:128];
		8'h34:		r1 <= dac3_r[127:96];
		8'h35:		r1 <= dac3_r[95:64];
		8'h36:		r1 <= dac3_r[63:32];
		8'h37:		r1 <= dac3_r[31:0];
		8'h40:		r1 <= dac4_r[255:224];
		8'h41:		r1 <= dac4_r[223:192];
		8'h42:		r1 <= dac4_r[191:160];
		8'h43:		r1 <= dac4_r[159:128];
		8'h44:		r1 <= dac4_r[127:96];
		8'h45:		r1 <= dac4_r[95:64];
		8'h46:		r1 <= dac4_r[63:32];
		8'h47:		r1 <= dac4_r[31:0];
		8'h50:		r1 <= dac5_r[255:224];
		8'h51:		r1 <= dac5_r[223:192];
		8'h52:		r1 <= dac5_r[191:160];
		8'h53:		r1 <= dac5_r[159:128];
		8'h54:		r1 <= dac5_r[127:96];
		8'h55:		r1 <= dac5_r[95:64];
		8'h56:		r1 <= dac5_r[63:32];
		8'h57:		r1 <= dac5_r[31:0];
		8'h60:		r1 <= dac6_r[255:224];
		8'h61:		r1 <= dac6_r[223:192];
		8'h62:		r1 <= dac6_r[191:160];
		8'h63:		r1 <= dac6_r[159:128];
		8'h64:		r1 <= dac6_r[127:96];
		8'h65:		r1 <= dac6_r[95:64];
		8'h66:		r1 <= dac6_r[63:32];
		8'h67:		r1 <= dac6_r[31:0];
		default:	r1 <= 32'hdeadbeef;
		endcase
	end

	initial	axil_read_data = 0;
	always @(posedge S_AXI_ACLK)
	if (OPT_LOWPOWER && !S_AXI_ARESETN)
		axil_read_data <= 0;
	else if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		case(arskd_addr)
		2'b00:	axil_read_data	<= r0;
		2'b01:	axil_read_data	<= r1;
		2'b10:	axil_read_data	<= r0;
		2'b11:	axil_read_data	<= r1;
		endcase

		if (OPT_LOWPOWER && !axil_read_ready)
			axil_read_data <= 0;
	end

	initial	last_value = 16'hffff;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		last_value <= 16'hffff;
	end else 
	begin
		last_value <= r0[31:16];
	end

	initial	dac0_r = 0;
	initial	dac0_f = 0;
	always @(posedge dac0_clk)
	if (i_reset)
	begin
		dac0_r <= 0;
		dac0_f <= 0;
	end else
	begin
		dac0_r <= |(last_value ^ r0[31:16]) & ~dac0_f ? dac0 : dac0_r;
		dac0_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac1_r = 0;
	initial	dac1_f = 0;
	always @(posedge dac1_clk)
	if (i_reset)
	begin
		dac1_r <= 0;
		dac1_f <= 0;
	end else
	begin
		dac1_r <= |(last_value ^ r0[31:16]) & ~dac1_f ? dac1 : dac1_r;
		dac1_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac2_r = 0;
	initial	dac2_f = 0;
	always @(posedge dac2_clk)
	if (i_reset)
	begin
		dac2_r <= 0;
		dac2_f <= 0;
	end else
	begin
		dac2_r <= |(last_value ^ r0[31:16]) & ~dac2_f ? dac2 : dac2_r;
		dac2_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac3_r = 0;
	initial	dac3_f = 0;
	always @(posedge dac3_clk)
	if (i_reset)
	begin
		dac3_r <= 0;
		dac3_f <= 0;
	end else
	begin
		dac3_r <= |(last_value ^ r0[31:16]) & ~dac3_f ? dac3 : dac3_r;
		dac3_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac4_r = 0;
	initial	dac4_f = 0;
	always @(posedge dac4_clk)
	if (i_reset)
	begin
		dac4_r <= 0;
		dac4_f <= 0;
	end else
	begin
		dac4_r <= |(last_value ^ r0[31:16]) & ~dac4_f ? dac4 : dac4_r;
		dac4_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac5_r = 0;
	initial	dac5_f = 0;
	always @(posedge dac5_clk)
	if (i_reset)
	begin
		dac5_r <= 0;
		dac5_f <= 0;
	end else
	begin
		dac5_r <= |(last_value ^ r0[31:16]) & ~dac5_f ? dac5 : dac5_r;
		dac5_f <= |(last_value ^ r0[31:16]);
	end
	initial	dac6_r = 0;
	initial	dac6_f = 0;
	always @(posedge dac6_clk)
	if (i_reset)
	begin
		dac6_r <= 0;
		dac6_f <= 0;
	end else
	begin
		dac6_r <= |(last_value ^ r0[31:16]) & ~dac6_f ? dac6 : dac6_r;
		dac6_f <= |(last_value ^ r0[31:16]);
	end	

	function [C_AXI_DATA_WIDTH-1:0]	apply_wstrb;
		input	[C_AXI_DATA_WIDTH-1:0]		prior_data;
		input	[C_AXI_DATA_WIDTH-1:0]		new_data;
		input	[C_AXI_DATA_WIDTH/8-1:0]	wstrb;

		integer	k;
		for(k=0; k<C_AXI_DATA_WIDTH/8; k=k+1)
		begin
			apply_wstrb[k*8 +: 8]
				= wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
		end
	endfunction
	// }}}

	// Make Verilator happy
	// {{{
	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
			S_AXI_ARADDR[ADDRLSB-1:0],
			S_AXI_AWADDR[ADDRLSB-1:0] };
	// Verilator lint_on  UNUSED
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// `ifdef	FORMAL
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	// The AXI-lite control interface
// 	//
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	// {{{
// 	localparam	F_AXIL_LGDEPTH = 4;
// 	wire	[F_AXIL_LGDEPTH-1:0]	faxil_rd_outstanding,
// 					faxil_wr_outstanding,
// 					faxil_awr_outstanding;

// 	faxil_slave #(
// 		// {{{
// 		.C_AXI_DATA_WIDTH(C_AXI_DATA_WIDTH),
// 		.C_AXI_ADDR_WIDTH(C_AXI_ADDR_WIDTH),
// 		.F_LGDEPTH(F_AXIL_LGDEPTH),
// 		.F_AXI_MAXWAIT(3),
// 		.F_AXI_MAXDELAY(3),
// 		.F_AXI_MAXRSTALL(5),
// 		.F_OPT_COVER_BURST(4)
// 		// }}}
// 	) faxil(
// 		// {{{
// 		.i_clk(S_AXI_ACLK), .i_axi_reset_n(S_AXI_ARESETN),
// 		//
// 		.i_axi_awvalid(S_AXI_AWVALID),
// 		.i_axi_awready(S_AXI_AWREADY),
// 		.i_axi_awaddr( S_AXI_AWADDR),
// 		.i_axi_awprot( S_AXI_AWPROT),
// 		//
// 		.i_axi_wvalid(S_AXI_WVALID),
// 		.i_axi_wready(S_AXI_WREADY),
// 		.i_axi_wdata( S_AXI_WDATA),
// 		.i_axi_wstrb( S_AXI_WSTRB),
// 		//
// 		.i_axi_bvalid(S_AXI_BVALID),
// 		.i_axi_bready(S_AXI_BREADY),
// 		.i_axi_bresp( S_AXI_BRESP),
// 		//
// 		.i_axi_arvalid(S_AXI_ARVALID),
// 		.i_axi_arready(S_AXI_ARREADY),
// 		.i_axi_araddr( S_AXI_ARADDR),
// 		.i_axi_arprot( S_AXI_ARPROT),
// 		//
// 		.i_axi_rvalid(S_AXI_RVALID),
// 		.i_axi_rready(S_AXI_RREADY),
// 		.i_axi_rdata( S_AXI_RDATA),
// 		.i_axi_rresp( S_AXI_RRESP),
// 		//
// 		.f_axi_rd_outstanding(faxil_rd_outstanding),
// 		.f_axi_wr_outstanding(faxil_wr_outstanding),
// 		.f_axi_awr_outstanding(faxil_awr_outstanding)
// 		// }}}
// 		);

// 	always @(*)
// 	if (OPT_SKIDBUFFER)
// 	begin
// 		assert(faxil_awr_outstanding== (S_AXI_BVALID ? 1:0)
// 			+(S_AXI_AWREADY ? 0:1));
// 		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0)
// 			+(S_AXI_WREADY ? 0:1));

// 		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0)
// 			+(S_AXI_ARREADY ? 0:1));
// 	end else begin
// 		assert(faxil_wr_outstanding == (S_AXI_BVALID ? 1:0));
// 		assert(faxil_awr_outstanding == faxil_wr_outstanding);

// 		assert(faxil_rd_outstanding == (S_AXI_RVALID ? 1:0));
// 	end

// 	//
// 	// Check that our low-power only logic works by verifying that anytime
// 	// S_AXI_RVALID is inactive, then the outgoing data is also zero.
// 	//
// 	always @(*)
// 	if (OPT_LOWPOWER && !S_AXI_RVALID)
// 		assert(S_AXI_RDATA == 0);
// 	// }}}
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	// Register return checking
// 	// {{{
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	//
// `define	CHECK_REGISTERS
// `ifdef	CHECK_REGISTERS
// 	faxil_register #(
// 		// {{{
// 		.AW(C_AXI_ADDR_WIDTH),
// 		.DW(C_AXI_DATA_WIDTH),
// 		.ADDR(0)
// 		// }}}
// 	) fr0 (
// 		// {{{
// 		.S_AXI_ACLK(S_AXI_ACLK),
// 		.S_AXI_ARESETN(S_AXI_ARESETN),
// 		.S_AXIL_AWW(axil_write_ready),
// 		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_WDATA(wskd_data),
// 		.S_AXIL_WSTRB(wskd_strb),
// 		.S_AXIL_BVALID(S_AXI_BVALID),
// 		.S_AXIL_AR(axil_read_ready),
// 		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_RVALID(S_AXI_RVALID),
// 		.S_AXIL_RDATA(S_AXI_RDATA),
// 		.i_register(r0)
// 		// }}}
// 	);

// 	faxil_register #(
// 		// {{{
// 		.AW(C_AXI_ADDR_WIDTH),
// 		.DW(C_AXI_DATA_WIDTH),
// 		.ADDR(4)
// 		// }}}
// 	) fr1 (
// 		// {{{
// 		.S_AXI_ACLK(S_AXI_ACLK),
// 		.S_AXI_ARESETN(S_AXI_ARESETN),
// 		.S_AXIL_AWW(axil_write_ready),
// 		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_WDATA(wskd_data),
// 		.S_AXIL_WSTRB(wskd_strb),
// 		.S_AXIL_BVALID(S_AXI_BVALID),
// 		.S_AXIL_AR(axil_read_ready),
// 		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_RVALID(S_AXI_RVALID),
// 		.S_AXIL_RDATA(S_AXI_RDATA),
// 		.i_register(r1)
// 		// }}}
// 	);

// 	faxil_register #(
// 		// {{{
// 		.AW(C_AXI_ADDR_WIDTH),
// 		.DW(C_AXI_DATA_WIDTH),
// 		.ADDR(8)
// 		// }}}
// 	) fr2 (
// 		// {{{
// 		.S_AXI_ACLK(S_AXI_ACLK),
// 		.S_AXI_ARESETN(S_AXI_ARESETN),
// 		.S_AXIL_AWW(axil_write_ready),
// 		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_WDATA(wskd_data),
// 		.S_AXIL_WSTRB(wskd_strb),
// 		.S_AXIL_BVALID(S_AXI_BVALID),
// 		.S_AXIL_AR(axil_read_ready),
// 		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_RVALID(S_AXI_RVALID),
// 		.S_AXIL_RDATA(S_AXI_RDATA),
// 		.i_register(r2)
// 		// }}}
// 	);

// 	faxil_register #(
// 		// {{{
// 		.AW(C_AXI_ADDR_WIDTH),
// 		.DW(C_AXI_DATA_WIDTH),
// 		.ADDR(12)
// 		// }}}
// 	) fr3 (
// 		// {{{
// 		.S_AXI_ACLK(S_AXI_ACLK),
// 		.S_AXI_ARESETN(S_AXI_ARESETN),
// 		.S_AXIL_AWW(axil_write_ready),
// 		.S_AXIL_AWADDR({ awskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_WDATA(wskd_data),
// 		.S_AXIL_WSTRB(wskd_strb),
// 		.S_AXIL_BVALID(S_AXI_BVALID),
// 		.S_AXIL_AR(axil_read_ready),
// 		.S_AXIL_ARADDR({ arskd_addr, {(ADDRLSB){1'b0}} }),
// 		.S_AXIL_RVALID(S_AXI_RVALID),
// 		.S_AXIL_RDATA(S_AXI_RDATA),
// 		.i_register(r3)
// 		// }}}
// 	);
// `endif
// 	// }}}
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	// Cover checks
// 	//
// 	////////////////////////////////////////////////////////////////////////
// 	//
// 	// {{{

// 	// While there are already cover properties in the formal property
// 	// set above, you'll probably still want to cover something
// 	// application specific here

// 	// }}}
// `endif
// }}}
endmodule
