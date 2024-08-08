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
		parameter	C_AXI_ADDR_WIDTH = 4,
		localparam	C_AXI_DATA_WIDTH = 32
		// parameter [0:0]	OPT_SKIDBUFFER = 1'b0,
		// parameter [0:0]	OPT_LOWPOWER = 0
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
		input	wire	[255:0]			gauss_input,
		output	wire	[31:0]			data_addr_read
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

	reg	[31:0]	r0, r1, r2, r3;
	wire	[31:0]	wskd_r0, wskd_r1, wskd_r2, wskd_r3;
	wire	[255:0] input_data;
	reg		[255:0] input_data_reg;
	wire	[31:0]	next_out [0:15];
	reg		[31:0]	memory;
	// reg [63:0]	reg3, reg2, reg1, reg0;
	// wire	[63:0]	reg3_wire, reg2_wire, reg1_wire, reg0_wire;
	// wire	[63:0]	reg3_src, reg2_src, reg1_src, reg0_src;
	// wire update_register;
	// assign reg3_src = gauss_input[255:192];
	// assign reg2_src = gauss_input[191:128];
	// assign reg1_src = gauss_input[127:64];
	// assign reg0_src = gauss_input[63:0];
	// assign reg3_src = {32'hF0CACC1A, 32'hD0D0CACA};
	// assign reg2_src = {32'hDEADC0DE, 32'h4B1D4B1D};
	// assign reg1_src = {32'h0B00B135, 32'hCAFEBABE};
	// assign reg0_src = {32'hDEADBEEF, 32'h1337C0D3};
	//assign input_data = {32'hF0CACC1A, 32'hD0D0CACA, 32'hDEADC0DE, 32'h4B1D4B1D, 32'h0B00B135, 32'hCAFEBABE, 32'hDEADBEEF, 32'h1337C0D3};
	generate
	genvar i_a;
		for (i_a=0; i_a<16; i_a=i_a+1) begin : next_out_assignment
			assign next_out[i_a] = {12'd0, i_a, input_data_reg[i_a*16 +: 16]};
		end
	endgenerate
	assign input_data = gauss_input;
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
	assign	wskd_r2 = apply_wstrb(r2, wskd_data, wskd_strb);
	assign	wskd_r3 = apply_wstrb(r3, wskd_data, wskd_strb);

	initial	r0 = 0;
	initial	r1 = 0;
	initial	r2 = 0;
	initial	r3 = 0;
	always @(posedge S_AXI_ACLK)
	if (i_reset)
	begin
		r0 <= 0;
		r1 <= 0;
		r2 <= 0;
		r3 <= 0;
	end else if (axil_write_ready)
	begin
		case(awskd_addr)
		2'b00:	r0 <= wskd_r0;
		2'b01:	r1 <= wskd_r1;
		2'b10:	r2 <= wskd_r2;
		2'b11:	r3 <= wskd_r3;
		endcase
	end
assign data_addr_read = r2;
// 	initial	reg3 = 0;
// 	initial	reg2 = 0;
// 	initial	reg1 = 0;
// 	initial	reg0 = 0;
// 	assign reg3_wire = {reg3[31:0], 32'd0};
// 	assign reg2_wire = {reg2[31:0], 32'd0};
// 	assign reg1_wire = {reg1[31:0], 32'd0};
// 	assign reg0_wire = {reg0[31:0], 32'd0};
// 	assign update_register = ~|{reg3_wire, reg2_wire, reg1_wire, reg0_wire}; 
// 	always @(posedge S_AXI_ACLK)
// 	// if ((!S_AXI_RVALID || S_AXI_RREADY) && (!OPT_LOWPOWER || axil_read_ready))
// 	if (!S_AXI_RVALID || S_AXI_RREADY)
// 	begin
// 		case(arskd_addr)
// //		2'b00:	reg0	<= ~|reg0_wire ? reg0_src : reg0_wire;
// //		2'b01:	reg1	<= ~|reg1_wire ? reg1_src : reg1_wire;
// //		2'b10:	reg2	<= ~|reg2_wire ? reg2_src : reg2_wire;
// //		2'b11:	reg3	<= ~|reg3_wire ? reg3_src : reg3_wire;
// 		2'b00:	reg0	<= update_register ? reg0_src : reg0_wire;
// 		2'b01:	reg1	<= update_register ? reg1_src : reg1_wire;
// 		2'b10:	reg2	<= update_register ? reg2_src : reg2_wire;
// 		2'b11:	reg3	<= update_register ? reg3_src : reg3_wire;
// 		endcase
// 	end

	initial	axil_read_data = 0;
	always @(posedge S_AXI_ACLK)
	// if (OPT_LOWPOWER && !S_AXI_ARESETN)
	// 	axil_read_data <= 0;
	// else 
	if (!S_AXI_RVALID || S_AXI_RREADY)
	begin
		case(r0[3:0])
		4'b0000:	axil_read_data	<= next_out[4'h0];
		4'b0001:	axil_read_data	<= next_out[4'h1];
		4'b0010:	axil_read_data	<= next_out[4'h2];
		4'b0011:	axil_read_data	<= next_out[4'h3];
		4'b0100:	axil_read_data	<= next_out[4'h4];
		4'b0101:	axil_read_data	<= next_out[4'h5];
		4'b0110:	axil_read_data	<= next_out[4'h6];
		4'b0111:	axil_read_data	<= next_out[4'h7];
		4'b1000:	axil_read_data	<= next_out[4'h8];
		4'b1001:	axil_read_data	<= next_out[4'h9];
		4'b1010:	axil_read_data	<= next_out[4'ha];
		4'b1011:	axil_read_data	<= next_out[4'hb];
		4'b1100:	axil_read_data	<= next_out[4'hc];
		4'b1101:	axil_read_data	<= next_out[4'hd];
		4'b1110:	axil_read_data	<= next_out[4'he];
		4'b1111:	axil_read_data	<= next_out[4'hf];
		endcase

		// if (OPT_LOWPOWER && !axil_read_ready)
		// 	axil_read_data <= 0;
	end
	initial	memory = 32'd0;
	initial input_data_reg = 0;
	always @(posedge S_AXI_ACLK)
	begin
		memory	<= r1;
		input_data_reg	<=	|(memory ^ r1) ? input_data : input_data_reg;
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
endmodule
