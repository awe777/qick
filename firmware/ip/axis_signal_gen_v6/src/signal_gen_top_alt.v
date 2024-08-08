module signal_gen_top_alt
	(
		// Reset and clock.
    	aresetn				,
		aclk				,

    	// AXIS Slave to load memory samples.
    	s0_axis_aresetn	    ,
		s0_axis_aclk		,
		s0_axis_tdata_i		,
		s0_axis_tvalid_i	,
		s0_axis_tready_o	,

    	// AXIS Slave to queue waveforms.
		s1_axis_tdata_i		,
		s1_axis_tvalid_i	,
		s1_axis_tready_o	,

		// M_AXIS for output.
		m_axis_tready_i		,
		m_axis_tvalid_o		,
		m_axis_tdata_o		,

		// Registers.
		START_ADDR_REG		,
		WE_REG,
		gauss_a,
		gauss_b,
		gauss_c,
		gauss_4,
		gauss_3,
		gauss_2,
		gauss_1,
		gauss_0,
		data_addr_read
	);

/**************/
/* Parameters */
/**************/
// Memory address size.
parameter N = 16;

// Number of parallel dds blocks.
parameter [31:0] N_DDS = 16;

/*********/
/* Ports */
/*********/
input					aresetn;
input					aclk;

input					s0_axis_aresetn;
input					s0_axis_aclk;
input 	[31:0]			s0_axis_tdata_i;
input					s0_axis_tvalid_i;
output					s0_axis_tready_o;

input 	[159:0]			s1_axis_tdata_i;
input					s1_axis_tvalid_i;
output					s1_axis_tready_o;

input					m_axis_tready_i;
output					m_axis_tvalid_o;
output	[N_DDS*16-1:0]	m_axis_tdata_o;
output	[31:0]			gauss_a;
output	[31:0]			gauss_b;
output	[31:0]			gauss_c;
output	[31:0]			gauss_4;
output	[31:0]			gauss_3;
output	[31:0]			gauss_2;
output	[31:0]			gauss_1;
output	[31:0]			gauss_0;
input	[31:0]			data_addr_read;

input   [31:0]  		START_ADDR_REG;
input           		WE_REG;

/********************/
/* Internal signals */
/********************/
// Fifo.
wire					fifo_wr_en;
wire	[159:0]			fifo_din;
wire					fifo_rd_en;
wire	[159:0]			fifo_dout;
wire					fifo_full;
wire					fifo_empty;
wire	[7:0]			status_flag;
// Memory.
wire	[N_DDS-1:0]		mem_ena;
wire					mem_wea;
wire	[N-1:0]			mem_addra;
wire	[31:0]			mem_dia;
wire	[N-1:0]			mem_addrb;
wire	[N_DDS*16-1:0]	mem_dob_real;
wire	[N_DDS*16-1:0]	mem_dob_imag;


/**********************/
/* Begin Architecture */
/**********************/

// Fifo.
fifo
    #(
        // Data width.
        .B	(160),
        
        // Fifo depth.
        .N	(16)
    )
    fifo_i
	( 
        .rstn	(aresetn	),
        .clk 	(aclk		),

        // Write I/F.
        .wr_en 	(fifo_wr_en	),
        .din    (fifo_din	),
        
        // Read I/F.
        .rd_en 	(fifo_rd_en	),
        .dout  	(fifo_dout	),
        
        // Flags.
        .full   (fifo_full	),
        .empty  (fifo_empty	)
    );

assign fifo_wr_en	= s1_axis_tvalid_i;
assign fifo_din		= s1_axis_tdata_i;

// Data writer.
data_writer
    #(
        // Number of tables.
        .NT	(N_DDS	),
        // Address map of memory.
        .N	(N		),
        // Data width.
        .B	(32		)
    )
    data_writer_i
    (
        .rstn           (s0_axis_aresetn	),
        .clk            (s0_axis_aclk       ),
        
        // AXI Stream I/F.
        .s_axis_tready	(s0_axis_tready_o	),
		.s_axis_tdata	(s0_axis_tdata_i	),
		.s_axis_tvalid	(s0_axis_tvalid_i	),
		
		// Memory I/F.
		.mem_en         (mem_ena			),
		.mem_we         (mem_wea			),
		.mem_addr       (mem_addra			),
		.mem_di         (mem_dia			),
		
		// Registers.
		.START_ADDR_REG (START_ADDR_REG		),
		.WE_REG			(WE_REG				)
    );

