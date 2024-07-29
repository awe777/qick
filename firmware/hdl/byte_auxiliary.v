module byte_auxiliary(
	din7,
	din6,
	din5,
	din4,
	din3,
	din2,
	din1,
	din0,
	gauss_output,
	dout_7to0
);
input			din7, din6, din5, din4, din3, din2, din1, din0;
output	[7:0]	dout_7to0;
output	[255:0]	gauss_output;
assign dout_7to0 = {din7, din6, din5, din4, din3, din2, din1, din0};
assign gauss_output = 256'h1337C0D3_DEADBEEF_CAFEBABE_0B00B135_4B1D4B1D_DEADC0DE_D0D0CACA_F0CACC1A;
endmodule