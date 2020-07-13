
/**
 * Instruction Decode Stage
 *
 * Decode stage of the core. It decodes the instructions and hosts the register
 * file.
 */
 
module ex_stage  #(parameter DEPTH=32, parameter LINEWIDTH=64, parameter WIDTH = 32,
		parameter DEPTHMSB = $clog2(DEPTH)-1)
		(

		input  logic                  clk_i,
		input  logic                  rst_ni,
 		
		// EX from IF interface
		//input  logic [31:0]          operand_a_i,
		//input  logic [31:0]          operand_b_i,
		//input  logic [31:0]          wd_addr,
		//input  logic                 we,
		//input  logic [31:0]          rs2,
		input   logic                  stall_i,      //stall from stage 1
		//input   logic                  flush_i,    //flush from stage 1
		input   logic [31:0]           inst_i,       //instr if2idex
		input   logic                  inst_valid_i,
		input   logic [31:0]           pc_idex,      //pc if2idex stage
		input   logic [31:0]           pc_stage1_i,  //stage 1 pc, used when jal or branch taken
        /*
		output  logic                  we_o,      //write enable, last cycle
		output  logic [DEPTHMSB:0]     wa_o,      //write address, last cycle
		output  logic [WIDTH-1:0]      wd_o,	  //write rd data, last cycle
        */
		output  logic [31:0]           alu_result_o,
 		
		// control
		//alu control
		input  logic [4:0]           aluSel_c2a, //alu mode choose
		input  logic [1:0]           ASel_i,   //mux for rs1 and pc
		input  logic [1:0]           BSel_i,   //mux for rs2 and imm
		//control interface
		output logic                 is_rvc_o,
		output logic [1:0]           rs1_rs2_eqz_o,
		output logic [1:0]           rs1_rs2_eqz_u_o,
		input  logic                 reg_write_back_en_c2r,
        output logic [1:0]           illegal_inst_o,
		
		//control->ex->multiplier
		output logic                 multdiv_finish_o,
		output logic                 div_sub_o,
		input  logic                 mulit_en_i,
		input  logic                 div_en_i,
		
		//data mem control
		output logic [WIDTH-1:0]     rs2_o,
		input  logic [WIDTH-1:0]     load_result_i,   // data mem to regfile
		input  logic [2:0]           data_to_regfile_i,
//		input  logic                 MemR_i,  //mem read enable
//		input  logic                 MemW_i,  //mem write enable
//		input  logic [1:0]           load_length_i,   //L8,L16,L32
//		input  logic                 load_signed_i,   //0: unsigned ext,1: sext
//		input  logic                 miss_aligned_stall_i,
 		
		//EX to data memory interface
//		output  logic                MemR_o,   //mem read enable
//		output  logic                MemW_o,   //mem write enable
// 		
//		output logic [31:0]          data_addr_o,	// r/w addr
//		output logic [31:0]          data_o,    // data to mem
//		
//		input logic [LINEWIDTH-1:0]  line_in,    // data from mem
//		input logic                  line_ready  // memory system is ready
		//reg 2csr
		input  logic [31:0]          csr_rdata_i,
		output logic [WIDTH-1:0]     rs1_o,
		output logic [31:0]          imm_o,

        //csr->ex
        input  logic [1:0]           priv_lvl_i
		);
	
	//logic [31:0] alu_result_o;
	
	//decode to regfile interface
	logic [1:0][4:0]       ra_d2r;
	logic [1:0]            re_d2r;
	logic                  we_d2r;
	logic [DEPTHMSB:0]     wd_addr_d2r;
	//decode to alu
	logic [31:0]           imm_d2a;
	assign imm_o = imm_d2a;
	
	logic                  ASel_d2a;   //mux for rs1 and pc
	logic                  BSel_d2a;   //mux for rs2 and imm

	//regfile
	logic [31:0]           data_to_regfile;
	
	//assign data_to_regfile = (data_to_regfile_i == REG_ALU) ? alu_result_o : load_result_i;
	always_comb begin : data_regfile
		case(data_to_regfile_i)
			REG_PC4    : data_to_regfile = pc_stage1_i;
			REG_LOAD   : data_to_regfile = load_result_i;
			REG_MULDIV : data_to_regfile = muldiv_result;
			REG_CSR    : data_to_regfile = csr_rdata_i;
			default    : data_to_regfile = alu_result_o;
		endcase
	end
	
	logic [1:0][WIDTH-1:0] rs_r2a;
	assign rs1_o = rs_r2a[0];
	assign rs2_o = rs_r2a[1];
	//alu
