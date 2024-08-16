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
// N_DDS * STORED_SETS must be equal to 256
input										rstn;
input										clk;
input 		[N_DDS*16-1:0]					mem_dout_real_i;
input 		[N_DDS*16-1:0]					mem_dout_imag_i;
input		[31:0]							data_addr_read;
output		[31:0]							gauss_output_a;
output		[31:0]							gauss_output_b;
output		[31:0]							gauss_output_c;
output		[7:0]							status_flag;
// section 1
reg			[15:0]							last_real[0:N_DDS-1];
reg			[15:0]							last_imag[0:N_DDS-1];
wire		[31:0]							data_comb[0:N_DDS-1];
// section 2
reg			[31:0]							stored_values[0:N_DDS*STORED_SETS-1];
wire										disable_memory_update;
// section 3
reg											stop_shift_register;
reg											last_set_nonzero;
wire										flush_memory;
wire										stop_sr_trigger;
reg			[3:0]							ctrl_flush_memory;
reg			[3:0]							ctrl_sr_en_toggle;
reg			[7:0]							addr_a;
reg			[7:0]							addr_b;
reg			[7:0]							addr_c;
reg			[1:0]							stop_trigger;
// section 4
reg			[31:0]							result_a;
reg			[31:0]							result_b;
reg			[31:0]							result_c;
// section 1 "assignment" - long form
generate 
genvar i_a;
	for (i_a=0; i_a<N_DDS; i_a=i_a+1) begin : section_1
		assign data_comb[i_a] = {last_real[i_a], last_imag[i_a]};
		always @(posedge clk) begin
			if (~rstn) begin
				last_real[i_a]						<=	0;
				last_imag[i_a]						<=	0;
			end
			else begin
				last_real[i_a]						<=	mem_dout_real_i		[i_a*16 +: 16];
				last_imag[i_a]						<=	mem_dout_imag_i		[i_a*16 +: 16];
			end
		end
	end
endgenerate
// section 2 "assignment" - long form
generate
genvar i_b, j_b;
	for (i_b=0; i_b<STORED_SETS; i_b=i_b+1) begin : section_2_0
		for (j_b=0; j_b<N_DDS; j_b=j_b+1) begin : section_2_1
			if (i_b==0) begin
				always @(posedge clk) begin
					if (~rstn | flush_memory) begin 
						stored_values[i_b*N_DDS + j_b]	<= 0;
					end
					else if (~disable_memory_update) begin 
						stored_values[i_b*N_DDS + j_b]	<= data_comb[j_b];
					end
				end
			end
			else begin
				always @(posedge clk) begin
					if (~rstn | flush_memory) begin 
						stored_values[i_b*N_DDS + j_b]	<= 0;
					end
					else if (~disable_memory_update) begin 
						stored_values[i_b*N_DDS + j_b]	<= stored_values[(i_b-1)*N_DDS + j_b];
					end
				end
			end
		end
	end
endgenerate
assign disable_memory_update = stop_shift_register | last_set_nonzero;
// section 3 "assignment" - long form
always @(posedge clk) begin
	if (~rstn) begin 
		stop_shift_register	<=	0;
		ctrl_flush_memory	<=	0;
		ctrl_sr_en_toggle	<=	0;
		addr_a				<=	0;
		addr_b				<=	0;
		addr_c				<=	0;
		last_set_nonzero	<=	0;
	end
	else begin 
		stop_shift_register	<=	stop_sr_trigger ? ~stop_shift_register : stop_shift_register;
		ctrl_flush_memory	<=	data_addr_read[31:28];
		ctrl_sr_en_toggle	<=	data_addr_read[27:24];
		addr_a				<=	data_addr_read[23:16];
		addr_b				<=	data_addr_read[15:8];
		addr_c				<=	data_addr_read[7:0];
		last_set_nonzero	<=	|stored_values[240];
	end
end
assign stop_sr_trigger = |(ctrl_sr_en_toggle ^ data_addr_read[27:24]);
always @(posedge clk) begin
	if (~rstn | flush_memory) begin 
		stop_trigger		<=	0;
	end
	else if (~|stop_trigger) begin 
		stop_trigger		<=	{stop_shift_register, last_set_nonzero};
	end
end
assign flush_memory = |(ctrl_flush_memory ^ data_addr_read[31:28]);
// section 4 "assignment" - long form
always @(posedge clk) begin
	if (~rstn | flush_memory) begin 
		result_a		<=	0;
		result_b		<=	0;
		result_c		<=	0;
	end
	else if (disable_memory_update) begin 
		result_a		<=	stored_values[addr_a];
		result_b		<=	stored_values[addr_b];
		result_c		<=	stored_values[addr_c];
	end
end
// output assignment
assign gauss_output_a = result_a;
assign gauss_output_b = result_b;
assign gauss_output_c = result_c;
assign status_flag = {4'hf, stop_trigger, stop_shift_register, last_set_nonzero};
endmodule