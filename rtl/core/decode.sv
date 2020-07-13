
import liborv32s::*;
import libdecode::*;
import libdefine::*;
import libopcode::*;

module decode #(parameter DEPTH=32, parameter LINEWIDTH=64, parameter WIDTH = 32,
		parameter DEPTHMSB = $clog2(DEPTH)-1) 
		(
		//input  logic            clk,
		input  logic            rst,
		
		//control
		input  logic            stall,
		//input  logic            flush,
		
		//// alu interface
		output logic [31:0]           imm_o,  // immediate
		//		output logic [2:0]            aluSel_o,//alu mode select
		//		//alu mux
		//		output logic            ASel,   //mux for rs1 and pc
		//		output logic            BSel,   //mux for rs2 and imm

		//control interface
		output logic            is_rvc,
        output logic [1:0]      illegal_inst_o,
		//instruction buffer interface
		//output logic            inst_re,    // read one instr from inst_buff enable
		input  logic [31:0]     inst_in,    // the one instr
		input  logic            inst_valid, // signal from buffer, its a whole instr(rv32/rvc)
        
		//ID to EX interface	
		//// regfile interface
		output logic [1:0]            re,     // 2 rs read enable
		output logic [1:0][4:0]       ra,     // 2 rs read address

		output logic                  we,     // rd write enable
		output logic [DEPTHMSB:0]     wd_addr,	//rd write address 

        // csr interface, working mode
        input  logic [1:0]            priv_lvl_i
		);
       
    logic [1:0] illegal_inst;
    
    assign illegal_inst_o = illegal_inst; //& {inst_valid, inst_valid};

	//logic is_rvc_imm;
	//logic is_rv32_imm;
	regaddr_t rs1_addr, rs2_addr;
	regaddr_t rd_addr;
	
	logic [17:0] imm_rvc;
	logic [31:0] imm_rv32;
	logic sign_ext;   //sign extend: 0 or 1
	
	assign is_rvc = is_inst_rvc(inst_in[1:0]);
	//logic  bubble_inst;
    //assign bubble_inst = (inst_in == '0) ? '1 : '0;
    //assign is_rvc_internal = !bubble_inst && is_rvc;

	//decode regfile access 
	always_comb begin: decode_reg
		if (is_rvc) begin //TODO decode unfinished
			//is_rvc_imm = is_inst_rvc_imm(inst_in[15:0]);
		/*if(is_rvc_imm) begin
				decode_imm_16(inst_in[15:0], imm_rvc, sign_ext);
			end*/ 
			/*assign*/ /*illegal_inst =*/ decode_regaddr_16(inst_in[15:0], rs1_addr, rs2_addr, rd_addr);
			
		end else begin
             //is_rv32_imm = is_inst_rv32_imm(inst_in);
		/*	if(is_rv32_imm) begin
				imm_rv32 = signed'( {decode_imm_32(inst_in)} );
			end */ 
			/*assign*/ illegal_inst = decode_regaddr_32(inst_in, priv_lvl_i, rs1_addr, rs2_addr, rd_addr);
		end
	end
    
    always_comb begin: decode_imm   
		decode_imm_16(inst_in[15:0], imm_rvc, sign_ext);
		imm_rv32 = signed'( {decode_imm_32(inst_in)} );
    end

	assign imm_o = is_rvc ? { {14{sign_ext}}, imm_rvc } : imm_rv32;

	always_comb begin: decode_addr
		if(rs1_addr.valid) begin  //switch between rs1 and rd for alu_muxa
			re [0] =  rs1_addr.valid & inst_valid;
			ra [0] =  rs1_addr.addr;
		end else begin
			re [0] =  rd_addr.valid & inst_valid;
			ra [0] =  rd_addr.addr;
		end
		re [1] =  rs2_addr.valid & inst_valid;
		ra [1] =  rs2_addr.addr;

		we     =  rd_addr.valid & inst_valid;
		wd_addr = rd_addr.addr;
	
//doesn't need it because found the assembler can automatically generate the implicit reg
/*		case (inst_in[6:2]) //opcode
			JAL:     wd_addr = (rd_addr.addr==5'b0) ? 5'b1 : rd_addr.addr;
			default: wd_addr = rd_addr.addr;
		endcase*/
		
	end
	
	
	
	/*//mux for rs1 and pc
	always_comb begin: alu_mux_asel
		if(rs1_addr.valid) begin
			ASel = ASEL_RS1;   
		end else begin
			ASel = ASEL_PC;
		end
	end
	//mux for rs2 and imm
	always_comb begin: alu_mux_bsel
		if(rs2_addr.valid) begin
			BSel = BSEL_RS2;   
		end else begin
			BSel = ASEL_IMM;
		end
	end*/
	
	
	
	
endmodule 