//	logic [31:0]           operand_a_i;
//	logic [31:0]           operand_b_i;

	
	decode de (
			.rst             ( rst_ni                      ),
		
			//control
			//.flush           ( flush                       ),    
			.stall           ( stall_i                     ),
		//	.ASel            ( ASel                        ),
		//	.BSel            ( BSel                        ),
			//control interface
			.is_rvc          ( is_rvc_o                    ),
            .illegal_inst_o  ( illegal_inst_o              ),
			//instruction buffer interface
			.inst_in         ( inst_i                      ),
			.inst_valid      ( inst_valid_i                ),
        
			//regfile interface
			.ra              ( ra_d2r                      ),
			.re              ( re_d2r                      ),
			//reg write interface
			.we              ( we_d2r                      ),
			.wd_addr         ( wd_addr_d2r                 ),
			//// alu interface
			.imm_o           ( imm_d2a                     ),  // immediate

            .priv_lvl_i      ( priv_lvl_i                  )
		);
	
	iregfile ir (
			.clk                 ( clk_i                        ),
			.re                  ( re_d2r                       ),	//read enable
			.ra                  ( ra_d2r                       ),	//read address
			.reg_write_back_en_i ( reg_write_back_en_c2r        ),  // for jal, jalr, load
			.rs                  ( rs_r2a                       ),	//rs1, rs2
			.we                  ( we_d2r                       ),                 	//write enable
			.wa                  ( wd_addr_d2r                  ), //write address
			.wd                  ( data_to_regfile              )
			
			//for log_gene.cpp
			//.inst_in         ( inst_i                       )
		);
	
	
	branch_compare branch_compare0
		(
			.rs1               ( rs_r2a[0]                  ),
			.rs2               ( rs_r2a[1]                  ),
			.rs1_rs2_eqz_u     ( rs1_rs2_eqz_u_o            ),
			.rs1_rs2_eqz       ( rs1_rs2_eqz_o              )//0:r1-r2>0, 1:r1-r2<0 ,2:r1-r2==0, 3:error
		);
	
	//logic [31:0]       adder_result; 

	logic [33:0] adder_result_ext_a2m;
	alu alu (
			.rst                ( rst_ni                       ),
			.is_rvc_i           ( is_rvc_o                     ),
			.r1_i               ( rs_r2a[0]                    ),
			.r2_i               ( rs_r2a[1]                    ),
			.pc_i               ( pc_idex                      ),
			.imm_i              ( imm_d2a                      ),
			//multi/div operand
			.multdiv_operand_a_i( multdiv_operand_a_m2a        ),
			.multdiv_operand_b_i( multdiv_operand_b_m2a        ),
			//operand select
			.ASel_i             ( ASel_i                       ),
			.BSel_i             ( BSel_i                       ),
			
			.aluSel_i           ( aluSel_c2a                   ),  //alu mode choose
			//output
			.adder_result_ext_o ( adder_result_ext_a2m         ), //to multiplier
			.result_o           ( alu_result_o                 ),   //alu result
			//.adder_result_o  ( adder_result                 )
			//alu->control
			//.rs1_rs2_eqz_o      ( rs1_rs2_eqz_o                )
			);

	///////////
	//mul_div//
	///////////
	logic [31:0] mul_result;
	logic [31:0] div_result;
	logic [31:0] muldiv_result;
	assign muldiv_result = mulit_en_i ? mul_result : div_result;
	
	logic mul_finish;
	logic div_finish;
	assign multdiv_finish_o = mulit_en_i ? mul_finish : div_finish;
	

	logic [31:0] multdiv_operand_a_m2a;
	logic [31:0] multdiv_operand_b_m2a;
	logic [31:0] mul_operand_a;
	logic [31:0] mul_operand_b;
	logic [31:0] div_operand_a;
	logic [31:0] div_operand_b;
	assign multdiv_operand_a_m2a = mulit_en_i ? mul_operand_a : div_operand_a;
	assign multdiv_operand_b_m2a = mulit_en_i ? mul_operand_b : div_operand_b;
	multiplier_fast multiplier0 (
			.clk                ( clk_i                        ),
			.rst                ( rst_ni                       ),
			//control
			.mul_finish_o       ( mul_finish                   ),
			.mulit_en_i         ( mulit_en_i                   ),
			.funct3_32          ( inst_i[14:12]                ),

			//operand
			.muldiv_a_i            ( rs_r2a[0]                    ), // Multiplicand<< 
			.muldiv_b_i            ( rs_r2a[1]                    ), // multiplier>>
		
			// alu interface
			.adder_result_ext_i    ( adder_result_ext_a2m         ), //from alu
			.mult_operand_a_o      ( mul_operand_a             ),
			.mult_operand_b_o      ( mul_operand_b             ),
			// regfile interface
			.muldiv_result_o       ( mul_result                   )
		);
	
	divider divider0 (
			.clk                ( clk_i                        ),
			.rst                ( rst_ni                       ),
			//control
			.div_finish_o       ( div_finish                   ),
			.div_en_i           ( div_en_i                     ), 
			.funct3_32          ( inst_i[14:12]                ),
			.div_sub_o          ( div_sub_o                    ),

			//operand
			.muldiv_a_i            ( rs_r2a[0]                    ), // Dividend<<
			.muldiv_b_i            ( rs_r2a[1]                    ), // divisor>>

			// alu interface
			.adder_result_ext_i ( adder_result_ext_a2m          ), //from alu
			.div_operand_a_o    ( div_operand_a                 ),
			.div_operand_b_o    ( div_operand_b                 ),
			
			// regfile interface
			.muldiv_result_o       ( div_result                   )
			);
/*
	logic at_syscall;
	assign at_syscall = pc_idex == 32'h251a; // the entry of seg <syscall.constprop.0>
	
	logic at_secs_passed_0;
	assign at_secs_passed_0 = pc_idex == 32'h34bc; // the entry of <iterate>
	
	logic at_secs_passed_1;
	assign at_secs_passed_1 = pc_idex == 32'h34c0; // the entry of <stop_time>
	
	logic at_secs_passed_2;
	assign at_secs_passed_2 = pc_idex == 32'h34c4; // the entry of <get_time>
	
	logic at_secs_passed_3;
	assign at_secs_passed_3 = pc_idex == 32'h34c8; // the entry of <time_in_secs>
*/
/*	
	logic start_time;
	assign start_time = pc_idex == 32'h2124;
	
	logic stop_time;
	assign stop_time = pc_idex == 32'h2132;
	
	logic get_time;
	assign get_time = pc_idex == 32'h2140;
*/
endmodule
 		