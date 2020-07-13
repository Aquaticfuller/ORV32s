/*
Copyright (c) 2019, RiVAI Techologies(Shenzhen) Co., Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

 * Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

File:        orv32s_top.sv
Author:      Zhangxi Tan
Description: pipeline data structures

 */
import libcsr::*;
module orv32s_top#(parameter DEPTH=32, parameter LINEWIDTH=64, parameter WIDTH = 32,
		parameter DEPTHMSB = $clog2(DEPTH)-1)
		(

		input   logic                    clk, 
		input   logic                    rst,
		input   logic [31:0]             rst_addr_i,
		// LSU to data ram interface
		output  logic [31:0]             data_addr_o, 
		output  logic [31:0]             data_o, 
		input   logic [31:0]             line_in_d, 
		output  logic                    MemR_o, 
		output  logic                    MemW_o,
		output  logic [3:0]              byte_enable_o,

		input   logic                    read_valid_i,  //together with load data
		input   logic                    write_ready_i, //ready to receive store data if set
		// IF to inst rom interface
		output  logic                   flush_o,
		
		input   logic [LINEWIDTH-1:0]   line_in_im2i,    //instruction in
	    input   logic                   line_ready_im2i, //memory system is ready
        input   logic                   line_valid_im2i, //instruction   to buffer enable

        output  logic                   ld_line_i2im,    //prefetch a line (split transaction)
        output  logic                   read_finish_i2im,
	
        output  logic                   inst_req_i2im,	//valid im request
		output  logic [31:0]            inst_addr_flush_i2im
		
		//inst rom interface
//		output  logic                   flush,
//		output  logic                   ld_line_i,
//		output  logic                   read_finish_i,
//		output  logic                   inst_req_i,
//		output  logic [31:0]            inst_addr_flush_i,	// alu
//		
//		input   logic [LINEWIDTH-1:0]   line_out,    //instruction in
//		input   logic                   line_ready, //memory system is ready for next fetch
//		input   logic                   line_valid  //instruction input to buffer enable
		
		
		);
	logic          [WIDTH-1:0]      dff_ireg_ver[0:31];
	//instruction buffer
	//inst_buffer inst_buf_i();
	
	//logic [31:0]            instr;
	
	// control to if
	logic [31:0]            boot_addr;              // also used for mtvec(Machine Trap Vector, holds the address the processor jumps to when an exception occurs.)
	logic                   req;                    // instruction request control
	logic       			branch;
	logic 				    flush;                         //flush instruction buffer
	logic 				    stall;                         //pipeline stall
	assign  flush_o = flush;

	//logic                  pc_set;                 // set the PC to a new value
	//logic [1:0]            pc_mux_c2f;
	
	//control to ex
	logic [4:0]           aluSel_c2e; //alu mode choose
	logic [1:0]           ASel_c2e;
	logic [1:0]           BSel_c2e;
	logic                 MemR_c2lsu;  //mem read enable
	logic                 MemW_c2lsu;   //mem write enable
	logic [1:0]           load_length_c2e;   //L8,L16,L32
	logic                 load_signed_c2e;   //0: unsigned ext,1: sext
		
	logic                 is_rvc_e2c;
	logic [1:0]           rs1_rs2_eqz_e2c;
	logic [1:0]           rs1_rs2_eqz_u_e2c;
	logic                 reg_write_back_en_c2e;
	//logic                 miss_aligned_stall_c2lsu;
	logic [2:0]           data_to_regfile_c2e;
	logic                 multdiv_finish_e2c;
	logic                 div_sub_e2c;
	logic                 mulit_en_c2e;
	logic                 div_en_c2e;
	//logic [1:0]           rs1_rs2_eqz_u_e2c;
	//assign rs1_rs2_eqz_e2c = alu_result_e2f[1:0];
	
	//c2csr
	logic                 sys_call_en_c2csr;
    logic                 excep_en_c2csr;
	logic                 mret_en_c2csr;
	libcsr::csr_op_e      csr_op_c2csr;
	control control_unit (
			.rst                           ( rst                   ),
			.inst_in                       ( inst_f2e_stage2       ),
			.inst_valid                    ( inst_valid_f2e_stage2 ),
			// control to if
			.stall_last                    ( stall_f2c_stage2      ),
			.flush_last                    ( flush_f2c_stage2      ),
            //.flush_last_last               ( prev_flush2           ),
			.boot_addr_i                   ( boot_addr             ),  // also used for mtvec(Machine Trap Vector, holds the address the processor jumps to when an exception occurs.)
			.req_i                         ( req                   ),  // instruction request control
			.branch_i                      ( branch                ),
			.flush                         ( flush                 ),  //flush instruction buffer
			.stall                         ( stall                 ),  //pipeline stall

			//.pc_set_o                      ( pc_set                ),  // set the PC to a new value
			//.pc_mux_o                      ( pc_mux_c2f            ),  // selector for PC multiplexer
 		
			//control to ex
			
			.aluSel_o                      ( aluSel_c2e            ),  //alu mode choose
			.ASel_o                        ( ASel_c2e              ),
			.BSel_o                        ( BSel_c2e              ),
			.is_rvc_i                      ( is_rvc_e2c            ),
            .illegal_inst_i                ( illegal_inst_e2c      ),

			.rs1_rs2_eqz_i                 ( rs1_rs2_eqz_e2c       ),
			.rs1_rs2_eqz_u_i               ( rs1_rs2_eqz_u_e2c     ),
			.reg_write_back_en_o           ( reg_write_back_en_c2e ),
			
			
			.load_finish_i                 ( load_finish_lsu2c       ),
			.store_finish_i                ( store_finish_lsu2c      ),
			.MemR_o                        ( MemR_c2lsu              ),  //mem read enable
			.MemW_o                        ( MemW_c2lsu              ),   //mem write enable
			.load_length_o                 ( load_length_c2e       ),   //L8,L16,L32
			.load_signed_o                 ( load_signed_c2e       ),   //0: unsigned ext,1: sext
			//.miss_aligned_stall_o          ( miss_aligned_stall_c2lsu),
			.data_to_regfile_o             ( data_to_regfile_c2e   ),
			//control->ex->multiplier
			.multdiv_finish_i              ( multdiv_finish_e2c     ),
			.div_sub_i                     ( div_sub_e2c            ),
			.mulit_en_o                    ( mulit_en_c2e           ),
			.div_en_o                      ( div_en_c2e             ),
			
			//control->csr
			.sys_call_en_o                 ( sys_call_en_c2csr      ),
            .excep_en_o                    ( excep_en_c2csr         ),
			.mret_en_o                     ( mret_en_c2csr          ),
			.csr_op_o                      ( csr_op_c2csr           )
		);
	
	//csr->ex->regfile
	logic [31:0] csr_rdata_csr2r;
	//csr->if->imaccess
	logic [31:0] csr_mtvec_csr2i;
	logic [31:0] csr_mepc_csr2i;
	logic [31:0] csr_wdata_tmp;
	
	//csrrxi //csrrx
	assign csr_wdata_tmp = inst_f2e_stage2[14] ? imm_e2csr : rs1_e2csr;
	
	logic  inst_zero_en;
	assign inst_zero_en = (inst_f2e_stage2 == 32'b0);

    logic [1:0]  priv_lvl_csr2e;

	cs_registers csr0 (
			.clk                           ( clk                    ),
			.rst                           ( rst                    ),
			.stall_i                       ( stall_f2c_stage1       ),
			.flush_i                       ( flush_f2c_stage1       ),
			
			.sys_call_en_i                 ( sys_call_en_c2csr      ),
            .excep_en_i                    ( excep_en_c2csr         ),
			.mret_en_i                     ( mret_en_c2csr          ),
			
			.pc_idex_i                     ( mepc_if2csr            ),
			.opcode_idex_i                 ( inst_f2e_stage2[6:0]   ),
			.fun3_rvc_idex_i               ( inst_f2e_stage2[15:13] ),
			.inst_zero_en_i                ( inst_zero_en           ),
			
			// mtvec
			.csr_mtvec_o                   ( csr_mtvec_csr2i        ),
			
			// csr read/write
			.csr_addr_i                    ( inst_f2e_stage2[31:20] ),
			.csr_wdata_i                   ( csr_wdata_tmp          ),
			.csr_op_i                      ( csr_op_c2csr           ),
			//input  libcsr::csr_op_e      csr_op_i,
			.csr_rdata_o                   ( csr_rdata_csr2r        ),
			// interrupts
			.csr_mepc_o                    ( csr_mepc_csr2i         ),
            // working mode  csr->ex->decode
            .priv_lvl_o                    ( priv_lvl_csr2e         )

			);
	
	
	
	// IF to EX interface
	//	logic [31:0]      	  operand_a_f2e;
	//	logic [31:0]       	  operand_b_f2e;
	//	logic [31:0]           wd_addr_f2e;
	//	logic                  we_f2e;
	//	logic [31:0]           rs2_f2e;
	//logic [31:0]           inst_f2e_stage1;
	//logic [1:0]            inst_valid_f2e_stage1;
	//logic                  we_i_e2f;      //write enable; last cycle
	//logic [DEPTHMSB:0]     wa_i_e2f;      //write address; last cycle
	//logic [WIDTH-1:0]      wd_i_e2f;	     //write re data; last cycle
	logic [31:0]           alu_result_e2f;
	logic [31:0]           inst_addr_flush;
    logic [31:0]           mepc_if2csr;
	assign   inst_addr_flush      = mret_en_c2csr     ? csr_mepc_csr2i
		                          : (sys_call_en_c2csr || excep_en_c2csr) ? csr_mtvec_csr2i
		                          : alu_result_e2f;
	assign   inst_addr_flush_i2im = inst_addr_flush;
	
	if_stage IF (
			
			.clk_i                         ( clk                  ),
			.rst_ni                        ( rst                  ),
			.rst_addr_i                    ( rst_addr_i           ),
			// control
			//.inst_c                        ( instr                ),
			.boot_addr_i                   ( boot_addr            ),              // also used for mtvec(Machine Trap Vector, holds the address the processor jumps to when an exception occurs.)
			.req_i                         ( req                  ),// instruction request control
			.branch_i                      ( branch               ),
			.flush                         ( flush                ), //flush instruction buffer
			.stall                         ( stall                ), //pipeline stall

			//.pc_set_i                      ( pc_set               ),  // set the PC to a new value
			//.pc_mux_i                      ( pc_mux_c2f           ),  // selector for PC multiplexer
			// IF to instruction memory interface
			.line_in                       ( line_in_im2i         ),    //instruction in
			.line_ready                    ( line_ready_im2i      ), //memory system is ready
			.line_valid                    ( line_valid_im2i      ), //instruction input to buffer enable
			//.imembusy_i                    ( busy_im2i            ),
			
			.ld_line                       ( ld_line_i2im         ),    //prefetch a line (split transaction)
			.read_finish_o                 ( read_finish_i2im     ),
			
			.inst_req_o                    ( inst_req_i2im        ),	//valid im request
			.inst_addr_o                   ( inst_addr_i2im       ),	// pc
			//.instmem_addr_o                ( instmem_addr_i2im    ),
			// IF to EX interface
			//			.operand_a_o                   ( operand_a_f2e        ),
			//			.operand_b_o                   ( operand_b_f2e        ),
			//			.wd_addr_o                     ( wd_addr_f2e          ),
			//			.we_o                          ( we_f2e               ),
			//			.rs2                           ( rs2_f2e              ),
			.inst_o                        ( inst_f2e_stage1      ),
			.inst_valid_o                  ( inst_valid_f2e_stage1),

			.inst_addr_flush_i             ( inst_addr_flush      ),
			//.alu_result                    ( alu_result_e2f       ),

			//.we_i                          ( we_i_e2f             ),      //write enable, last cycle
			//.wa_i                          ( wa_i_e2f             ),      //write address, last cycle
			//.wd_i                          ( wd_i_e2f             ),      //write re data, last cycle
		
			//csr->if->imaccess
			.sys_call_en_i                 ( sys_call_en_c2csr    ), //ecall
            .excep_en_i                    ( excep_en_c2csr       ),
			.mret_en_i                     ( mret_en_c2csr        ), //mret
			//.csr_mtvec_i                   ( csr_mtvec_csr2i      ),
			//.csr_mepc_i                    ( csr_mepc_csr2i       )

            .mepc_before_flush_o           (  mepc_if2csr         )
		);
			
	// if to inst mem
//	logic [LINEWIDTH-1:0]   line_in_im2i;    //instruction in
//	logic                   line_ready_im2i; //memory system is ready
//	logic                   line_valid_im2i; //instruction   to buffer enable
//
//	logic                   ld_line_i2im;    //prefetch a line (split transaction)
//	logic                   read_finish_i2im;
//	
//	logic                   inst_req_i2im;	//valid im request
	logic [31:0]            inst_addr_i2im;	// pc

	//logic [31:0]            instmem_addr_i2im;
	//logic                   busy_im2i;
	

/*	inst_rom inst_rom
		(
			.clk                           ( clk                 ),
			.rst                           ( rst                  ),
			.flush                         ( flush               ),
			.ld_line_i                     ( ld_line_i2im        ),
			.read_finish_i                 ( read_finish_i2im    ),//buff has finish reading
			.inst_req_i                    ( inst_req_i2im       ),
			.inst_addr_flush_i             ( alu_result_e2f      ),// pc
			//.instmem_addr_i 	           ( instmem_addr_i2im   ), 
		
			.line_out                      ( line_in_im2i        ),    //instruction in
			.line_ready                    ( line_ready_im2i     ), //memory system is ready for next fetch
			.line_valid                    ( line_valid_im2i     )//instruction input to buffer enable
			//.busy                          ( busy_im2i           )
		);*/
	
	//EX to data memory
	logic [31:0]            rs2_e2lsu;
	logic [31:0]            load_result_lsu2e;
    //ex2csr
	logic [31:0]            rs1_e2csr;
	logic [31:0]            imm_e2csr;
    //ex2controller
    logic [1:0]             illegal_inst_e2c;
	ex_stage EX (
			.clk_i                         ( clk                  ),
			.rst_ni                        ( rst                  ),
 		
			// control
			.stall_i                       ( stall_f2c_stage2     ),
			.aluSel_c2a                    ( aluSel_c2e           ),  //alu mode choose
			.ASel_i                        ( ASel_c2e             ),
			.BSel_i                        ( BSel_c2e             ),
			.is_rvc_o                      ( is_rvc_e2c           ),
            .illegal_inst_o                ( illegal_inst_e2c     ),
			.rs1_rs2_eqz_o                 ( rs1_rs2_eqz_e2c      ),
			.rs1_rs2_eqz_u_o               ( rs1_rs2_eqz_u_e2c    ),
			.reg_write_back_en_c2r         ( reg_write_back_en_c2e ),
			
			//control->ex->multiplier
			.multdiv_finish_o              ( multdiv_finish_e2c     ),
			.div_sub_o                     ( div_sub_e2c            ),
			.mulit_en_i                    ( mulit_en_c2e           ),
			.div_en_i                      ( div_en_c2e             ),
			//.MemR_i                        ( MemR_c2lsu             ),  //mem read enable
			//.MemW_i                        ( MemW_c2lsu             ),  //mem write enable
			
			//EX to data memory interface
			.rs2_o                         ( rs2_e2lsu             ),
			.load_result_i                 ( load_result_lsu2e     ),
//			.MemR_o                        ( MemR_o                ),   //mem read enable
//			.MemW_o                        ( MemW_o                ),   //mem write enable
//			.load_length_i                 ( load_length_c2e       ),   //L8,L16,L32
//			.load_signed_i                 ( load_signed_c2e       ),   //0: unsigned ext,1: sext
//			.miss_aligned_stall_i          ( miss_aligned_stall_c2e),
			
//			.data_addr_o                   ( data_addr_o          ),	// r/w addr
//			.data_o                        ( data_o               ),    // data to mem
		
		//	.line_in                       ( line_in_d            ),    // data from mem
		//	.line_ready                    ( line_ready_d         ), // memory system is ready
			.data_to_regfile_i             ( data_to_regfile_c2e  ),
			// EX from IF interface
			//			.operand_a_i                   ( operand_a_f2e        ),
			//			.operand_b_i                   ( operand_b_f2e        ),
			//			.wd_addr                       ( wd_addr_f2e          ),
			//			.we                            ( we_f2e               ),
			.alu_result_o                  ( alu_result_e2f       ),
			//			.rs2                           ( rs2_f2e              ),
			// .we_o                          ( we_i_e2f             ),      //write enable, last cycle
			// .wa_o                          ( wa_i_e2f             ),      //write address, last cycle
			// .wd_o                          ( wd_i_e2f             ),	  //write rd data, last cycle
			.inst_i                        ( inst_f2e_stage2      ),
			.inst_valid_i                  ( inst_valid_f2e_stage2),
			.pc_idex                       ( pc_f2e_stage2        ),
			.pc_stage1_i                   ( pc_f2e_stage1        ),
			
			//reg 2csr
			.csr_rdata_i                   ( csr_rdata_csr2r      ),
			.rs1_o                         ( rs1_e2csr            ),
			.imm_o                         ( imm_e2csr            ),

            //csr2e
            .priv_lvl_i                    ( priv_lvl_csr2e       )
		);
	
	
//	// LSU to data mem interface
//	logic                   MemR_o;   //mem read enable to mem
//	logic                   MemW_o;   //mem write enable to mem
// 		
//	logic [31:0]            data_addr_o;	// r/w addr
//	logic [31:0]            data_o;    // data to mem
//		
//	logic [LINEWIDTH-1:0]   line_in_d;    // data from mem
//	logic                   line_ready_d;  // memory system is ready
	logic load_finish_lsu2c;
	logic store_finish_lsu2c;
			
	load_store_unit load_store_unit0 (
			.clk                           ( clk                   ),
			.rst                           ( rst                   ),
			//EX stage interface
			.MemR_i                        ( MemR_c2lsu            ),   //mem read enable
			.MemW_i                        ( MemW_c2lsu            ),   //mem write enable
			.load_length_i                 ( load_length_c2e       ),   //L8,L16,L32
			.load_signed_i                 ( load_signed_c2e       ),   //0: unsigned ext,1: sext
			
			.dm_addr_i                     ( alu_result_e2f        ),	// data mem w/r address
 		    .data_i                        ( rs2_e2lsu             ),    // data to mem //rs2
			.result_o                      ( load_result_lsu2e     ),   // data to regfile
 		    // Control interface
			.read_valid_i                  ( read_valid_i          ),  //together with load data
			.write_ready_i                 ( write_ready_i         ),  //ready to receive store data if set
			.load_finish_o                 ( load_finish_lsu2c     ),
			.store_finish_o                ( store_finish_lsu2c    ),
			//.miss_aligned_stall_i          ( miss_aligned_stall_c2lsu ),
 		    
			//.line_ready                    ( line_ready            ),   //memory system is ready

			
		
			// data mem interface
			.line_in                       ( line_in_d             ),   // data from mem
			.data_o                        ( data_o                ),
			.MemR_o                        ( MemR_o                ),   // mem read enable
			.MemW_o                        ( MemW_o                ),   // mem write enable	
			.data_addr_o                   ( data_addr_o           ),	// r/w addr
			.byte_enable_o                 ( byte_enable_o         )
		);
	
	
	
	//stage register
	logic 				 stall_f2c_stage1;
	logic                stall_f2c_stage2;
	logic 				 flush_f2c_stage1;
	logic                flush_f2c_stage2;
	logic [31:0]         pc_f2e_stage1;	// pc
	logic [31:0]         pc_f2e_stage2;
	logic [31:0]         inst_f2e_stage1;
	logic [31:0]         inst_f2e_stage2;
	logic                inst_valid_f2e_stage1;
	logic                inst_valid_f2e_stage2;
    //logic                prev_flush1;
    //logic                prev_flush2; 
	assign pc_f2e_stage1    = inst_addr_i2im;
	assign stall_f2c_stage1 = stall;
	assign flush_f2c_stage1 = flush;

	
	//refresh the if-idex stage registers
	always_ff @(posedge clk) begin
		stall_f2c_stage2      <= stall_f2c_stage1;
		flush_f2c_stage2      <= flush_f2c_stage1;
        //prev_flush1           <= flush;
        //prev_flush2           <= prev_flush1;
		if(~stall) begin
			pc_f2e_stage2         <= pc_f2e_stage1;          //pc_idex <= pc_if
			inst_f2e_stage2       <= inst_f2e_stage1;        //instr_idex <= instr_if  
			inst_valid_f2e_stage2 <= inst_valid_f2e_stage1;
		end else begin			
			pc_f2e_stage2         <= pc_f2e_stage2;          //pc_idex <= pc_if
			inst_f2e_stage2       <= inst_f2e_stage2;        //instr_idex <= instr_if  
			inst_valid_f2e_stage2 <= inst_valid_f2e_stage2;
		end
	end
	
endmodule

