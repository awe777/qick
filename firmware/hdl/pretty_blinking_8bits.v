module pretty_blinking_8bits(
	input	wire			aresetn,
	input	wire			aclk,
	output	wire [7:0]		led_output
); 

// reg	[31:0]	lfsr0;
reg	[7:0]	lfsr0;
wire [7:0]	next0;
reg	[7:0]	lfsr1;
wire [7:0]	next1;
reg	[7:0]	lfsr2;
wire [7:0]	next2;
// initial lfsr0 = 0;
// always @(posedge aclk) begin
// 	lfsr0		<=	lfsr0 + 1;
// end
assign next0 = {lfsr0[6], lfsr0[5] ^ lfsr0[7], lfsr0[4] ^ lfsr0[7], lfsr0[3] ^ lfsr0[7], lfsr0[2], lfsr0[1], lfsr0[0], lfsr0[7]};
initial lfsr0 = 8'hff;
always @(posedge aclk) begin
	if (~|lfsr0) begin
		lfsr0		<=	8'hff;
	end else begin
		lfsr0		<=	next0;
	end
end

assign next1 = {lfsr1[6], lfsr1[5] ^ lfsr1[7], lfsr1[4] ^ lfsr1[7], lfsr1[3] ^ lfsr1[7], lfsr1[2], lfsr1[1], lfsr1[0], lfsr1[7]};
initial lfsr1 = 8'hff;
always @(posedge aclk) begin
	if (~|lfsr1) begin
		lfsr1		<=	8'hff;
	end else if (&next0) begin
		lfsr1		<=	next1;
	end
end

assign next2 = {lfsr2[6], lfsr2[5] ^ lfsr2[7], lfsr2[4] ^ lfsr2[7], lfsr2[3] ^ lfsr2[7], lfsr2[2], lfsr2[1], lfsr2[0], lfsr2[7]};
initial lfsr2 = 8'hff;
always @(posedge aclk) begin
	if (~|lfsr2) begin
		lfsr2		<=	8'hff;
	end else if (&next1) begin
		lfsr2		<=	next2;
	end
end
// always @(posedge aclk) begin
// 	if (~|lfsr3) begin
// 		lfsr3		<=	8'h0;
// 	end else if(&lfsr2) begin
// 		lfsr3	<=	lfsr3 + 1;
// 	end
// end

assign	led_output	= lfsr2;
assign	unused		= aresetn;
endmodule