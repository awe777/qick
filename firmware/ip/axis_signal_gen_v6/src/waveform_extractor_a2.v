/*
	New stuff:
	logic [31: 0] a_vect;
	logic [0 :31] b_vect;
	logic [63: 0] dword;
	integer sel;
	a_vect[ 0 +: 8] // == a_vect[ 7 : 0]
	a_vect[15 -: 8] // == a_vect[15 : 8]
	b_vect[ 0 +: 8] // == b_vect[0 : 7]
	b_vect[15 -: 8] // == b_vect[8 :15]
	dword[8*sel +: 8] // variable part-select with fixed width
*/
/*
// Integer square root (using binary search)
unsigned int isqrt(unsigned int y)
{
	unsigned int L = 0;
	unsigned int M;
	unsigned int R = y + 1;

    while (L != R - 1)
    {
        M = (L + R) / 2;

		if (M * M <= y)
			L = M;
		else
			R = M;
	}

    return L;
}
*/
module waveform_extractor_a2 // this one does not do integer square root
	(
		mem_dout_real_i	,
		mem_dout_imag_i	,
		// m_axis_tdata_o,
		// mem_addr_o,
		gauss_output_a,
		gauss_output_b,
		gauss_output_c,
		status_flag,
		rstn,
		clk
	);
// parameter N = 16;
parameter [31:0] N_DDS = 16;
parameter [31:0] STORED_SETS = 16; // 16 values per set, must be power of 2
parameter [31:0] CLOG2_DDS_SETS = 8; 
// unlike the DAC Verilog (async reset), this follows the convention that has been set by the rest of the FPGA (sync reset)
// section 0: I/O
input										rstn;
input										clk;
input 		[N_DDS*16-1:0]					mem_dout_real_i;
input 		[N_DDS*16-1:0]					mem_dout_imag_i;
output		[31:0]							gauss_output_a;
output		[31:0]							gauss_output_b;
output		[31:0]							gauss_output_c;
output		[7:0]							status_flag;
// section 1
reg signed	[15:0]							last_real[0:N_DDS-1];
reg signed	[15:0]							last_imag[0:N_DDS-1];
reg signed	[31:0]							last_abr2[0:N_DDS-1];
reg signed	[31:0]							last_abi2[0:N_DDS-1];
// section 2
reg signed	[31:0]							stored_values[0:N_DDS*STORED_SETS-1];		// structured as 2D array, with index 0 to N_DDS - 1 being the most recent page
wire signed	[31:0]							stored_values_la[0:N_DDS*STORED_SETS-1];	// actually will be used in section 4
// section 3
reg signed	[31:0]							cmp_values[0:N_DDS*STORED_SETS-1];
wire signed	[31:0]							cmp_value_last;
reg											refresh;
// section 4
//wire		[N_DDS*STORED_SETS-1:0]	argmax_equal;
wire signed	[31:0]							cmp_future_;
reg signed	[31:0]							cmp_present;
wire		[N_DDS*STORED_SETS-1:0]			is_meq_to_halfmax;
reg			[CLOG2_DDS_SETS:0]				halfmax_accum[0:N_DDS*STORED_SETS-1];
wire		[CLOG2_DDS_SETS:0]				zero_to_half_tally;
wire		[CLOG2_DDS_SETS:0]				rise_to_fall_tally;
reg			[CLOG2_DDS_SETS:0]				zero_to_half;
reg			[CLOG2_DDS_SETS:0]				rise_to_fall;
// section 5: controls
reg											bc_ready;
//reg											a_ready;
//reg											a_calc;
//reg 		[31:0]							sqrt_L;
//reg 		[31:0]							sqrt_R;
//reg 		[31:0]							sqrt_M;
//wire 		[31:0]							sqrt_M_wire;
//wire 		[63:0]							sqrt_M_squared_plus_1;
//reg 		[63:0]							sqrt_M_squared_plus_1;
//wire 		[63:0]							sqrt_R_squared;
//reg 		[63:0]							sqrt_R_squared;
//wire 										sqrt_M_squared_plus_1_more_than_max;
//wire 										stability_LMR;
reg 		[31:0]							gauss_a2;
reg 		[31:0]							gauss_b;
reg 		[31:0]							gauss_c;
//reg											LMR_clock;
wire 		[47:0]							gauss_c_wireholder;
// section 6: debug
reg											last_cmp_reg_not_zero; // cmp_values[N_DDS*STORED_SETS - 1]
reg											half_max_reg_not_zero; // halfmax_accum[N_DDS*STORED_SETS/2 - 2]
reg											cmp_value_last_match_; // cmp_value_last
reg											cmp_future_match_last; // cmp_future_
reg 		[3:0]							past_checks;
// 	THE GOAL: extract a, b, c of y = a * math.exp(-(x - b)^2 / (2c^2))
//	a is maximum height
//	b is delay offset
//	c is pulse span

