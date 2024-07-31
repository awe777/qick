module pmod_shift_register(
	input	wire			aresetn,
	input	wire			aclk,
	input   wire [255:0]	gauss_input,
	output	wire [7:0]		pmod_output,
	output	wire [7:0]		led_output
); 
reg	[287:0]	gauss_reg;
reg	[7:0]	lfsr;
//reg	[7:0]	lfsr2;

always @(posedge aclk) begin
	if (~aresetn) begin
		gauss_reg	<=	0;
	end else begin
		gauss_reg	<=	|gauss_reg ? {gauss_reg[279:0], 8'd0} : {32'd0, gauss_input};
	end
end
always @(posedge aclk) begin
	if (~aresetn) begin
		lfsr		<=	8'hff;
	end else if(~|gauss_reg & |gauss_input) begin
		lfsr[7]		<=	lfsr[6];
		lfsr[6]		<=	lfsr[5] ^ lfsr[7];
		lfsr[5]		<=	lfsr[4] ^ lfsr[7];
		lfsr[4]		<=	lfsr[3] ^ lfsr[7];
		lfsr[3]		<=	lfsr[2];
		lfsr[2]		<=	lfsr[1];
		lfsr[1]		<=	lfsr[0];
		lfsr[0]		<=	lfsr[7];
	end
end
// always @(posedge aclk) begin
// 	if (~aresetn) begin
// 		lfsr2		<=	8'hff;
// 	end else if(&lfsr) begin
// 		lfsr2[7]	<=	lfsr2[6];
// 		lfsr2[6]	<=	lfsr2[5] ^ lfsr2[7];
// 		lfsr2[5]	<=	lfsr2[4] ^ lfsr2[7];
// 		lfsr2[4]	<=	lfsr2[3] ^ lfsr2[7];
// 		lfsr2[3]	<=	lfsr2[2];
// 		lfsr2[2]	<=	lfsr2[1];
// 		lfsr2[1]	<=	lfsr2[0];
// 		lfsr2[0]	<=	lfsr2[7];
// 	end
// end
assign	led_output	= lfsr;
assign	pmod_output	= gauss_reg[287:280];
endmodule