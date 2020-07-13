
/**
 * Main controller of the processor
 */
import libdecode::*;
import libdefine::*;
import libopcode::*;
import liborv32s::*;
import libalu::*;

module control (
 		input   logic                   rst,
		input   logic [31:0]            inst_in,
		input   logic                   inst_valid,
		// control to if
		input   logic                   stall_last,   //stall for last stage
		input   logic                   flush_last,   //flush for last stage
        //input   logic                   flush_last_last,
		output  logic [31:0]            boot_addr_i,  // also used for mtvec(Machine Trap Vector, holds the address the processor jumps to when an exception occurs.)
		output  logic                   req_i,        // instruction request control
		output  logic       			branch_i,
		output  logic 				    flush,                         //flush instruction buffer
		output  logic 				    stall,                         //pipeline stall

		//output  logic                   pc_set_o,                 // set the PC to a new value
		//output  logic [1:0]             pc_mux_o,                 // selector for PC multiplexer
 		
		//control to lsu
		//control->ex->data mem
		output  logic                   MemR_o,  //mem read enable
		output  logic                   MemW_o,  //mem write enable
		input   logic                   load_finish_i,
		input   logic	                store_finish_i,
	 	
		//control to ex
		//alu mux
		output  logic [1:0]             ASel_o,   //mux for rs1 and pc
		output  logic [1:0]             BSel_o,   //mux for rs2 and imm
		output  logic [4:0]             aluSel_o,//alu mode select
		input   logic                   is_rvc_i,
        input   logic [1:0]             illegal_inst_i,
		input   logic [1:0]             rs1_rs2_eqz_i,  //0:r1-r2>0, 1:r1-r2<0 ,2:r1-r2==0, 3:error
		input   logic [1:0]             rs1_rs2_eqz_u_i,
		//control->regfiles
		output  logic                   reg_write_back_en_o,
		output  logic [2:0]             data_to_regfile_o,//alu/load
		//control->ex->load_store_interface
		output  logic [1:0]             load_length_o,
		output  logic                   load_signed_o,   //0: unsigned ext,1: sext
		//output  logic                   miss_aligned_stall_o,

		//control->ex->multiplier
		input   logic                   div_sub_i, /// division step need do Subtraction
		inout   logic                   multdiv_finish_i,
		output  logic                   mulit_en_o,
		output  logic                   div_en_o,
		
		//control->csr
		output  logic                   sys_call_en_o,
        output  logic                   excep_en_o,
	    output  logic                   mret_en_o,
	    output  libcsr::csr_op_e        csr_op_o
		);
 	
	
	///////////////
	//rvc -> rv32//
	///////////////
	//rv32 opcode
	logic [4:0]      op_32;  //rv32 opcode
	logic [2:0]      funct3_32;
	logic            funct7_32; //inst_in[30]
	//rvc16 opcode
	//logic [2:0] funct3_16;//rvc opcode
	
	always_comb begin: rv_rvc
		if(~is_rvc_i) begin
			op_32     =  inst_in[6:2];
			funct3_32 =  inst_in[14:12];
			funct7_32 =  inst_in[30];
		end
		else begin  //translate rvc to rv
			funct7_32 = '0;
			if(inst_in[1:0] == 2'b00) begin//quadrant 0
				case(inst_in[15:13])
					3'b000: begin	//c.addi4spn rd0, uimm //addi rd, x2, uimm
						op_32     = OP_IMM;
						funct3_32 = ADDI;
					end
					//  quadrant 0 load & store
					3'b010: begin   //c.lw rd', uimm(rs1')//lw rd, uimm(rs1)
						op_32     = LOAD;
						funct3_32 = LW;
					end
					/*3'b110: begin
						op_32     = STORE;
						funct3_32 = SW;
					end*/
					
					default: begin  //3'b110
						op_32     = STORE;
						funct3_32 = SW;
					end
				endcase
			end
			
			if(inst_in[1:0] == 2'b01) begin//quadrant 1
				funct3_32 = ADDI;
				case(inst_in[15:13])
					3'b000,	 //c.addi
					3'b010:	 //c.li rd, imm   //addi rd, x0, imm
					begin
						op_32     = OP_IMM;
						//funct3_32 = ADDI;
					end
					3'b001, //c.jal
					3'b101:	//c.j
						op_32     = JAL; 
					3'b011: begin 
						if(inst_in[11:7]==5'b10) begin//c.addi16sp imm //addi x2, x2, imm
							op_32     = OP_IMM;
							//funct3_32 = ADDI;
						end else 				//c.lui rd, imm
							op_32 = LUI;
					end
					3'b110: begin   //c.beqz
						op_32     = BRANCH;
						funct3_32 = BEQ;
					end
					3'b111: begin   //c.bnez
						op_32     = BRANCH;
						funct3_32 = BNE;
					end
					
					default: begin //3'b100
						if(inst_in[11:10]==2'b00) begin//c.srli
							op_32     = OP_IMM;
							funct3_32 = SRLI_SRAI;
							funct7_32 = SRL;
						end
						if(inst_in[11:10]==2'b01) begin//c.srai
							op_32     = OP_IMM;
							funct3_32 = SRLI_SRAI;
							funct7_32 = SRA;
						end
						if(inst_in[11:10]==2'b10) begin//c.andi
							op_32     = OP_IMM;
							funct3_32 = ANDI;
						end
						if(inst_in[11:10]==2'b11 & inst_in[6:5]==2'b00) begin//c.sub
							op_32     = OP;
							funct3_32 = ADD_SUB;
							funct7_32 = SUB;
						end
						if(inst_in[11:10]==2'b11 & inst_in[6:5]==2'b01) begin//c.xor
							op_32     = OP;
							funct3_32 = XOR;
						end
						if(inst_in[11:10]==2'b11 & inst_in[6:5]==2'b10) begin//c.or
							op_32     = OP;
							funct3_32 = OR;
						end
						if(inst_in[11:10]==2'b11 & inst_in[6:5]==2'b11) begin//c.and
							op_32     = OP;
							funct3_32 = AND;
						end
					end
				endcase
			end
			
			if(inst_in[1:0] == 2'b10) begin//quadrant 2
				funct3_32 = SLLI;
				case(inst_in[15:13])
					3'b000: begin //c.slli
						op_32     = OP_IMM;
						//funct3_32 = SLLI;
					end
					3'b010: begin // c.lwsp rd, uimm(x2) //lw rd, uimm(x2)
						op_32     = LOAD;
						funct3_32 = LW;
					end
					
					3'b100: begin
						logic rd_zero;
						logic rs2_zero;
						rd_zero  = (inst_in[11:7] == 5'b0);
						rs2_zero = (inst_in[6:2]  == 5'b0);
						if(~rd_zero & rs2_zero)//c.jr //jalr x0, 0(rs1) //c.jalr
							op_32 = JALR;
						if(~rd_zero & ~rs2_zero)//c.mv //add rd, x0, rs2 //c.add
						begin
							op_32     = OP;
							funct3_32 = ADD_SUB;
							funct7_32 = ADD;
						end
						//TODO c.ebreak
						
					end
					
					default: begin //3'b110  // c.swsp //sw rs2, uimm(x2)
						op_32     = STORE;
						funct3_32 = SW;
					end
				endcase
			end
		end
	end
	



	////////////////////////////
	// reg write back control //
	////////////////////////////
	
	// jal,jalr write back pc+4 in 1st cycle
	// load write back in the last cycle
	logic reg_write_back_en;
	always_comb begin: reg_write_back_control
		case (op_32)
			//JAL,JALR: reg_write_back_en = ~stall_last;
				//LOAD    : reg_write_back_en = miss_aligned_stall ? ( stall_last ? ENABLE : DISABLE) : ENABLE;
			LOAD    : reg_write_back_en = stall_last;
			MULDIV32: reg_write_back_en = inst_in[25] & ~is_rvc_i ? multdiv_finish_i : ENABLE;
			CSR     : reg_write_back_en = ~(inst_in[13:12]==2'b00);
			default:  reg_write_back_en = ENABLE;
		endcase
	end	
	assign reg_write_back_en_o = reg_write_back_en & (rst==RstDisable);
	
	assign data_to_regfile_o = ( op_32 == JAL | op_32 == JALR  ) ? REG_PC4
		                     : ( op_32 == LOAD ) ? REG_LOAD 
		                     :   is_rvmop        ? REG_MULDIV 
		                     :   csr_en          ? REG_CSR
		                     :                     REG_ALU;


	///////////////////////////
	// alu_mux & mem control //
	///////////////////////////
	logic[1:0]   BSel_jal; //new inst_in//stage 1, compare
	assign       BSel_jal    = BSEL_IMM; //stall_last ? BSEL_IMM  : BSEL_IM4;
	
	logic[1:0]   ASel_jalr; //new inst_in//stage 1, compare
	logic[1:0]   BSel_jalr;

	assign       ASel_jalr   = ASEL_RS1; //stall_last ? ASEL_RS1  : ASEL_PC;
	assign       BSel_jalr   = BSEL_IMM; //stall_last ? BSEL_IMM  : BSEL_IM4;
	
	logic[1:0]   ASel_branch;
	logic[1:0]   BSel_branch;
	assign       ASel_branch = ASEL_PC;  //stall_last ? ASEL_PC   : ASEL_RS1;
	assign       BSel_branch = BSEL_IMM; //stall_last ? BSEL_IMM  : BSEL_RS2;
	
	logic[1:0]   ASel_op;
	logic[1:0]   BSel_op;
	assign       ASel_op     = is_rvmop   ? ASEL_MULA : ASEL_RS1;
	assign       BSel_op     = is_rvmop   ? BSEL_MULB : BSEL_RS2;

	//recognize
	always_comb begin: opcode
		MemR_o   = DISABLE;
		MemW_o   = DISABLE;
		case (op_32)
			LUI: begin				// rd<-(imm<<12)
				ASel_o   = ASEL_IM0;
				BSel_o   = BSEL_IMM;
			end
			AUIPC: begin			// rd<-pc+(imm<<12)
				ASel_o   = ASEL_PC;
				BSel_o   = BSEL_IMM;
			end
			JAL: begin				// rd(default x1)<-pc+4, pc<-pc+sext(offset)
				ASel_o   = ASEL_PC;
				BSel_o   = BSel_jal;
			end
				
			JALR: begin				// rd(default x1)<-pc+4, pc<-rs1+sext(offset)
				ASel_o   = ASel_jalr;
				BSel_o   = BSel_jalr;
			end
				
			BRANCH: begin			// if(r1??r2) pc<-pc+sext(offset)
				ASel_o   = ASel_branch;
				BSel_o   = BSel_branch;
			end
			LOAD: begin
				ASel_o   = ASEL_RS1;
				BSel_o   = BSEL_IMM;
				MemR_o   = ENABLE;
			end
			STORE: begin
				ASel_o   = ASEL_RS1;
				BSel_o   = BSEL_IMM;
				MemW_o   = ENABLE;
			end
				
			OP_IMM: begin
				ASel_o   = ASEL_RS1;
				BSel_o   = BSEL_IMM;	
			end
				
			default: begin //OP // opcode equal to MULDIV32
				ASel_o   = ASel_op;
				BSel_o   = BSel_op;
			end

		endcase
		//	end
	end
	
	
	//////////////////////////
	// load & store control //
	//////////////////////////
	always_comb begin: funct3_load
		load_signed_o = ENABLE; //sext	
		if( op_32 == LOAD) begin
			case(funct3_32)
				LB: begin           //load byte rd<-sext(M[rs1+sext(offset)][7:0])
					load_length_o = L8;
					//load_signed_o = ENABLE; //sext	
				end
				
				LH: begin           //load halfword rd<-sext(M[rs1+sext(offset)][15:0])
					load_length_o = L16;
					//load_signed_o = ENABLE; //sext	
				end
				
				LW: begin           //load halfword rd<-sext(M[rs1+sext(offset)][31:0])
					load_length_o = L32;
					//load_signed_o = ENABLE; //sext
				end
				
				LBU: begin          //load byte rd<-zext(M[rs1+sext(offset)][7:0])
					load_length_o = L8;
					load_signed_o = DISABLE; //zero ext	
				end
				
				default: begin   //LHU       //load halfword rd<-zext(M[rs1+sext(offset)][15:0])
					load_length_o = L16;
					load_signed_o = DISABLE; //zero ext	
				end
			endcase
		end 
		else begin //op_32 == STORE
			case(funct3_32)
				SB: begin
					load_length_o = L8;
				end
				SH: begin
					load_length_o = L16;
				end
				default: begin//SW
					load_length_o = L32;
				end
			endcase
		end
	end
	
/*	always_comb begin: funct3_store
		if( op_32 == STORE) begin
			case(funct3_32)
				SB: begin
					load_length_o = L8;
				end
				SH: begin
					load_length_o = L16;
				end
				SW: begin
					load_length_o = L32;
				end
				default: ;//error
			endcase
		end
	end*/
	
	
	
	/////////////////
	//stall_control//
	/////////////////
	
	//jal
	logic  jal_stall;
	assign jal_stall    = DISABLE;//~stall_last;
	
	//branch
	
	assign branch_stall = DISABLE; //stall_last ? DISABLE : branch_taken;	
	
	
	// load
	logic load_stall     = /*~load_finish_i;*/ ~(stall_last & load_finish_i);
	
	// store
	logic store_stall    = /*~store_finish_i;*/~(stall_last & store_finish_i);
	
	//muldiv
	logic muldiv_stall   = is_rvmop ? ~multdiv_finish_i : DISABLE;

	//stall control
	always_comb begin: stall_control
		case (op_32)
			JAL,                  // rd(default x1)<-pc+4, pc<-pc+sext(offset)
			JALR                  // rd(default x1)<-pc+4, pc<-rs1+sext(offset)
			: stall    = jal_stall; //new inst_in//stage 1 compare, stage 2 pc
				
			BRANCH                // if(r1??r2) pc<-pc+sext(offset)
			: stall    = branch_stall;	
				
			OP                    // opcode equal to MULDIV32
			: stall    = muldiv_stall;
			
			LOAD
			: stall    = load_stall; //~load_finish_i;
			
			STORE
			: stall    = store_stall; //~store_finish_i;

			default               //LUI, AUIPC, OP_IMM
			: stall    = DISABLE; 	
		endcase
	end
	
	
	/////////////////
	//flush_control//
	/////////////////
	
	//jal
	logic  jal_flush;
	assign jal_flush    = ENABLE;
	
	//branch
	logic  branch_flush;
	assign branch_flush = branch_taken ? PCALU : PC4;
	
	
	logic  compare_gt; //r1 >  r2
	logic  compare_lt; //r1 <  r2
	logic  compare_eq; //r1 == r2
	logic  compare_gt_u; //r1 >  r2
	logic  compare_lt_u; //r1 <  r2
	logic  compare_eq_u; //r1 == r2
	logic  branch_taken;
	logic  branch_stall;
	
	assign compare_gt     = (rs1_rs2_eqz_i == BRAN_GT);
	assign compare_lt     = (rs1_rs2_eqz_i == BRAN_LT);
	assign compare_eq     = ~compare_gt & ~compare_lt;
	assign compare_gt_u   = (rs1_rs2_eqz_u_i == BRAN_GT);
	assign compare_lt_u   = (rs1_rs2_eqz_u_i == BRAN_LT);
	assign compare_eq_u   = ~compare_gt_u & ~compare_lt_u;
	
	assign branch_stall = DISABLE; //stall_last ? DISABLE : branch_taken;	
	
	always_comb begin: stall_branch_judge
		case(funct3_32)
			BEQ : branch_taken =  compare_eq;
				
			BNE : branch_taken = ~compare_eq;
				
			BLT : branch_taken =  compare_lt;
			BLTU: branch_taken =  compare_lt_u;
				
			BGE : branch_taken =  compare_gt   | compare_eq;
			BGEU: branch_taken =  compare_gt_u | compare_eq_u;
				
			default:;
		endcase
	end
	
	
	
	//system
	logic  sys_flush;
    //assign sys_flush    = (sys_call_en | mret_en | excep_en) ? PCALU : PC4;
	//flush control
	always_comb begin: flush_control
		case (op_32)
			JAL,
			JALR
			: flush = jal_flush;
				
			BRANCH
			: flush = branch_flush;
			
		/*	SYSTEM //ecall, ebreak, mret
			: flush = sys_flush; //set pc to mtvec
		*/		
        /*
            BUBBLE: begin
                // no operation
                flush = DISABLE;
            end*/
			default                 //LUI, AUIPC, LOAD, STORE, OP_IMM, OP
			: //flush = PC4; 
				begin
                    sys_flush = (sys_call_en | mret_en | excep_en) ? PCALU : PC4;
                    flush = sys_flush? ENABLE : DISABLE;
                end 
		endcase
		//if (sys_flush)
		   
	end
	
	/////////////////////
	//aluSelect_control//
	/////////////////////
	logic [4:0]  aluSel;
	assign aluSel_o = aluSel;
	
	//jal
	logic [4:0] jal_aluSel;
	assign jal_aluSel   = ALU_ADD; //stall_last ? ALU_ADD : ALU_JAL;
	
	//branch
	logic [4:0] branch_aluSel;
	/*
	logic  branch_compare;
	always_comb begin: aluSel_branch_judge
		case(funct3_32)				
			BLTU,
			BGEU
			: branch_compare   = ALU_CMPU; //new inst_in//stage 1, compare
				
			default  //BEQ,	BNE, BLT, BGE
			: branch_compare   = ALU_CMP;
		endcase
	end
	*/
	assign branch_aluSel = ALU_ADD; //stall_last ? ALU_ADD : branch_compare;
	
	//opi
	logic[4:0]  opi_aluSel;
	logic       is_addi;
	assign      is_addi          = (funct3_32 == ADDI);         //ADDI
	assign      opi_aluSel       = is_addi ? ALU_ADD : op_int; 
	
	
	//op (op_int & op_muldiv)
	logic[4:0]  op_aluSel;
	logic[4:0]  op_int;
	logic[4:0]  op_muldiv;
	assign      op_aluSel        = int_muldiv ? op_int : op_muldiv;

	
	logic       int_muldiv;
	assign      int_muldiv =  is_rvc_i ? ENABLE : ~inst_in[25];   //set: int, reset: muldiv
	
	logic       add_sub;
	logic[4:0]  op_int_addsub;
	assign      add_sub          = (funct7_32 == ADD);//set: add, reset: subtract
	assign      op_int_addsub    = add_sub ? ALU_ADD : ALU_SUB;
	
	logic       srl_sra;
	logic[4:0]  op_int_srlsra;
	assign      srl_sra          = (funct7_32 == SRL);
	assign      op_int_srlsra    = srl_sra ? ALU_SRL : ALU_SRA;

	
	always_comb begin: funct3_OP //R type //I type
		case(funct3_32)
			SLL                       //shift left logic rd<-rs1<<rs2
			//==SLLI 
			: op_int   = ALU_SLL; 
				
			SLT                       //set rd if rs1<rs2 signed
			//==SLTI 
			: op_int   = ALU_SLT; 
				
			SLTU                      //set rd if rs1<rs2 unsigned
			//==SLTIU
			: op_int   = ALU_SLTU;
				
			XOR
			//==XORI
			: op_int   = ALU_XOR;
				
			OR
			//==ORI
			: op_int   = ALU_OR;
				
			AND
			//==ANDI
			: op_int   = ALU_AND;
				
			ADD_SUB
			: op_int   = op_int_addsub;
				
			default //SRL_SRA==SRLI_SRAI
			: op_int   = op_int_srlsra;
		endcase
	end
		
	logic[4:0]  op_muldiv_divrem;
	assign      op_muldiv_divrem = div_sub_i ? ALU_SUB : ALU_ADD;
	assign      op_muldiv        = mul_div   ? ALU_ADD : op_muldiv_divrem;


	//aluSelect control
	always_comb begin: aluSel_control
		case (op_32)
			LUI, 		           // rd<-(imm<<12)
			AUIPC,                 // rd<-pc+(imm<<12)
			LOAD,
			STORE
			: aluSel   = ALU_ADD;
			
			JAL,
			JALR
			: aluSel   = jal_aluSel;
			
				
			BRANCH
			: aluSel   = branch_aluSel;
				
			OP_IMM
			: aluSel   = opi_aluSel;
				
			OP                     // opcode equal to MULDIV32
			: aluSel   = op_aluSel;

			default   //LUI rd<-(imm<<12), AUIPC rd<-pc+(imm<<12), LOAD, STORE
			: aluSel   = ALU_ADD;
				
		endcase
	end
	
	
	
	//////////////////
	//muldiv_control//
	//////////////////
	logic  is_rviop; //distinguish rvi op from rvm muldiv
	logic  is_rvmop;
	logic  is_rvop; 
	assign is_rvop    = (op_32 == OP);  //OP == MULDIV32
	assign is_rviop   = is_rvop & ~inst_in[25];
	assign is_rvmop   = is_rvop &  inst_in[25] & ~is_rvc_i;

	
	logic  mul_div;
	assign mul_div    = ~funct3_32[2]; //set:mul, reset:div
	assign mulit_en_o = is_rvmop &  mul_div;
	assign div_en_o   = is_rvmop & ~mul_div;
 
	
	
	/////////////
	// csr r/w //
	/////////////
	logic  csr_en;
	logic  sys_call_en;
    logic  excep_en;
	logic  mret_en;

	assign csr_en        = ( op_32 == SYSTEM );
	assign sys_call_en   = csr_en & (funct3_32 == ECALL) & ( inst_in[21:20] == 2'b00); //ecall
	assign sys_call_en_o = sys_call_en;
    //assign excep_en      = illegal_inst_i == INST_EXCEP || illegal_inst_i == BUBBLE_EXCEP && !flush_last_last && !flush_last;
    //assign excep_en      = (illegal_inst_i == INST_EXCEP || illegal_inst_i == BUBBLE_EXCEP) && !flush_last_last;
    assign excep_en      = illegal_inst_i == INST_EXCEP && inst_in != 32'b0;
	assign excep_en_o    = excep_en;
	assign mret_en       = csr_en & (funct3_32 == ECALL) & ( inst_in[21:20] == 2'b10); //mret
	assign mret_en_o     = mret_en;
	
	//csr_op
	libcsr::csr_op_e   csr_op;
	always_comb begin: csr_op_1
		unique case (inst_in[13:12])
	      2'b01:   csr_op = CSR_OP_WRITE;
	      2'b10:   csr_op = CSR_OP_SET;
	      2'b11:   csr_op = CSR_OP_CLEAR;
	      default:;
		endcase
	end
	
	// CSRRSI/CSRRCI must not write 0 to CSRs (uimm[4:0]=='0)
	// CSRRS/CSRRC must not write from x0 to CSRs (rs1=='0)
	always_comb begin: csr_op_2
		csr_op_o = csr_op;
		if ((csr_op == CSR_OP_SET || csr_op == CSR_OP_CLEAR) && inst_in[19:15] == '0) begin
			csr_op_o = CSR_OP_READ;
		end
	end
	
	
	
 endmodule
