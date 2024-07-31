module byte28bits(
	din_7to0,
	dout7,
	dout6,
	dout5,
	dout4,
	dout3,
	dout2,
	dout1,
	dout0
);
output			dout7, dout6, dout5, dout4, dout3, dout2, dout1, dout0;
input	[7:0]	din_7to0;
assign dout7 = din_7to0[7];
assign dout6 = din_7to0[6];
assign dout5 = din_7to0[5];
assign dout4 = din_7to0[4];
assign dout3 = din_7to0[3];
assign dout2 = din_7to0[2];
assign dout1 = din_7to0[1];
assign dout0 = din_7to0[0];
endmodule