// section 1 "assignment" - long form
generate 
genvar i_a;
	for (i_a=0; i_a<N_DDS; i_a=i_a+1) begin : section_1
		always @(posedge clk) begin
			if (~rstn) begin
				last_abr2[i_a]						<=	0;
				last_real[i_a]						<=	0;
				last_imag[i_a]						<=	0;
				last_abi2[i_a]						<=	0;
			end
			else begin
				last_real[i_a]						<=	mem_dout_real_i		[i_a*16 +: 16];
				last_imag[i_a]						<=	mem_dout_imag_i		[i_a*16 +: 16];
				last_abr2[i_a]						<=	last_real[i_a] * last_real[i_a];
				last_abi2[i_a]						<=	last_imag[i_a] * last_imag[i_a];
				// yes it says signed, therefore we expect last_ab#2[i]'s MSB to be 0
			end
		end
	end
endgenerate
// section 2 "assignment" - short form
generate
genvar i_b, j_b;
	for (i_b=0; i_b<STORED_SETS; i_b=i_b+1) begin : section_2_0
		for (j_b=0; j_b<N_DDS; j_b=j_b+1) begin : section_2_1
			if (i_b==0) begin
				always @(posedge clk) begin
					stored_values[i_b*N_DDS + j_b]		<=	~rstn ? 0 : last_abr2[j_b] + last_abi2[j_b];
				end
			end
			else begin
				always @(posedge clk) begin
					stored_values[i_b*N_DDS + j_b]		<=	~rstn ? 0 : stored_values[(i_b-1)*N_DDS + j_b];
				end
			end
		end
	end
endgenerate
generate
genvar i_c;
	for (i_c=0; i_c<N_DDS*STORED_SETS; i_c=i_c+1) begin : section_2_2
		latency_reg
			#(
				.N(1 + CLOG2_DDS_SETS),
				.B(32)
			)
			stored_values_la_i
			(
				.rstn	(rstn				),
				.clk	(clk				),
				.din	(stored_values[i_c]	),
				.dout	(stored_values_la[i_c]) // takes 3 + 9 clock cycles for data to get here
			);
	end
