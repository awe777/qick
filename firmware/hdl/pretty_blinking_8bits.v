module pretty_blinking_8bits(
	input	wire			aresetn,
	input	wire			aclk,
	output	wire [7:0]		led_output
); 
reg	[7:0]	lfsr;
reg	[7:0]	lfsr2;
//reg	[7:0]	lfsr3;
wire 		unused;

always @(posedge aclk) begin
	if (~|lfsr) begin
		lfsr		<=	8'hff;
	end else begin
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

always @(posedge aclk) begin
	if (~|lfsr2) begin
		lfsr2		<=	8'hff;
	end else if(&lfsr) begin
		lfsr2[7]	<=	lfsr2[6];
		lfsr2[6]	<=	lfsr2[5] ^ lfsr2[7];
		lfsr2[5]	<=	lfsr2[4] ^ lfsr2[7];
		lfsr2[4]	<=	lfsr2[3] ^ lfsr2[7];
		lfsr2[3]	<=	lfsr2[2];
		lfsr2[2]	<=	lfsr2[1];
		lfsr2[1]	<=	lfsr2[0];
		lfsr2[0]	<=	lfsr2[7];
	end
end
// too slow
//always @(posedge aclk) begin
//	if (~aresetn) begin
//		lfsr3		<=	8'hff;
//	end else if(&lfsr2) begin
//		lfsr3[7]	<=	lfsr3[6];
//		lfsr3[6]	<=	lfsr3[5] ^ lfsr3[7];
//		lfsr3[5]	<=	lfsr3[4] ^ lfsr3[7];
//		lfsr3[4]	<=	lfsr3[3] ^ lfsr3[7];
//		lfsr3[3]	<=	lfsr3[2];
//		lfsr3[2]	<=	lfsr3[1];
//		lfsr3[1]	<=	lfsr3[0];
//		lfsr3[0]	<=	lfsr3[7];
//	end
//end

assign	led_output	= lfsr2;
assign	unused		= aresetn;
endmodule