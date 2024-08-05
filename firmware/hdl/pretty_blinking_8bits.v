module pretty_blinking_8bits(
	input	wire			aresetn,
	input	wire			aclk,
	output	wire [7:0]		led_output
); 

reg	[31:0]	lfsr0;
// reg	[7:0]	lfsr;
// reg	[7:0]	lfsr2;
// reg	[7:0]	lfsr3;
initial lfsr0 = 0;
always @(posedge aclk) begin
	lfsr0		<=	lfsr0 + 1;
end

// always @(posedge aclk) begin
// 	if (~|lfsr2) begin
// 		lfsr2		<=	8'h0;
// 	end else if(&lfsr) begin
// 		lfsr2	<=	lfsr2 + 1;
// 	end
// end

// always @(posedge aclk) begin
// 	if (~|lfsr3) begin
// 		lfsr3		<=	8'h0;
// 	end else if(&lfsr2) begin
// 		lfsr3	<=	lfsr3 + 1;
// 	end
// end

assign	led_output	= lfsr0[31:24];
// assign	unused		= aresetn;
endmodule