endgenerate
// section 3 "assignment" - long form
generate
genvar i_d;
	for (i_d=0; i_d<N_DDS*STORED_SETS/2; i_d=i_d+1) begin : section_3
		always @(posedge clk) begin
			if (~rstn | refresh) begin
				cmp_values[i_d]						<=	0;
				cmp_values[N_DDS*STORED_SETS/2+i_d]	<=	0;
			end
			else begin
				cmp_values[i_d]						<=	stored_values[2 * i_d + 1] > stored_values[2 * i_d] ? stored_values[2 * i_d + 1] : stored_values[2 * i_d];
				cmp_values[N_DDS*STORED_SETS/2+i_d]	<=	cmp_values[2 * i_d + 1] > cmp_values[2 * i_d] ? cmp_values[2 * i_d + 1] : cmp_values[2 * i_d];
			end
		end
		/*
			So, I should explain:
			(1) - Comparing method
			We know stored_values is signed and non-negative (as it is a sum of squares)
			Therefore, the sign bit of (a - b), which is its MSB is 1 (negative) or 0 (non-negative)  
			Therefore the truth value of (a < b) is as simple as checking its MSB

			(2) - Comparison structure 
			There are 16 * STORED_SETS = 256 = 2^8 stored values - can be extrapolated to deeper/shallower trees
			Linear compare takes 2^8 clock cycles, which is stupid
			Therefore, tree compare: should take ceil_log2(2^8) = 8 clock cycles
			tree layer 0: each compares two values from original 2^8 values, outputs the higher value of both, has 2^7 entries
			tree layer 1: each compares two values from previous 2^7 values, outputs the higher value of both, has 2^6 entries
			...
			tree layer 7: each compares two values from previous 2^1 values, outputs the higher value of both, has 2^0 entries

			Therefore, this is how it is supposed to be structured:

			000
			001		128
			002		129		192
			003		130		193		224
			004		131		194		225		240
			005		132		195		226		241		248
			006		133		196		227		242		249		252
			007		134		197		228		243		250		253		254
			...		...		...		...		...		...		...		
			127
			
			Note that: 
				tree layer 1
				index 128+000+z		compares index 000 + 2z	+ 0 and 000 + 2z + 1 for z from 000 to 063

				tree layer 2
				index 128+064+z		compares index 128 + 2z + 0 and 128 + 2z + 1 for z from 000 to 031
									compares index 2(z + 064)+0 and 2(z + 064)+1
				index 128+000+z		compares index 000 + 2z + 0 and 000 + 2z + 1 for z from 064 to 095

				tree layer 3
				index 128+096+z		compares index 192 + 2z + 0 and 192 + 2z + 1 for z from 000 to 015
									compares index 2(z + 096)+0 and 2(z + 096)+1
				index 128+000+z		compares index 000 + 2z + 0 and 000 + 2z + 1 for z from 096 to 111

				...
				tree layer 6
				index 128+124+z		compares index 248 + 2z + 0 and 248 + 2z + 1 for z from 000 to 001
									compares index 2(z + 124)+0 and 2(z + 124)+1
				index 128+000+z		compares index 000 + 2z + 0 and 000 + 2z + 1 for z from 124 to 125
				
				tree layer 7 (final layer)
				index 128+124+z		compares index 252 + 2z + 0 and 252 + 2z + 1 for z from 000 to 000 (just z = 0)
									compares index 2(z + 126)+0 and 2(z + 126)+1
				index 128+000+z		compares index 000 + 2z + 0 and 000 + 2z + 1 for z from 126 to 126 (just z = 126)
			
			so, we can assign index 128 + z to compare index 2z and index 2z + 1 for z = 0 to 126
			However, we have z ranging from 0 to 127, so how would z = 127 looked like?
			index 128 + 127 compares index 254 and 255 (itself), then outputs the higher value
			This data persistence is normally desirable, but data needs to be flushed once calculation is complete
			Hence, the refresh register in addition to reset
			As now there are 1 + ceil_log2(2^8) = 9 layers, it will take 9 clock cycles to compare all data
		*/
	end
endgenerate
/* with N_DDS = 16 and STORED_SETS = &16&, we then take 1 + clog2(N_DDS * STORED_SETS) = ^9^, and N_DDS * STORED_SETS = #256#

After this point, in 3 + ^9^ = $12$ clock cycles, we have:
	stored_values_la[0:#256# - 1]	32 bits, #256# data with value = square of |data| inputted from $12$ to $12$ + &16& - 1 clock cycles ago
	cmp_values[#256# - 1]			32 bits, 1 data that is max(stored_values_la, self)
*/
// section 4 "assignment" - long form
generate
genvar i_e;
	for (i_e=0; i_e<N_DDS*STORED_SETS/2; i_e=i_e+1) begin : section_4_0
		// the reason to do is_meq_than_halfmax (y - max(y)/2 has a MSB of 0) instead of more (max(y)/2 - y has a MSB of 1):
		//		setting non-strict inequality means &is_more_than_halfmax is 1 if all y == max(y)/2 (i.e. y = 0)
		//		allowing zero_to_half_tally to begin from 0
		assign is_meq_to_halfmax[2*i_e] = ~(stored_values_la[2*i_e] < (cmp_values[N_DDS*STORED_SETS - 1] >>> 1));
		assign is_meq_to_halfmax[2*i_e + 1] = ~(stored_values_la[2*i_e + 1] < (cmp_values[N_DDS*STORED_SETS - 1] >>> 1));
		always @(posedge clk) begin
			if (~rstn | refresh) begin
				halfmax_accum[i_e]						<=	0;
				halfmax_accum[N_DDS*STORED_SETS/2+i_e]	<=	0;
			end
			else begin
				halfmax_accum[i_e]						<=	is_meq_to_halfmax[2*i_e] + is_meq_to_halfmax[2*i_e + 1];
				halfmax_accum[N_DDS*STORED_SETS/2+i_e]	<=	halfmax_accum[2*i_e] + halfmax_accum[2*i_e + 1];
			end
		end
	end
