

/**
 * Instruction Fetch Stage
 *
 * Instruction fetch unit: Selection of the next PC (PC+4/ALU), and buffering (sampling) of
 * the read instruction.
 */
 
module if_stage #(parameter DEPTH=32, parameter LINEWIDTH=64, parameter WIDTH = 32,
		parameter DEPTHMSB = $clog2(DEPTH)-1) 
		(
		
		input  logic                   clk_i,
		input  logic                   rst_ni,
		input  logic [31:0]            rst_addr_i,

		// control
		//output logic [31:0]            inst_c,
		input  logic [31:0]            boot_addr_i,              // also used for mtvec(Machine Trap Vector, holds the address the processor jumps to when an exception occurs.)
		input  logic                   req_i,                    // instruction request control
		input  logic       			   branch_i,
		input  logic 				   flush,                    //flush instruction buffer
		input  logic 				   stall,                    //pipeline stall

		//input  logic                   pc_set_i,                 // set the PC to a new value
		//input  logic [1:0]             pc_mux_i,                 // selector for PC multiplexer

		// IF to instruction memory interface
		input logic [LINEWIDTH-1:0]    line_in,                  //instruction in
		input logic                    line_ready,               //memory system is ready for next inst fetch request
		input logic                    line_valid,               //instruction input to buffer enable
		//input logic                    imembusy_i,
		
		output logic                   ld_line,    //prefetch a line (split transaction)
		output logic                   read_finish_o, 
		
		output logic                   inst_req_o,	//valid im request
		output logic [31:0]            inst_addr_o,	// pc
		//output logic [31:0]            instmem_addr_o, //line fetch address, based on pc

		// IF to EX interface
		//output logic [31:0]      	  operand_a_o,
		//output logic [31:0]         operand_b_o,
		//output logic [DEPTHMSB:0]           wd_addr_o,
		//output logic                  we_o,
		//output logic [31:0]           rs2,
		output logic [31:0]           inst_o,     //instr if2idex
		output logic                  inst_valid_o,

		input  logic [31:0]           inst_addr_flush_i,
		//input  logic [31:0]           alu_result,

		//input  logic                  we_i,      //write enable, last cycle
		//input  logic [DEPTHMSB:0]     wa_i,      //write address, last cycle
		//input  logic [WIDTH-1:0]      wd_i,	   //write re data, last cycle

		//csr->if->imaccess
		input  logic                 sys_call_en_i, //ecall
        input  logic                 excep_en_i,
		input  logic                 mret_en_i, //mret
		//input  logic [31:0]          csr_mtvec_i,
		//input  logic [31:0]          csr_mepc_i
		
        output logic [31:0]          mepc_before_flush_o

		);
	
	
	// im_access to buffer interface
	logic                   ld_line_b2im;     //prefetch a line (split transaction)
	//a block of inst mem contains 2 to 4(rvc) instructions, it works smoothly in sequential way,
	//but when flush come, the next instruction may be the 2nd,3rd,4th one in the mem block
	logic [1:0]             order_when_flush_nextcnt; //00 for the 1st in the block, 01 for the 2nd one. 10, 11 for 3rd, 4th
	logic [1:0]             order_when_flush_rdptr; //00 for the 1st in the block, 01 for the 2nd one. 10, 11 for 3rd, 4th
    
	// buffer to fetch interface
	//logic                   inst_re_f2p; //inst buff read enable
	//logic [31:0] 			inst_p2f;
	logic        			inst_valid_p2f;
	logic                   is_rvc;
	
	assign ld_line          = ld_line_b2im;
	assign is_rvc = is_inst_rvc(inst_o[1:0]);
	im_access im_access0 (
			.clk               ( clk_i                       ),
			.rst               ( rst_ni                      ),
			.rst_addr_i        ( rst_addr_i                  ),
			// control signal
			.flush             ( flush                       ),               //flush instruction buffer
			.stall             ( stall                       ), 
			//.sys_call_en_i     ( sys_call_en_i               ), //ecall
            //.excep_en_i        ( excep_en_i                  ),
			//.mret_en_i         ( mret_en_i                   ), //mret
			//			.line_ready      ( line_ready_im2b             ),			    //memory system is ready
			//			.line_valid      ( line_valid_im2b             ),			    //instruction input to buffer enable
			//.imembusy_i      ( imembusy_i                  ),
			
			.ld_line    	   ( ld_line_b2im                ),				 //prefetch a line (split transaction)
			//.inst_re         ( inst_re_f2p                 ),
			//.alu_result      ( alu_result                  ),
			//.mtvec_i         ( csr_mtvec_i                 ),
			//.mepc_i          ( csr_mepc_i                  ),
            .inst_addr_flush_i ( inst_addr_flush_i         ),

			.inst_valid_i      ( inst_valid_p2f              ),
			.is_rvc_i          ( is_rvc                      ), 
			//			.branch_i        ( branch_i                    ),
			.inst_req_o        ( inst_req_o                  ),
			.inst_addr_o       ( inst_addr_o                 ),    //pc
            .pc_prev_o         ( mepc_before_flush_o         )
			//.instmem_addr_o  ( instmem_addr_o              )
		);
	
	assign order_when_flush_nextcnt = inst_addr_o[2:1];
	assign order_when_flush_rdptr   = inst_addr_flush_i[2:1];
	assign inst_valid_o = inst_valid_p2f;
	inst_buffer inst_buffer_i (
			.clk                      ( clk_i                       ),
			.rst                      ( rst_ni                      ),
			.flush                    ( flush                       ),               //flush instruction buffer
			.order_when_flush_nextcnt ( order_when_flush_nextcnt    ),
			.order_when_flush_rdptr   ( order_when_flush_rdptr      ),
			.stall                    ( stall                       ),               //pipeline stall
			.line_in                  ( line_in                     ),			     //instruction in
			.line_ready               ( line_ready                  ),			     //memory system is ready
			.line_valid               ( line_valid                  ),			     //instruction input to buffer enable
			.ld_line    	          ( ld_line_b2im                ),				 //prefetch a line (split transaction)
			.read_finish_o            ( read_finish_o               ),
			
			//fetch interface
			//.inst_re         ( inst_re_f2p                 ),	//inst buff read enable
			.inst_out                 ( inst_o                      ),
			.inst_valid               ( inst_valid_p2f              )
			
		);
      /*          
	fetch fetch_i (
			//.clk             ( clk_i                       ),
			.rst             ( rst_ni                      ),
			//instruction buffer interface
			.inst_re         ( inst_re_f2p                 ),
			//.inst_in         ( inst_p2f                    ),
			.inst_valid      ( inst_valid_p2f              ),
        
			//regfile interface
			//.ra              ( ra_f2r                      ),
			//.re              ( re_f2r                      ),
        
			//control
			.stall           ( stall                       ),
			.flush           ( flush                       )
			//.ASel            ( ASel                        ),
			//.BSel            ( BSel                        ),
			
			//if2ex interface
			//.we              ( we_o                        ),
			//.wd_addr         ( wd_addr_o                   )
		);
	*/
	/*iregfile ir (
			.clk             ( clk_i                        ),
			.re              ( re_f2r                       ),	//read enable
			.ra              ( ra_f2r                       ),	//read address
			.rs              ( rs_o                         ),	//rs1, rs2
			.we              ( we_i                         ),                 	//write enable
			.wa              ( wa_i                         ), //write address
			.wd              ( wd_i                         )
			);*/
	/*	always_comb begin
		inst_c = inst_o;
		instr = inst_p2f;
	
		if(ASel == 0)
			operand_a_o = rs_o[0];	      //operand_a_o = rs1
		else if(ASel == 1)
			operand_a_o = inst_addr_o;   //operand_a_o = pc
		
		if(BSel == 0)
			operand_b_o = rs_o[1];	      //operand_b_o = rs2
		else if(BSel == 1)
			operand_b_o = rs_o[1];  //TODO add imm //operand_b_o = imm
	end*/
endmodule