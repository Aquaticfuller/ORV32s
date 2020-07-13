//`timescale 1ns/1ps

module testbench
		#(
		parameter DEPTH     = 32, 
		parameter LINEWIDTH = 64, 
		parameter LINEHIGHT = 65536 + 4096,//2048,
		parameter WIDTH     = 32,
		parameter BlockNumLog2  = $clog2(LINEHIGHT)
		) (
		//verifying port
		output logic          [31:0]      dff_ireg_ver[0:31],
		output logic          [31:0]      pc_stage2_ver,
		output logic          [31:0]      inst_ver,
		
		output logic          [63:0]      dff_csr_mcycle_ver,
		output logic          [63:0]      dff_csr_minstret_ver,
		
		input  logic [LINEWIDTH-1:0]      inst_mem_i [0:LINEHIGHT-1],
		input  logic [31:0]               data_mem_i [0:4096-1],//
		output logic [31:0]               data_mem_o [0:4096-1],//
		input  logic [31:0]               mhartid_i,
		output logic [31:0]               mhartid_o,

		output logic                      readMiss_o,
		output logic                      writeMiss_o,
		output logic                      readHit_o,
		output logic                      writeHit_o,
		output logic [31:0]               data_addr_o,

		input  logic [255:0]              cacheLine_i [0:1024-1],
	    output logic [16:0]               cacheLineTag_o[0:1024-1],   // Tag 17bits, Index 10 bits, Offset 5 bits
	    output logic [1:0]                cacheLineValid_o[0:1024-1], // Valid bits, 00:Invalid, 01:Shared. 11:Modified
		
		output logic [255:0]              cacheLine_o [0:1024-1],
	    input  logic [16:0]               cacheLineTag_i[0:1024-1],   // Tag 17bits, Index 10 bits, Offset 5 bits
	    input  logic [1:0]                cacheLineValid_i[0:1024-1], // Valid bits, 00:Invalid, 01:Shared. 11:Modified
		
		output logic [31:0]               store_data_o,
		//output logic [3:0]                write_en_o,

		output logic [16:0]               reqTag_o,
		output logic [9:0]                reqIndex_o,



		//input  logic                      stall_i,


		//////////////////////////////////////////////
		input logic        clk,
		input logic        rst,
		input logic [31:0] rst_addr_i
		);

	// LSU to data ram interface
	logic [31:0]             data_addr_t2dr;
	logic [31:0]             store_data_t2dr; 
	logic [31:0]             load_data_dr2t;
	logic                    MemR_en_t2dr; 
	logic                    MemW_en_t2dr;
	logic [3:0]              byte_enable_t2dr;
	
	logic                    read_valid_dr2t;
	logic                    write_ready_dr2t;
	// IF to inst rom interface
	logic                    flush;

	logic [63:0]             line_in_ir2t;    //instruction in
	logic                    line_ready_ir2t; //memory system is ready
	logic                    line_valid_ir2t; //instruction   to buffer enable

	logic                    ld_line_t2ir;    //prefetch a line (split transaction)
	logic                    read_finish_t2ir;

	logic                    inst_req_t2ir;	//valid im request
	logic [31:0]             inst_addr_flush_t2ir;
	
	//logic [31:0]             inst_debug;
	//assign inst_debug = $root.orv32s_top0.inst_f2e_stage2;
	//assign inst_debug = $unit::top.orv32s_top0.inst_f2e_stage2;

	assign dff_ireg_ver[1:31]             = orv32s_top0.EX.ir.dff_ireg;
	assign dff_ireg_ver[0]                = '0;
	assign pc_stage2_ver                  = orv32s_top0.pc_f2e_stage2;
	assign inst_ver                       = orv32s_top0.inst_f2e_stage2;

	assign dff_csr_mcycle_ver             = orv32s_top0.csr0.mct[0][63:0];
	assign dff_csr_minstret_ver           = orv32s_top0.csr0.mct[1][63:0];
	assign orv32s_top0.csr0.mhartid       = mhartid_i;
	assign mhartid_o                      = orv32s_top0.csr0.mhartid;

	assign readHit_o                      = read_valid_dr2t;
	assign writeHit_o                     = write_ready_dr2t;
	assign data_addr_o                    = data_addr_t2dr;

    assign Dcache.cacheLine               = cacheLine_i;
	assign cacheLineTag_o                 = Dcache.cacheLineTag;
	assign cacheLineValid_o               = Dcache.cacheLineValid;

	assign cacheLine_o                    = Dcache.cacheLine;
	assign Dcache.cacheLineTag            = cacheLineTag_i;
	assign Dcache.cacheLineValid          = cacheLineValid_i;
    
   // assign store_data_o                   = Dcache.store_data_i;
   // assign write_en_o                     = Dcache.write_en;

	assign reqTag_o                       = Dcache.reqTag;
	assign reqIndex_o                     = Dcache.reqIndex;

	logic [31:0] store_data_raw;
	assign store_data_raw      = Dcache.cacheLine[Dcache.reqIndex] [Dcache.reqAddrInLine  +: 32];
	assign store_data_o[7:0]   = Dcache.write_en[0] ? Dcache.store_data_i[7:0]   : store_data_raw[7:0];
	assign store_data_o[15:8]  = Dcache.write_en[1] ? Dcache.store_data_i[15:8]  : store_data_raw[15:8];
	assign store_data_o[23:16] = Dcache.write_en[2] ? Dcache.store_data_i[23:16] : store_data_raw[23:16];
	assign store_data_o[31:24] = Dcache.write_en[3] ? Dcache.store_data_i[31:24] : store_data_raw[31:24];



	//assign orv32s_top0.control_unit.stall = stall_i;

	orv32s_top orv32s_top0
		(
			.clk                    ( clk                    ), 
			.rst                    ( rst                    ),
			.rst_addr_i             ( rst_addr_i             ),
			// LSU to data ram interface
			.data_addr_o            ( data_addr_t2dr         ), 
			.data_o                 ( store_data_t2dr        ),
			.line_in_d              ( load_data_dr2t         ), 
			.MemR_o                 ( MemR_en_t2dr           ), 
			.MemW_o                 ( MemW_en_t2dr           ),
			.byte_enable_o          ( byte_enable_t2dr       ),
			
			.read_valid_i           ( read_valid_dr2t        ),  //together with load data
			.write_ready_i          ( write_ready_dr2t       ), //ready to receive store data if set
			// IF to inst rom interface
			.flush_o                ( flush                  ),
		
			.line_in_im2i           ( line_in_ir2t           ),    //instruction in
			.line_ready_im2i        ( line_ready_ir2t        ), //memory system is ready
			.line_valid_im2i        ( line_valid_ir2t        ), //instruction   to buffer enable

			.ld_line_i2im           ( ld_line_t2ir           ),    //prefetch a line (split transaction)
			.read_finish_i2im       ( read_finish_t2ir       ),
	
			.inst_req_i2im          ( inst_req_t2ir          ),	//valid im request
			.inst_addr_flush_i2im   ( inst_addr_flush_t2ir   )
		);
	/*
	logic [31:0]               data_mem [0:2048-1];
	always_comb  begin
		for (int i=1536;i<1536+18;i++) begin//1536==0x600, accord to data address starts from 0x3000
			data_mem[i*2  ] = inst_mem_i[i][31:0];
			data_mem[i*2+1] = inst_mem_i[i][63:32];
		end
		for (int i=1027;i<1027+18;i++) begin//1027==0x403, accord to data address starts from 0x2018 in rvc
			data_mem[i*2  ] = inst_mem_i[i][31:0];
			data_mem[i*2+1] = inst_mem_i[i][63:32];
		end
	end 
*/
	
	
	
	data_cache Dcache(
			.clk                    ( clk                    ),
			.rst                    ( rst                    ),
			.data_addr_i            ( data_addr_t2dr         ), 
			.store_data_i           ( store_data_t2dr        ),
			.load_data_o            ( load_data_dr2t         ),
			.MemR_en_i              ( MemR_en_t2dr           ),
			.MemW_en_i              ( MemW_en_t2dr           ),
			.byte_enable_i          ( byte_enable_t2dr       ),
			.read_valid_o           ( read_valid_dr2t        ),  //together with load data
			.write_ready_o          ( write_ready_dr2t       ), //ready to receive store data if set
			.readMiss_o             ( readMiss_o             ),    // read miss
		    .writeMiss_o            ( writeMiss_o            ),   // write miss
			/////////////////////////////////////
			.data_mem_i             ( data_mem_i             )		
		);
	
	inst_rom inst_rom
		(
			.clk                           ( clk                 ),
			.rst                           ( rst                 ),
			.rst_addr_i                    ( rst_addr_i          ),
			.flush                         ( flush               ),
			.ld_line_i                     ( ld_line_t2ir        ),
			.read_finish_i                 ( read_finish_t2ir    ),//buff has finish reading
			.inst_req_i                    ( inst_req_t2ir       ),
			.inst_addr_flush_i             ( inst_addr_flush_t2ir),// pc
			//.instmem_addr_i 	           ( instmem_addr_t2ir   ), 
		
			.line_out                      ( line_in_ir2t        ),    //instruction in
			.line_ready                    ( line_ready_ir2t     ), //memory system is ready for next fetch
			.line_valid                    ( line_valid_ir2t     ),//instruction input to buffer enable
			//.busy                          ( busy_ir2t           )
			/////////////////////////////////////
			.inst_mem_i                    ( inst_mem_i          )
		);
			
	
	
endmodule