endgenerate
// unlike in the compare tree, we MUST take halfmax_accum[N_DDS*STORED_SETS/2 - 2] as the final result, and we will obtain this value after ^9^ - 1 clock cycles
latency_reg
	#(
		.N(1),
		.B(32)
	)
	cmp_values_la_1
	(
		.rstn	(rstn				),
		.clk	(clk				),
		.din	(cmp_values[N_DDS*STORED_SETS - 1]),
		.dout	(cmp_value_last)
	);
latency_reg
	#(
		.N(CLOG2_DDS_SETS - 2), // not a typo, I need the data ^9^ - 2 cycles later in order to "peek the future"
		.B(32)
	)
	cmp_values_la_0
	(
		.rstn	(rstn				),
		.clk	(clk				),
		.din	(cmp_value_last),
		.dout	(cmp_future_)
	);

assign rise_to_fall_tally = halfmax_accum[N_DDS*STORED_SETS/2 - 2]; 	
// starting value of rise_to_fall_tally is 256 (because max(y) = 0 means y >= max(y)/2 for all 256 values of y)
// therefore, rise_to_fall's update is safeguarded by a criteria to update only when the current maximum is not 0
assign zero_to_half_tally = {1'b0, ~halfmax_accum[N_DDS*STORED_SETS/2 - 2][CLOG2_DDS_SETS-2:0]} + 1;
always @(posedge clk) begin
	if (~rstn | refresh) begin
		zero_to_half									<=	0;
		rise_to_fall									<=	0;
		cmp_present										<=	0;
	end
	else begin
		zero_to_half									<=	~|(cmp_future_ ^ cmp_present) & (zero_to_half < zero_to_half_tally) ? zero_to_half_tally : zero_to_half;
		rise_to_fall									<=	~|(cmp_future_ ^ cmp_present) & (rise_to_fall < rise_to_fall_tally) ? rise_to_fall_tally : rise_to_fall;
		cmp_present										<=	cmp_future_;
		// both zero_to_half and rise_to_fall only changes if the tally increases while its conditions are met
		// zero_to_half only can change if the maximum value stabilizes
		// rise_to_fall 
	end
end
/*
After this point, in 3 + ^9^ + ^9^ - 1 = 20 clock cycles, we have:
	zero-to-half			^9^ - 1 bits, b - c * sqrt(2ln(2))
	rise-to-fall			^9^ - 1 bits, 2 * c * sqrt(2ln(2))
	cmp_values[#256# - 1]	32 bits, a^2
	
*/
// section 5 "assignment" - long form
always @(posedge clk) begin
	if (~rstn | refresh) begin
		bc_ready										<=	0;
		//a_ready											<=	0;
		//a_calc											<=	0;
		//LMR_clock										<=	0;
		last_cmp_reg_not_zero							<=	0;
		half_max_reg_not_zero							<=	0;
		cmp_value_last_match_							<=	0;
		cmp_future_match_last							<=	0;
	end
	else begin
		bc_ready										<=	|(cmp_present) & ~|(cmp_future_ ^ cmp_present) & ~(rise_to_fall < rise_to_fall_tally);
		//a_ready											<=	a_ready | (|(cmp_value_last) & ~|(cmp_value_last ^ cmp_values[N_DDS*STORED_SETS - 1]));
		//a_calc											<=	a_ready;
		//LMR_clock										<=	~LMR_clock;
		last_cmp_reg_not_zero							<=	|cmp_values[N_DDS*STORED_SETS - 1];
		half_max_reg_not_zero							<=	|halfmax_accum[N_DDS*STORED_SETS/2 - 2];
		cmp_value_last_match_							<=	~|(cmp_value_last ^ cmp_values[N_DDS*STORED_SETS - 1]);
		cmp_future_match_last							<=	~|(cmp_future_ ^ cmp_value_last);
	end
end
// https://en.wikipedia.org/wiki/Integer_square_root
// technically, this calculates floor(sqrt(max - 1)), because max - 1 + 1 will not overflow and max + 1 might
// to fix sqrt(4) == 1, we bitwise-nor (sqrt_R)^2 ^ 4, which returns 1 if both are equal
// at that point, it's obvious which one is the square root (sqrt_R if equal, otherwise sqrt_L)
// after update @ 2024/07/19, the squaring wires became a bottleneck
//assign sqrt_M_squared_plus_1 = sqrt_M * sqrt_M + 1;
// assign sqrt_M_squared_plus_1_more_than_max = |sqrt_M_squared_plus_1[63:32] | (cmp_value_last < sqrt_M_squared_plus_1[31:0]);
// //assign sqrt_R_squared = sqrt_R * sqrt_R;
// assign sqrt_M_wire = (sqrt_L + sqrt_R) >>> 1;
// always @(posedge clk) begin
// 	if (~rstn | refresh | ~a_ready) begin
// 		sqrt_L											<=	0;
// 		sqrt_R											<=	0;
// 		sqrt_M											<=	0;
// 		sqrt_M_squared_plus_1							<=	0;
// 		sqrt_R_squared									<=	0;
// 	end
// 	else if (LMR_clock) begin
// 		// LMR_clock == 1: update (sqrt(M))^2 +1 and (sqrt(R))^2
// 		sqrt_L											<=	sqrt_L;
// 		sqrt_R											<=	sqrt_R;
// 		sqrt_M											<=	sqrt_M;
// 		sqrt_M_squared_plus_1							<=	sqrt_M * sqrt_M + 1;
// 		sqrt_R_squared									<=	sqrt_R * sqrt_R;
// 	end
// 	else begin
// 		// LMR_clock == 0:  update LMR
// 		sqrt_L											<=	a_calc ? (sqrt_M_squared_plus_1_more_than_max ? sqrt_L : sqrt_M) : 0;
// 		sqrt_R											<=	a_calc ? (sqrt_M_squared_plus_1_more_than_max ? sqrt_M : sqrt_R) : cmp_value_last;
// 		sqrt_M											<=	sqrt_M_wire; // note, sqrt_M is lagging by 1 clock compared to sqrt_L and sqrt_R
// 		sqrt_M_squared_plus_1							<=	sqrt_M_squared_plus_1;
// 		sqrt_R_squared									<=	sqrt_R_squared;
// 	end
// end
assign gauss_c_wireholder = {rise_to_fall >>> 1, 16'd0} - 16'd9875 * (rise_to_fall >>> 1); // approximation to rise_to_fall/(2*sqrt(2ln2))
//assign stability_LMR = ~|(sqrt_M_wire ^ sqrt_L); // it will take 2 * $clog2(max - 1) clock cycles after a_ready for this to return 1
always @(posedge clk) begin
	if (~rstn) begin
		gauss_a2										<=	0;
		gauss_b											<=	0;
		gauss_c											<=	0;
		refresh											<=	0;
		past_checks										<=	0;
	end
	else begin
		gauss_a2										<=	bc_ready ? cmp_values[N_DDS*STORED_SETS-1] : gauss_a2;
		gauss_b											<=	bc_ready ? zero_to_half + (rise_to_fall >>> 1) : gauss_b;
		gauss_c											<=	bc_ready ? gauss_c_wireholder[47:16] : gauss_c;
		refresh											<=	|gauss_c & bc_ready;
		past_checks										<=	refresh ? {last_cmp_reg_not_zero, half_max_reg_not_zero, cmp_value_last_match_, cmp_future_match_last} : past_checks;
	end
end
assign gauss_output_a = gauss_a2;
assign gauss_output_b = gauss_b;
assign gauss_output_c = gauss_c;
assign status_flag = {past_checks, last_cmp_reg_not_zero, half_max_reg_not_zero, cmp_value_last_match_, cmp_future_match_last};
endmodule