generate
genvar i;
	for (i=0; i<N_DDS; i=i+1) begin : GEN_mem
		/***********************/
		/* Block instantiation */
		/***********************/
		// Memory for Real Part.
		bram_dp
		    #(
		        // Memory address size.
		        .N	(N),
		        // Data width.
		        .B	(16)
		    )
		    mem_real_i
			( 
				.clka    (s0_axis_aclk				),
		        .clkb    (aclk						),
		        .ena     (mem_ena[i]				),
		        .enb     (1'b1						),
		        .wea     (mem_wea					),
		        .web     (1'b0						),
		        .addra   (mem_addra					),
		        .addrb   (mem_addrb					),
		        .dia     (mem_dia[15:0]				),
		        .dib     (16'h0000					),
		        .doa     (							),
		        .dob     (mem_dob_real[i*16 +: 16]	)
		    );

		// Memory for Imaginary Part.
		bram_dp
		    #(
		        // Memory address size.
		        .N	(N),
		        // Data width.
		        .B	(16)
		    )
		    mem_imag_i
			( 
				.clka    (s0_axis_aclk				),
		        .clkb    (aclk						),
		        .ena     (mem_ena[i]				),
		        .enb     (1'b1						),
		        .wea     (mem_wea					),
		        .web     (1'b0						),
		        .addra   (mem_addra					),
		        .addrb   (mem_addrb					),
		        .dia     (mem_dia[31:16]			),
		        .dib     (16'h0000					),
		        .doa     (							),
		        .dob     (mem_dob_imag[i*16 +: 16]	)
		    );

		/*************/
		/* Registers */
		/*************/

		/*****************************/
		/* Combinatorial assignments */
		/*****************************/
	end
endgenerate

// Signal gen. 
signal_gen 
	#(
		.N		(N		),
		.N_DDS	(N_DDS	)
	)
	signal_gen_i
	(
		// Reset and clock.
		.rstn				(aresetn			),
		.clk				(aclk				),

		// Fifo interface.
		.fifo_rd_en_o		(fifo_rd_en			),
		.fifo_empty_i		(fifo_empty			),
		.fifo_dout_i		(fifo_dout			),

		// Memory interface.
		.mem_addr_o			(mem_addrb			),
		.mem_dout_real_i	(mem_dob_real		),
		.mem_dout_imag_i	(mem_dob_imag		),

		// M_AXIS for output.
		.m_axis_tready_i	(m_axis_tready_i	),
		.m_axis_tvalid_o	(m_axis_tvalid_o	),
		.m_axis_tdata_o		(m_axis_tdata_o		)
	);
// waveform_extractor_a2 
// 	#(
// 		.N_DDS	(N_DDS	),
// 		.STORED_SETS	(16),
// 		.CLOG2_DDS_SETS	(8)
// 	)
// 	waveform_extractor_i
// 	(
// 		// Fifo interface.

// 		// Memory interface.
// 		.mem_dout_real_i	(mem_dob_real		),
// 		.mem_dout_imag_i	(mem_dob_imag		),

// 		// M_AXIS for output.
// 		.gauss_output_a		(gauss_a			),
// 		.gauss_output_b		(gauss_b			),
// 		.gauss_output_c		(gauss_c			),
// 		.status_flag		(status_flag		),
// 		// Reset and clock.
// 		.rstn				(aresetn			),
// 		.clk				(aclk				)
// 	);

waveform_analyzer
	#(
		.N_DDS	(N_DDS	),
		.STORED_SETS	(16)
	)
	waveform_analyzer_i
	(
		.mem_dout_real_i	(mem_dob_real		),
		.mem_dout_imag_i	(mem_dob_imag		),
		.gauss_output_a		(gauss_a			),
		.gauss_output_b		(gauss_b			),
		.gauss_output_c		(gauss_c			),
		.status_flag		(status_flag		),
		.data_addr_read		(data_addr_read		),
		.rstn				(aresetn			),
		.clk				(aclk				)
	);

// Assign outputs.
assign s1_axis_tready_o	= ~fifo_full;
//Format of waveform interface:
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// | 159 .. 149 |   148 |     147 |  146 | 145 .. 144 | 143 .. 128 | 127 .. 112 | 111 .. 96 | 95 .. 80 | 79 .. 64 | 63 .. 32 | 31 .. 0 |
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// |       xxxx | phrst | stdysel | mode |     outsel |      nsamp |       xxxx |      gain |     xxxx |     addr |    phase |    freq |
// |------------|-------|---------|------|------------|------------|------------|-----------|----------|----------|----------|---------|
// since there are unused waveform interface, might as well use funny words as placeholder + proof of working memory assignment
assign gauss_4 = {status_flag, fifo_dout[151:128]};
assign gauss_3 = {16'hdead, fifo_dout[111:96]};
assign gauss_2 = {16'hbeef, fifo_dout[79:64]};
assign gauss_1 = fifo_dout[63:32];
assign gauss_0 = fifo_dout[31:0];

endmodule

