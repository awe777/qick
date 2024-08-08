module waveform_analyzer
	(
		mem_dout_real_i	,
		mem_dout_imag_i	,
		gauss_output_a,
		gauss_output_b,
		gauss_output_c,
		status_flag,
		data_addr_read,
		rstn,
		clk
	);
parameter [31:0] N_DDS = 16;
parameter [31:0] STORED_SETS = 16;

endmodule